data "aws_s3_bucket" "existing_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_notification" "ocr_trigger" {
  bucket = data.aws_s3_bucket.existing_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.ocr_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "inbox/"
  }
  lambda_function {
    lambda_function_arn = module.lambda_outbox.lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "outbox/"
    filter_suffix       = "-final.md"
  }
}
