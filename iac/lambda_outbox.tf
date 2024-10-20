module "lambda_outbox" {
  source                = "./aws_tf_shared/lambda/"
  app_name              = var.app_name
  stack_env             = var.stack_env
  name                  = "outbox"
  output_path           = "${var.lambda_src_base}/lambda_outbox/lambda_outbox.zip"
  runtime               = "python${var.python_version}"
  aws_region_primary    = var.aws_region_primary
  architectures         = var.lambda_architectures
  layers                = [aws_lambda_layer_version.lambda_custom_layer.arn]
  localstack            = var.localstack
  security_group_ids    = var.lambda_security_group_ids
  subnet_ids            = var.lambda_subnet_ids
  logging_level         = var.logging_level
  log_retention_in_days = var.log_retention_in_days
  memory_size           = 512
  timeout               = 900
  environment = {
    STACK_ENV                   = var.stack_env
    POWERTOOLS_SERVICE_NAME     = "OcrOutputProcessor"
    POWERTOOLS_LOGGER_LOG_EVENT = "true"
  }
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda_s3_policy"
  role = module.lambda_outbox.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${data.aws_s3_bucket.existing_bucket.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "outbox_bedrock_policy" {
  name   = "ecs_task_bedrock_policy-${var.stack_env}"
  role   = module.lambda_outbox.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        "Action": [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        "Effect": "Allow",
        "Resource": "arn:aws:bedrock:*::foundation-model/*"
      },
    ]
  })
}
resource "aws_lambda_permission" "outbox_allow_bucket" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_outbox.lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.existing_bucket.arn
}
