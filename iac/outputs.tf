output "aws_regions" {
  value = [var.aws_region_primary, var.aws_region_secondary]
}

output "aws_region_primary" {
  value = var.aws_region_primary
}

output "aws_region_secondary" {
  value = var.aws_region_secondary
}

output "localstack" {
  value = var.localstack
}

output "vpc_id" {
  value = var.vpc_id
}

output "lambda_architectures" {
  value = var.lambda_architectures
}

output "lambda_subnet_ids" {
  value = var.lambda_subnet_ids
}

output "lambda_security_group_ids" {
  value = var.lambda_security_group_ids
}

output "bucket_name" {
  value = var.bucket_name
}
