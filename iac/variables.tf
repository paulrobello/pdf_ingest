variable "localstack" {
  description = "set to true when running under local stack"
  type        = bool
  default     = false
}

variable "logging_level" {
  description = "Debug level for lambda logging"
  type        = string
  default     = "INFO"
}

variable "log_retention_in_days" {
  description = "Lambda log retention period in days"
  type        = number
  default     = 3
}

variable "app_name" {
  description = "Application name prefix"
  type        = string
}

variable "stack_env" {
  description = "suffix to make stack name unique"
  type        = string
  default     = "stack"
}

variable "aws_account_num" {
  description = "AWS account number"
  type        = string
  default     = "000000000000"
}

variable "aws_region_primary" {
  description = "AWS primary region"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_secondary" {
  description = "AWS secondary region"
  type        = string
  default     = "us-west-2"
}

variable "lambda_architectures" {
  description = "Lambda architecture. arm64 or x86_64"
  type        = string
  default     = "arm64"
}

variable "lambda_src_base" {
  description = "Base folder for lambda source code."
  type        = string
  default     = "../src"
}

variable "vpc_id" {
  description = "VPC id if using private api / lambda"
  type        = string
  default     = null
}

variable "lambda_security_group_ids" {
  description = "vpc config security_group_ids"
  type = list(string)
  default = []
}

variable "lambda_subnet_ids" {
  description = "vpc config subnet_ids"
  type = list(string)
  default = []
}

variable "python_version" {
  description = "Python version to use"
  type        = string
  default     = "3.11"
}

variable "service" {
  description = "Application components, independent of infrastructure attributes."
  type        = string
  default     = "pdf_ingestion"
}

variable "role" {
  description = "What the service do"
  type        = string
  default     = "document_ingestion"
}

variable "created_by" {
  description = "IAC tool"
  type        = string
  default     = "Terraform"
}

variable "code_repository" {
  description = "Repo for IAC"
  type        = string
  default     = "pdf_ingestion"
}

variable "monitored_by" {
  description = "Monitoring tool used"
  type        = string
  default     = "cloudwatch"
}

variable "cost_center" {
  description = "For billing purposes"
  type        = string
  default     = "it"
}

variable "project" {
  description = "project name"
  type        = string
  default     = "PDF Ingestion"
}

variable "Provider" {
  description = "Cloud provider"
  type        = string
  default     = "amazon"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}


variable "langchain_tracing" {
  description = "Langchain Tracing. Requires VPC with internet access"
  type        = bool
  default     = false
}
variable "langchain_endpoint" {
  description = "Langchain Endpoint"
  type        = string
  default     = ""
}
variable "langchain_api_key" {
  description = "Langchain API Key"
  type        = string
  default     = ""
}
variable "langchain_project" {
  description = "Langchain Project name"
  type        = string
  default     = "Empty leg bot"
}

variable "max_ocr_workers" {
  description = "Max number of ocr workers"
  type        = string
  default     = null
}

variable "ai_provider" {
  description = "AI provider"
  type        = string
  default     = "Bedrock"
  validation {
    condition = contains(["Bedrock", "OpenAI", "Anthropic"], var.ai_provider)
    error_message = "Invalid AI provider. Must be one of Bedrock, OpenAI, or Anthropic."
  }
}
variable "ai_model" {
  description = "AI model"
  type        = string
  default     = ""
}

variable "openai_api_key" {
  description = "Open AI API Key"
  type        = string
  default     = ""
}
variable "anthropic_api_key" {
  description = "Anthropic API Key"
  type        = string
  default     = ""
}
