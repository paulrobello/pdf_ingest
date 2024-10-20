# see envs.app.makefile for default starting values

# env type we are deploying to, gets appended to most names and stack
local-%: export STACK_ENV := lcl
# this is set to true if running under localstack
local-%: export IS_LOCAL = true
# logging level used in lambdas
local-%: export LOGGING_LEVEL = DEBUG
# region we are deploying to
local-%: export AWS_ACCOUNT = 000000000000
local-%: export AWS_DEFAULT_REGION = us-east-1
local-%: export AWS_REGION = $(AWS_DEFAULT_REGION)
local-%: export AWS_PROFILE = localstack
# iac state
local-%: export IAC_BUCKET = ls-iac-state-$(AWS_REGION)

# use the localstack wrappers for terraform and aws cli
local-%: TF_CMD = tflocal
local-%: AWS_CMD = aws

# AI
local-%: export AI_PROVIDER = OpenAI
local-%: export MAX_OCR_WORKERS = 1 # prevent rate limits

local-caller:
	@echo $(shell $(AWS_CMD) sts get-caller-identity)

# used for private alb deployment. for localstack we fetch default values
local-%: VPC_ID = $(shell $(AWS_CMD) ec2 describe-vpcs --region $(AWS_REGION) --profile $(AWS_PROFILE) --query 'Vpcs[0].VpcId' | jq -cr)
local-%: VPC_SUBNET_IDS = $(shell $(AWS_CMD) ec2 describe-subnets --region $(AWS_REGION) --profile $(AWS_PROFILE) --query 'Subnets[].SubnetId' | jq -cr)
local-%: VPC_SG_IDS = $(shell $(AWS_CMD) ec2 describe-security-groups --region $(AWS_REGION) --profile $(AWS_PROFILE) --query 'SecurityGroups[].GroupId' | jq -cr)



# cpu arch that should be used by docker to build lambdas
# when running under localstack the target will be be auto set to host arch for faster local build and run
export LOCAL_ARCH ::= $(shell uname -m)

# used to build lambdas for host machine arch which avoids emulation and builds/runs faster
ifeq ("$(LOCAL_ARCH)","x86_64")
local-%: export DOCKER_ARCH = x86_64
local-%: export DOCKER_PLATFORM = linux/$(DOCKER_ARCH)
local-%: export LAMBDA_ARCH = $(DOCKER_ARCH)
local-%: export PIP_PLATFORM = manylinux2014_x86_64
else
local-%: export DOCKER_ARCH = arm64
local-%: export DOCKER_PLATFORM = linux/$(DOCKER_ARCH)
local-%: export LAMBDA_ARCH = $(DOCKER_ARCH)
local-%: export PIP_PLATFORM = manylinux2014_aarch64
endif
