resource "aws_ecr_repository" "ecr_repository" {
  name         = "${var.app_name}-repo-${var.stack_env}"
  force_delete = true
}

resource "null_resource" "docker_login" {
  count = var.localstack ? 0 : 1
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region_primary} | docker login --username AWS --password-stdin  ${var.aws_account_num}.dkr.ecr.${var.aws_region_primary}.amazonaws.com"
  }
  triggers = {
    image_src = filebase64sha256("${var.lambda_src_base}/inbox_container/checksum")
  }
}


resource "null_resource" "docker_tag" {
  provisioner "local-exec" {
    command = "docker tag inbox_container:latest ${aws_ecr_repository.ecr_repository.repository_url}:latest"
  }
  provisioner "local-exec" {
    command = "docker tag inbox_container:latest ${aws_ecr_repository.ecr_repository.repository_url}:${chomp(file("${var.lambda_src_base}/inbox_container/checksum"))}"
  }
  depends_on = [null_resource.docker_login]
  triggers = {
    image_src = filebase64sha256("${var.lambda_src_base}/inbox_container/checksum")
  }
}

resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.ecr_repository.repository_url}:latest"
  }
  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.ecr_repository.repository_url}:${chomp(file("${var.lambda_src_base}/inbox_container/checksum"))}"
  }
  depends_on = [null_resource.docker_tag]
  triggers = {
    image_src = filebase64sha256("${var.lambda_src_base}/inbox_container/checksum")
  }
}

data "aws_ecr_image" "service_image" {
  repository_name = aws_ecr_repository.ecr_repository.name
  image_tag = "latest"
  #   most_recent     = true
  depends_on = [null_resource.docker_push]
}


module "lambda_inbox" {
  source                = "./aws_tf_shared/lambda/"
  app_name              = var.app_name
  stack_env             = var.stack_env
  package_type          = "Image"
  name                  = "inbox"
  output_path           = "${aws_ecr_repository.ecr_repository.repository_url}:${chomp(file("${var.lambda_src_base}/inbox_container/checksum"))}"
  aws_region_primary    = var.aws_region_primary
  architectures         = var.lambda_architectures
  localstack            = var.localstack
  security_group_ids    = var.lambda_security_group_ids
  subnet_ids            = var.lambda_subnet_ids
  logging_level         = var.logging_level
  log_retention_in_days = var.log_retention_in_days
  memory_size           = 1024
  timeout               = 900
  environment = {
    STACK_ENV                   = var.stack_env
    POWERTOOLS_SERVICE_NAME     = "OcrPdfProcessor"
    POWERTOOLS_LOGGER_LOG_EVENT = "true"
    OUTPUT_BUCKET               = data.aws_s3_bucket.existing_bucket.id
    OUTPUT_PREFIX               = "outbox"
    INUT_BUCKET                 = data.aws_s3_bucket.existing_bucket.id
    INPUT_PREFIX                = "inbox"
    MAX_OCR_WORKERS             = var.max_ocr_workers
    AI_PROVIDER                 = var.ai_provider
    AI_MODEL                    = var.ai_model
    AI_BASE_URL                 = var.ai_base_url
    OPENAI_API_KEY              = var.openai_api_key
    ANTHROPIC_API_KEY           = var.anthropic_api_key
    LANGCHAIN_PROJECT           = var.langchain_project
    LANGCHAIN_TRACING_V2        = var.langchain_tracing
    LANGCHAIN_API_KEY           = var.langchain_api_key
    LANGCHAIN_ENDPOINT          = var.langchain_endpoint
  }
  depends_on = [null_resource.docker_push]
}


# IAM policy for OCR processor Lambda
resource "aws_iam_role_policy" "ocr_policy" {
  name = "ocr_output_processor_policy"
  role = module.lambda_inbox.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
        ]
        Resource = [
          data.aws_s3_bucket.existing_bucket.arn,
          "${data.aws_s3_bucket.existing_bucket.arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.ocr_queue.arn,
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "inbox_bedrock_policy" {
  name = "ecs_task_bedrock_policy-${var.stack_env}"
  role = module.lambda_inbox.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        "Action" : [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:bedrock:*::foundation-model/*"
      },
    ]
  })
}
