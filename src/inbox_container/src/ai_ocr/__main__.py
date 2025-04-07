"""cli app to use AI to OCR files."""

from __future__ import annotations

import concurrent.futures
import logging
import os
import tempfile
import time
from pathlib import Path

from azure.storage.blob import BlobServiceClient, ContentSettings
from dotenv import load_dotenv
from par_ai_core.llm_config import LlmConfig, llm_run_manager
from par_ai_core.llm_image_utils import image_to_base64, try_get_image_type
from par_ai_core.llm_providers import LlmProvider, provider_env_key_names, provider_vision_models
from par_ai_core.pricing_lookup import PricingDisplay
from par_ai_core.provider_cb_info import get_parai_callback
from pdf2image import convert_from_path

load_dotenv()
load_dotenv(str(Path("~/.par_ocr_config").expanduser()))

# Configure logger
logger = logging.getLogger("azure")
logger.setLevel(logging.INFO)

# Get connection string from environment
connection_string = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
blob_service_client = BlobServiceClient.from_connection_string(connection_string) if connection_string else None
assert blob_service_client


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
            response = model.invoke(
                [system_prompt, ("user", chat)],  # type: ignore
                config=llm_run_manager.get_runnable_config(model.name),  # type: ignore
            )  # type: ignore
            content = str(response.content).strip().replace("```markdown", "").replace("```", "")
            content += "\n\nPage # " + str(page_num) + "\n"
            text_file.write_text(content, encoding="utf-8")

            logger.info(f"Uploading {text_file} to {output_bucket}/{output_key}")
            assert blob_service_client
            # Get a client for the container
            container_client = blob_service_client.get_container_client(output_bucket)
            # Get a client for the blob
            blob_name = f"{output_key}/{src_file.stem}{suffix.split('.')[0]}.md"
            blob_client = container_client.get_blob_client(blob_name)
            # Upload the file
            with open(text_file, "rb") as data:
                blob_client.upload_blob(
                    data, overwrite=True, content_settings=ContentSettings(content_type="text/markdown")
                )
            upload_done = True
            return page_num, content
        except Exception as e:  # pylint: disable=broad-except
            logger.error(f"Error extracting text from image: {page_num}: {e}")
            logger.exception(e)
            if not upload_done:
                try:
                    # Get a client for the container
                    assert blob_service_client
                    container_client = blob_service_client.get_container_client(output_bucket)

                    # Get a client for the blob
                    blob_name = f"{output_key}/{src_file.stem}{suffix.split('.')[0]}.md"
                    blob_client = container_client.get_blob_client(blob_name)
                    # Upload error message
                    error_content = f"Error extracting text from image: {page_num}: {e}"
                    blob_client.upload_blob(
                        error_content.encode("utf-8"),
                        overwrite=True,
                        content_settings=ContentSettings(content_type="text/markdown"),
                    )
                except Exception as upload_error:
                    logger.error(f"Error uploading error message: {upload_error}")
            return page_num, f"Error extracting text from image {page_num}: {e}"

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        results = list(executor.map(process_image, images))

    for page_num, content in sorted(results, key=lambda x: x[0]):
        pages.append((page_num, content))

    text_file = output_path / (pdf_path.stem + f"-{llm_config.model_name}.md")
    text_file.write_text("\n\n".join([content for _, content in pages]), encoding="utf-8")
    return text_file


# pylint: disable=too-many-arguments,too-many-branches, too-many-positional-arguments
def ocr_main(
    *,
    max_workers: int | None = None,
    ai_provider: LlmProvider = LlmProvider.OPENAI,
    model: str | None = None,
    ai_base_url: str | None = None,
    pricing: PricingDisplay = PricingDisplay.DETAILS,
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
        model = provider_vision_models[ai_provider]

    # Check if API key is required for the provider
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
            f"Input Container: {input_bucket}",
            f"Input Blob: {input_key}",
            f"Output Container: {output_bucket}",
            f"Output Path: {output_key}",
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

    logger.info(f"Downloading blob from {input_bucket}/{input_key} to {input_file}")
    # Get a client for the container
    assert blob_service_client
    input_container_client = blob_service_client.get_container_client(input_bucket)
    # Get a client for the blob
    input_blob_client = input_container_client.get_blob_client(input_key)
    # Download the blob to the temporary file
    with open(input_file, "wb") as file:
        download_stream = input_blob_client.download_blob()
        file.write(download_stream.readall())

    logger.info(f"Uploading {src_file.name} to {output_bucket}/{output_key}")
    # Get a client for the output container
    output_container_client = blob_service_client.get_container_client(output_bucket)
    # Get a client for the output blob
    output_blob_name = f"{output_key}/{src_file.name}"
    output_blob_client = output_container_client.get_blob_client(output_blob_name)
    # Upload the file
    with open(input_file, "rb") as data:
        content_type = "application/pdf" if input_file.suffix.lower() == ".pdf" else "image/jpeg"
        output_blob_client.upload_blob(
            data, overwrite=True, content_settings=ContentSettings(content_type=content_type)
        )

    if input_ext == ".pdf":
        image_files = convert_pdf_to_images(src_file=src_file, pdf_path=input_file, output_path=output_path)
    elif input_ext in {".jpg", ".jpeg", ".png"}:
        image_files = [(input_file, input_file.suffix)]
    else:
        raise Exception(f"Input file {input_file} has an unsupported extension. Only pdf, jpg, and png are supported.")

    logger.info(f"Uploading {len(image_files)} to {output_bucket}/{output_key}")
    for image_file, suffix in image_files:
        # Get a client for the output container
        image_container_client = blob_service_client.get_container_client(output_bucket)
        # Get a client for the output blob
        image_blob_name = f"{output_key}/{src_file.stem}{suffix}"
        image_blob_client = image_container_client.get_blob_client(image_blob_name)
        # Upload the file
        with open(image_file, "rb") as data:
            image_blob_client.upload_blob(
                data, overwrite=True, content_settings=ContentSettings(content_type="image/jpeg")
            )

    with get_parai_callback(show_pricing=pricing):
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

    logger.info(
        f"Total time: {end_time - start_time:.1f}s Pages per second: {len(image_files) / (end_time - start_time):.2f}"
    )

    logger.info(f"Output file: {markdown_file.absolute()}")

    logger.info(f"Uploading {markdown_file.name} to {output_bucket}/{output_key}/{src_file.stem}-final.md")
    # Get a client for the output container
    final_container_client = blob_service_client.get_container_client(output_bucket)
    # Get a client for the output blob
    final_blob_name = f"{output_key}/{src_file.stem}-final.md"
    final_blob_client = final_container_client.get_blob_client(final_blob_name)
    # Upload the file
    with open(markdown_file, "rb") as data:
        final_blob_client.upload_blob(
            data, overwrite=True, content_settings=ContentSettings(content_type="text/markdown")
        )
