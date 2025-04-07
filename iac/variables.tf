variable "logging_level" {
  description = "Debug level for function logging"
  type        = string
  default     = "INFO"
}

variable "log_retention_in_days" {
  description = "Function log retention period in days"
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

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "centralus"
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "langchain_tracing" {
  description = "Langchain Tracing"
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
  default     = "PDF Ingestion"
}

variable "max_ocr_workers" {
  description = "Max number of ocr workers"
  type        = string
  default     = null
}

variable "ai_provider" {
  description = "AI provider"
  type        = string
  default     = "OpenAI"
  validation {
    condition = contains(["AzureOpenAI", "OpenAI", "Anthropic"], var.ai_provider)
    error_message = "Invalid AI provider. Must be one of AzureOpenAI, OpenAI, or Anthropic."
  }
}

variable "ai_model" {
  description = "AI model"
  type        = string
  default     = ""
}

variable "ai_base_url" {
  description = "AI base URL"
  type        = string
  default     = null
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

variable "azure_openai_api_key" {
  description = "Azure OpenAI API Key"
  type        = string
  default     = ""
}

variable "inbox_container_image_tag" {
  type        = string
  description = "latest"
  # You might want a default for local testing, but usually this is passed via CI/CD
  # default     = "latest"
}
