resource "aws_sqs_queue" "ocr_queue" {
  name                       = "${var.app_name}-ocr_queue-${var.stack_env}"
  visibility_timeout_seconds = module.lambda_inbox.lambda.timeout
}

resource "aws_sqs_queue_policy" "ocr_queue_policy" {
  queue_url = aws_sqs_queue.ocr_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.ocr_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = data.aws_s3_bucket.existing_bucket.arn
          }
        }
      }
    ]
  })
}

# Lambda event source mapping to connect SQS to Lambda
resource "aws_lambda_event_source_mapping" "ocr_processor_trigger" {
  event_source_arn = aws_sqs_queue.ocr_queue.arn
  function_name    = module.lambda_inbox.lambda.arn
  batch_size       = 1
}
