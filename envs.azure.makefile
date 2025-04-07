# Application Configuration
export APP_NAME = pdf-ingest
export STACK_ENV = dev
export PYTHON_VERSION = 3.11

# Logging Configuration
LOGGING_LEVEL = INFO
# must be at least 30
LOGGING_RETENTION_DAYS = 30

# Azure Regional Configuration
LOCATION = centralus
RESOURCE_GROUP = ${APP_NAME}-${STACK_ENV}
STORAGE_ACCOUNT = pdfingest${STACK_ENV}
ACR_NAME = pdfingestregistry${STACK_ENV}
#ACR_USERNAME = $(shell az acr credential show --name $(ACR_NAME) --query "username" -o tsv)
#ACR_PASSWORD = $(shell az acr credential show --name $(ACR_NAME) --query "passwords[0].value" -o tsv)

# Storage Container Names
STORAGE_CONTAINER_INBOX = inbox
STORAGE_CONTAINER_OUTBOX = outbox

# AI Configuration
AI_PROVIDER = OpenAI
AI_MODEL = gpt-4o
AI_BASE_URL =
MAX_OCR_WORKERS = 1

# Docker Build Configuration
export DOCKER_ARCH = x86_64
export DOCKER_PLATFORM = linux/$(DOCKER_ARCH)
export PIP_PLATFORM = manylinux2014_x86_64

# Azure CLI Command
AZ_CMD = az
