"""cli app to use AI to OCR files."""

from __future__ import annotations

import os
import tempfile
import time
from pathlib import Path
import concurrent.futures


from pdf2image import convert_from_path
from dotenv import load_dotenv
from aws_lambda_powertools import Logger
import boto3

from .lib.pricing_lookup import show_llm_cost
from .lib.llm_image_utils import image_to_base64, try_get_image_type
from .lib.llm_providers import LlmProvider, provider_default_models, provider_env_key_names
from .lib.llm_config import LlmConfig
from .lib.provider_cb_info import get_parai_callback

logger = Logger()

s3 = boto3.client("s3")

load_dotenv()
load_dotenv(str(Path("~/.par_ocr_config").expanduser()))


doc_folder = Path("./test_data").absolute()
input_file_default = doc_folder / "test1.pdf"
system_prompt_file_default = Path(__file__).parent / "system_prompt.md"


def convert_pdf_to_images(
    *,
    src_file: Path,
    pdf_path: Path,
    output_path: Path,
) -> list[tuple[Path, str]]:
    """convert_pdf_to_images"""
    logger.info(f"Converting {src_file} to images and saving to {output_path}")

    ret: list[tuple[Path, str]] = []
    image_data = convert_from_path(pdf_path, output_folder=output_path)
    for i, image in enumerate(image_data):
        suffix = "-page" + str(i + 1).zfill(3) + ".jpg"
        out_image_path = output_path / (pdf_path.stem + suffix)
        image.save(out_image_path, "JPEG")
        ret.append((out_image_path, suffix))
    return ret


def ai_ocr(
    *,
    max_workers: int | None = None,
    llm_config: LlmConfig,
    system_prompt_text: str,
    src_file: Path,
    pdf_path: Path,
    images: list[tuple[Path, str]],
    output_path: Path,
    output_bucket: str,
    output_key: str,
) -> Path:
    """Use AI OCR to extract text from images"""

    model = llm_config.build_chat_model()
    system_prompt = (
        "system",
        system_prompt_text,
    )

    pages: list[tuple[int, str]] = []

    def process_image(image_data: tuple[Path, str]) -> tuple[int, str]:
        image, suffix = image_data
        page_num = int("".join([x for x in suffix if x.isdigit()]).lstrip("0") or 0)
        text_file = output_path / (image.stem + f"-{llm_config.model_name}.md")
        logger.info(f"Extracting text from image {page_num} of {len(images)}")
        image_type = try_get_image_type(image)
        image_base_64 = image_to_base64(image.read_bytes(), image_type)
        chat = [
            {"type": "text", "text": "Please extract all text from the following image into markdown."},
            {
                "type": "image_url",
                "image_url": {"url": image_base_64},
            },
        ]
        upload_done = False
        try:
            response = model.invoke([system_prompt, ("user", chat)])  # type: ignore
            content = str(response.content).strip().replace("```markdown", "").replace("```", "")
            content += "\n\nPage # " + str(page_num) + "\n"
            text_file.write_text(content, encoding="utf-8")

            logger.info(f"Uploading {text_file} to {output_bucket}/{output_key}")
            s3.upload_file(
                str(text_file),
                output_bucket,
                f"{output_key}/{src_file.stem}{suffix.split('.')[0]}.md",
            )
            upload_done = True
            return page_num, content
        except Exception as e:  # pylint: disable=broad-except
            logger.error(f"Error extracting text from image: {page_num}: {e}")
            logger.exception(e)
            if not upload_done:
                s3.upload_file(
                    str(f"Error extracting text from image: {page_num}: {e}"),
                    output_bucket,
                    f"{output_key}/{src_file.stem}{suffix.split('.')[0]}.md",
                )
            return page_num, f"Error extracting text from image {page_num}: {e}"

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        results = list(executor.map(process_image, images))

    for page_num, content in sorted(results, key=lambda x: x[0]):
        pages.append((page_num, content))

    text_file = output_path / (pdf_path.stem + f"-{llm_config.model_name}.md")
    text_file.write_text("\n\n".join([content for _, content in pages]), encoding="utf-8")
    return text_file


