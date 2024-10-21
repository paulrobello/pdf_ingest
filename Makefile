.PHONY: all local-all clean local-clean deploy local-deploy stack-init local-stack-init

run    := uv run
python := $(run) python
lint   := $(run) pylint
pyright := $(run) pyright
black  := $(run) black


# this is optional and can be used to specify secrets or other vars. .env is in .gitignore and wont be checked in
-include .env
# contains application default values
include envs.app.makefile
# localstack deployment and testing
include envs.local.makefile
# specific aws envs should each have their own file included here
include envs.par-dev.makefile

# default to false if not set
LANGCHAIN_TRACING_V2 ?= false

# Directory structure
IAC_DIR := ./iac
SRC_DIR := ./src


local-all:all
all: clean stack-init deploy

# create .auto.tfvars file with all needed values
local-make-tf-vars: make-tf-vars
make-tf-vars:
	rm $(IAC_DIR)/*.auto.tfvars -f

	echo 'app_name="$(APP_NAME)"' > $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'stack_env="$(STACK_ENV)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'localstack="$(IS_LOCAL)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'logging_level="$(LOGGING_LEVEL)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'log_retention_in_days="$(LOGGING_RETENTION_DAYS)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'aws_region_primary="$(AWS_REGION)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'aws_region_secondary=""' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'lambda_architectures="$(LAMBDA_ARCH)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'python_version="$(PYTHON_VERSION)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'lambda_subnet_ids=$(VPC_SUBNET_IDS)' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'lambda_security_group_ids=$(VPC_SG_IDS)' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'aws_account_num="$(AWS_ACCOUNT)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'vpc_id="$(VPC_ID)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'bucket_name="$(BUCKET_NAME)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'max_ocr_workers="$(MAX_OCR_WORKERS)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'ai_provider="$(AI_PROVIDER)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'ai_model="$(AI_MODEL)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'openai_api_key="$(OPENAI_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'anthropic_api_key="$(ANTHROPIC_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'langchain_tracing=$(LANGCHAIN_TRACING_V2)' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'langchain_endpoint="$(LANGCHAIN_ENDPOINT)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'langchain_api_key="$(LANGCHAIN_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'langchain_project="$(LANGCHAIN_PROJECT)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars

	echo 'terraform {' > $(IAC_DIR)/main.tf
	echo '  required_providers {' >> $(IAC_DIR)/main.tf
	echo '    aws = {' >> $(IAC_DIR)/main.tf
	echo '      source  = "hashicorp/aws"' >> $(IAC_DIR)/main.tf
	echo '      version = "~> 5.20.0"' >> $(IAC_DIR)/main.tf
	echo '    }' >> $(IAC_DIR)/main.tf
	echo '  }' >> $(IAC_DIR)/main.tf
	echo '	backend "s3" {' >> $(IAC_DIR)/main.tf
	echo '		region="$(AWS_REGION)"' >> $(IAC_DIR)/main.tf
	echo '		bucket="$(IAC_BUCKET)"' >> $(IAC_DIR)/main.tf
	echo '		key="$(IAC_BUCKET_KEY)/$(APP_NAME)/$(STACK_ENV)/terraform.tfstate"' >> $(IAC_DIR)/main.tf
	echo '		encrypt=true' >> $(IAC_DIR)/main.tf
	echo '	}' >> $(IAC_DIR)/main.tf
	echo '}' >> $(IAC_DIR)/main.tf

local-create-iac-bucket:
	$(AWS_CMD) s3api create-bucket --region $(AWS_REGION) --bucket $(IAC_BUCKET)
	$(AWS_CMD) s3api put-bucket-versioning --bucket $(IAC_BUCKET) --versioning-configuration Status=Enabled

local-create-pdf-bucket:
	$(AWS_CMD) s3api create-bucket --region $(AWS_REGION) --bucket $(BUCKET_NAME)

local-aws-init: local-create-iac-bucket local-create-pdf-bucket

local-clean: clean
clean:
	rm -f outputs.*.json
	cd $(IAC_DIR) && rm -rf terraform.* terraform.tfstate* .terraform* -rf plan-$(STACK_ENV).json plan.out graph.dot *.auto.tfvars


local-stack-init: stack-init
stack-init: make-tf-vars
	cd $(IAC_DIR) && $(TF_CMD) init -upgrade -reconfigure

# helper to work with vpc
local-get-default-vpc-info: get-default-vpc-info
get-default-vpc-info:
	$(AWS_CMD) ec2 describe-vpcs --region $(AWS_REGION) --filters "Name=isDefault,Values=true"

# helper to work with vpc
local-get-default-vpc-subnets: get-default-vpc-subnets
get-default-vpc-subnets:
	$(AWS_CMD) ec2 describe-subnets --region $(AWS_REGION) --filters "Name=vpc-id,Values=$(VPC_ID)" --query 'Subnets[].SubnetId' | jq -c

refresh:
	cd $(IAC_DIR) && $(TF_CMD) refresh

# dump outputs to json file
local-dump-outputs: dump-outputs
dump-outputs: stack-init
	cd $(IAC_DIR) && $(TF_CMD) output -json > ../outputs-$(STACK_ENV).json

local-deploy: deploy
deploy: build stack-init make-tf-vars
	cd $(IAC_DIR) && $(TF_CMD) apply -auto-approve \
	&& $(TF_CMD) output -json > ../outputs-$(STACK_ENV).json

local-plan: plan
plan: build stack-init make-tf-vars
	cd $(IAC_DIR) && $(TF_CMD) plan


local-destroy:
	stop-ls.sh && start-ls.sh
destroy: stack-init make-tf-vars build
	cd $(IAC_DIR) && \
	$(TF_CMD) apply -destroy -auto-approve

# source packaging and assembly ---------------------------------------

# list of all dirs with makefiles for build
PKG_SUBDIRS := $(dir $(shell find src -name "makefile"))

local-clean: clean
clean-src: $(PKG_SUBDIRS)
	for i in $(PKG_SUBDIRS); do \
        $(MAKE) -C $$i clean; \
    done

local-build: build
build: $(PKG_SUBDIRS)
	# docker pull gets weird if an AWS_PROFILE is set so we temporarily unset
	for i in $(PKG_SUBDIRS); do \
		export AWS_PROFILE_OLD=$$AWS_PROFILE; \
		unset AWS_PROFILE; \
        $(MAKE) -C $$i build; \
		export AWS_PROFILE=$$AWS_PROFILE_OLD; \
    done

local-delete-zips: delete-zips
delete-zips:
	find ./src -type f -name '*.zip' -delete

# destroy and re-deploy
local-it-again: local-destroy local-clean local-aws-init local-all
it-again: destroy clean all

#--------- [ Logs ] ------------

local-list-log-groups: list-log-groups
list-log-groups:
	$(AWS_CMD) logs describe-log-groups


#--------- [ SNS ] ------------

local-get-sns-subs: get-sns-subs
get-sns-subs:
	$(AWS_CMD) sns list-subscriptions --region $(AWS_REGION)

#--------- [ SQS ] ------------

#--------- [ S3 Params ] ------------

local-upload-pdf: upload-pdf
upload-pdf:
	$(AWS_CMD) s3 cp ./docs/pdf-text-normal.pdf s3://${BUCKET_NAME}/inbox/

local-delete-pdf: delete-pdf
delete-pdf:
	$(AWS_CMD) s3 rm s3://${BUCKET_NAME}/inbox/pdf-text-normal.pdf

local-list-bucket: list-bucket
list-bucket:
	$(AWS_CMD) s3 ls ${BUCKET_NAME}/

local-list-inbox: list-inbox
list-inbox:
	$(AWS_CMD) s3 ls ${BUCKET_NAME}/inbox/

local-list-outbox: list-outbox
list-outbox:
	$(AWS_CMD) s3 ls ${BUCKET_NAME}/outbox/

#--------- [ TF ] ------------

local-gen-plan-json: gen-plan-json
gen-plan-json:
	cd $(IAC_DIR) && $(TF_CMD) plan -out=plan-$(STACK_ENV).out && $(TF_CMD) show -json plan-$(STACK_ENV).out > plan-$(STACK_ENV).json


.PHONY: ugly
ugly:				# Reformat the code with black.
	$(black) src/$(lib)

.PHONY: lint
lint:				# Run Pylint over the library
	$(lint) src

.PHONY: typecheck
typecheck:			# Perform static type checks with pyright
	$(pyright)

.PHONY: typecheck-stats
typecheck-stats:			# Perform static type checks with pyright and print stats
	$(pyright) --stats

.PHONY: checkall
checkall: ugly typecheck lint 	        # Check all the things

.PHONY: pre-commit              # run pre-commit checks on all files
pre-commit:
	pre-commit run --all-files

.PHONY: pre-commit-update               # run pre-commit and update hooks
pre-commit-update:
	pre-commit autoupdate
