# this is prepended to most names and stack
export APP_NAME = pdf_ingestion
# env type we are deploying to, gets appended to most names and stack
export STACK_ENV = prod
# logging level used in lambdas
export LOGGING_LEVEL = WARN
export LOGGING_RETENTION_DAYS = 30
# region we are deploying to
export AWS_DEFAULT_REGION = us-east-1
export AWS_REGION = $(AWS_DEFAULT_REGION)
# used as a prefix to build iac state key
export IAC_BUCKET_KEY = global-iac
# this is set to true if running under localstack
export IS_LOCAL = false
# python version used for building lambdas
export PYTHON_VERSION = 3.11
# Can be Bedrock, Anthropic or OpenAI
export AI_PROVIDER = Bedrock
# set to a value that prevents rate limits
export MAX_OCR_WORKERS = 4

# bucket that will handle pdf ingestion
BUCKET_NAME = pdf-ingestion-$(STACK_ENV)-$(AWS_REGION)


# terraform cli command
TF_CMD = terraform
# aws cli command
AWS_CMD = aws

# cpu arch that should be used by docker to build lambdas
# when running under localstack the target will be be auto set to host arch for faster local build and run
export DOCKER_ARCH = x86_64
export DOCKER_PLATFORM = linux/$(DOCKER_ARCH)
export LAMBDA_ARCH = $(DOCKER_ARCH)
export PIP_PLATFORM = manylinux2014_x86_64