# pylint: disable=too-many-arguments,too-many-branches, too-many-positional-arguments
def main(
    *,
    max_workers: int | None = None,
    ai_provider: LlmProvider = LlmProvider.OPENAI,
    model: str | None = None,
    ai_base_url: str | None = None,
    pricing: bool = False,
    request_id: str,
    input_bucket: str,
    input_key: str,
    output_bucket: str,
    output_key: str,
) -> None:
    """OCR files using AI."""

    # convert zero to None so default will be used
    if not max_workers:
        max_workers = None

    if not model:
        model = provider_default_models[ai_provider]

    if ai_provider not in [LlmProvider.BEDROCK]:
        key_name = provider_env_key_names[ai_provider]
        if not os.environ.get(key_name):
            raise ValueError(f"{key_name} environment variable not set.")

    llm_config = LlmConfig(provider=ai_provider, model_name=model, base_url=ai_base_url, temperature=0)

    # Set output path
    output_path = Path(tempfile.mkdtemp(suffix="inbox_container"))

    # config summary info
    logger.info(
        [
            f"Request ID: {request_id}",
            f"Input Bucket: {input_bucket}",
            f"Input Key: {input_key}",
            f"Output Bucket: {output_bucket}",
            f"Output Key: {output_key}",
            f"AI Provider: {ai_provider.value}",
            f"Model: {model}",
            f"AI Provider Base URL:{ai_base_url or 'default'}",
            f"System Prompt: {system_prompt_file_default.name}",
            f"Pricing: {pricing}",
        ]
    )

    if not system_prompt_file_default.exists():
        raise FileNotFoundError(f"System prompt file {system_prompt_file_default} does not exist.")

    src_file = Path(input_key.split("/")[-1])

    input_ext = src_file.suffix.lower()
    if input_ext not in {".pdf", ".jpg", ".jpeg", ".png"}:
        raise Exception(f"Input file {input_key} has an unsupported extension. Only pdf, jpg, and png are supported.")

    temp_file = tempfile.NamedTemporaryFile(dir=output_path, suffix=input_ext, delete=False)
    input_file = Path(temp_file.name)

    logger.info(f"Downloading file from s3 {input_bucket}/{input_key} to {input_file}")
    s3.download_file(input_bucket, input_key, input_file)
    logger.info(f"Uploading {src_file.name} to s3://{output_bucket}/{output_key}")
    s3.upload_file(input_file, output_bucket, f"{output_key}/{src_file.name}")

    if input_ext == ".pdf":
        image_files = convert_pdf_to_images(src_file=src_file, pdf_path=input_file, output_path=output_path)
    elif input_ext in {".jpg", ".jpeg", ".png"}:
        image_files = [(input_file, input_file.suffix)]
    else:
        raise Exception(f"Input file {input_file} has an unsupported extension. Only pdf, jpg, and png are supported.")

    logger.info(f"Uploading {len(image_files)} to s3://{output_bucket}/{output_key}")
    for image_file, suffix in image_files:
        s3.upload_file(image_file, output_bucket, f"{output_key}/{src_file.stem}{suffix}")

    with get_parai_callback(llm_config) as cb:
        start_time = time.time()
        markdown_file = ai_ocr(
            max_workers=max_workers,
            llm_config=llm_config,
            system_prompt_text=system_prompt_file_default.read_text(encoding="utf-8"),
            src_file=src_file,
            pdf_path=input_file,
            images=image_files,
            output_path=output_path,
            output_bucket=output_bucket,
            output_key=output_key,
        )
        end_time = time.time()
        usage_metadata = cb.usage_metadata

    logger.info(
        f"Total time: {end_time - start_time:.1f}s Pages per second: {len(image_files) / (end_time - start_time):.2f}"
    )

    logger.info(f"Output file: {markdown_file.absolute()}")

    logger.info(f"Uploading {markdown_file.name} to s3://{output_bucket}/{output_key}/{src_file.stem}-final.md")
    s3.upload_file(markdown_file, output_bucket, f"{output_key}/{src_file.stem}-final.md")

    if pricing:
        show_llm_cost(llm_config, usage_metadata)
