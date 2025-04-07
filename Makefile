.PHONY: all clean azure-deploy azure-clean stack-init format lint typecheck checkall azure-upload-pdf azure-list-outbox azure-create-tf-backend azure-destroy-tf-backend

run    := uv run
python := $(run) python
ruff   := $(run) ruff
pyright := $(run) pyright

# this is optional and can be used to specify secrets or other vars. .env is in .gitignore and wont be checked in
-include .env
# azure configuration (includes both app and infrastructure settings)
include envs.azure.makefile

# Directory structure
IAC_DIR := ./iac
SRC_DIR := ./src

all: clean stack-init azure-deploy

# Azure resource creation helpers
azure-create-resource-group:
	$(AZ_CMD) group create --name $(RESOURCE_GROUP) --location $(LOCATION)

azure-create-storage:
	$(AZ_CMD) storage account create --name $(STORAGE_ACCOUNT) \
		--resource-group $(RESOURCE_GROUP) \
		--location $(LOCATION) \
		--sku Standard_LRS

azure-create-tf-state-container:
	$(AZ_CMD) storage container create --name tfstate \
		--connection-string "$(AZURE_STORAGE_CONNECTION_STRING)" \
		--auth-mode login

azure-create-acr:
	$(AZ_CMD) acr create --name $(ACR_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--sku Basic \
		--admin-enabled true

azure-delete-acr:
	$(AZ_CMD) acr delete --name $(ACR_NAME) \
		--resource-group $(RESOURCE_GROUP) \
		--yes || true

# Delete the Terraform state container
azure-delete-tf-state-container:
	$(AZ_CMD) storage container delete --name tfstate \
		--connection-string "$(AZURE_STORAGE_CONNECTION_STRING)" \
		--auth-mode login

# Destroy all resources for Terraform state backend
azure-destroy-tf-backend: azure-delete-tf-state-container azure-delete-acr
	$(AZ_CMD) storage account delete --name $(STORAGE_ACCOUNT) \
		--resource-group $(RESOURCE_GROUP) \
		--yes

azure-destroy-tf-resource-group: azure-destroy-tf-backend
	$(AZ_CMD) group delete --name $(RESOURCE_GROUP) \
		--yes

azure-destroy-tf: azure-destroy-tf-resource-group


# Initialize Azure resources
azure-init: azure-create-resource-group azure-create-storage azure-create-tf-state-container azure-create-acr

azure-get-storage-key:
	$(AZ_CMD) storage account keys list \
	  --resource-group $(RESOURCE_GROUP) \
	  --account-name $(STORAGE_ACCOUNT)

azure-get-storage-connection-strings:
	$(AZ_CMD) storage account show-connection-string --name $(STORAGE_ACCOUNT) --output tsv

# clean terraform resources
clean:
	rm -f outputs.*.json
	cd $(IAC_DIR) && rm -rf terraform.* terraform.tfstate* .terraform* -rf plan-$(STACK_ENV).json plan.out graph.dot

# Initialize terraform
stack-init: 
	cd $(IAC_DIR) && terraform init -upgrade -reconfigure

# Create variables for terraform
make-tf-vars:
	echo 'app_name="$(APP_NAME)"' > $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'stack_env="$(STACK_ENV)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'location="$(LOCATION)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'storage_account_name="$(STORAGE_ACCOUNT)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'logging_level="$(LOGGING_LEVEL)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'log_retention_in_days="$(LOGGING_RETENTION_DAYS)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	INBOX_IMAGE_FULL_NAME="$(ACR_NAME).azurecr.io/inbox_container:latest"; \
	INBOX_SHA=$$(docker image inspect --format '{{.Id}}' "$${INBOX_IMAGE_FULL_NAME}" 2>/dev/null | cut -d ':' -f 2) || \
		(echo "Error: Failed to get SHA for image $${INBOX_IMAGE_FULL_NAME}. Was it built?" >&2; exit 1); \
	if [ -z "$${INBOX_SHA}" ]; then \
		echo "Error: Got empty SHA for image $${INBOX_IMAGE_FULL_NAME}. Was it built correctly?" >&2; exit 1; \
	fi; \
    echo "inbox_container_image_tag=\"$${INBOX_SHA}\"" >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
#	echo 'inbox_container_image_tag=$(INBOX_CONTAINER_IMAGE_TAG)' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'max_ocr_workers="$(MAX_OCR_WORKERS)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'ai_provider="$(AI_PROVIDER)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'ai_model="$(AI_MODEL)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'ai_base_url="$(AI_BASE_URL)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'openai_api_key="$(OPENAI_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'anthropic_api_key="$(ANTHROPIC_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'azure_openai_api_key="$(AZURE_OPENAI_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'langchain_tracing=$(LANGCHAIN_TRACING_V2)' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'langchain_endpoint="$(LANGCHAIN_ENDPOINT)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	@echo 'langchain_api_key="$(LANGCHAIN_API_KEY)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars
	echo 'langchain_project="$(LANGCHAIN_PROJECT)"' >> $(IAC_DIR)/$(STACK_ENV).auto.tfvars

# Deploy to Azure
azure-deploy-no-deps:
	cd $(IAC_DIR) && terraform apply -auto-approve \
	&& terraform output -json > ../outputs-$(STACK_ENV).json


azure-deploy: build stack-init make-tf-vars
	cd $(IAC_DIR) && terraform apply -auto-approve \
	&& terraform output -json > ../outputs-$(STACK_ENV).json

azure-plan: build stack-init make-tf-vars
	cd $(IAC_DIR) && terraform plan

# Destroy Azure resources
azure-destroy: stack-init make-tf-vars
	cd $(IAC_DIR) && terraform apply -destroy -auto-approve

azure-destroy-all: azure-destroy azure-destroy-tf
# source packaging and assembly
PKG_SUBDIRS := $(dir $(shell find src -name "makefile"))

build: $(PKG_SUBDIRS)
	for i in $(PKG_SUBDIRS); do \
        $(MAKE) -C $$i azure-build; \
    done

clean-src: $(PKG_SUBDIRS)
	for i in $(PKG_SUBDIRS); do \
        $(MAKE) -C $$i clean; \
    done

# Testing helpers

tail-inbox-logs:
	$(AZ_CMD) webapp log tail --resource-group $(RESOURCE_GROUP) --name $(APP_NAME)-inbox-$(STACK_ENV)

azure-upload-pdf:
	$(AZ_CMD) storage blob upload \
		--connection-string "$(AZURE_STORAGE_CONNECTION_STRING)" \
		--container-name $(STORAGE_CONTAINER_INBOX) \
		--connection-string $$($(AZ_CMD) storage account show-connection-string --name $(STORAGE_ACCOUNT) --output tsv) \
		--overwrite \
		--file ./docs/pdf-text-normal.pdf \
		--name pdf-text-normal.pdf

azure-list-inbox:
	$(AZ_CMD) storage blob list \
		--connection-string "$(AZURE_STORAGE_CONNECTION_STRING)" \
		--container-name $(STORAGE_CONTAINER_INBOX) \
		--connection-string $$($(AZ_CMD) storage account show-connection-string --name $(STORAGE_ACCOUNT) --output tsv) \
		--output table

azure-delete-pdf:
	$(AZ_CMD) storage blob delete \
		--container-name $(STORAGE_CONTAINER_INBOX) \
		--connection-string $$($(AZ_CMD) storage account show-connection-string --name $(STORAGE_ACCOUNT) --output tsv) \
		--name pdf-text-normal.pdf || true

azure-upload-md:
	$(AZ_CMD) storage blob upload \
		--connection-string "$(AZURE_STORAGE_CONNECTION_STRING)" \
		--container-name $(STORAGE_CONTAINER_OUTBOX) \
		--connection-string $$($(AZ_CMD) storage account show-connection-string --name $(STORAGE_ACCOUNT) --output tsv) \
		--overwrite \
		--file ./docs/pdf-text-normal-final.md \
		--name pdf-text-normal-final.md

azure-list-outbox:
	$(AZ_CMD) storage blob list \
		--container-name $(STORAGE_CONTAINER_OUTBOX) \
		--connection-string $$($(AZ_CMD) storage account show-connection-string --name $(STORAGE_ACCOUNT) --output tsv) \
		--output table

# Format and lint
.PHONY: format
format:
	$(ruff) format src

.PHONY: lint
lint:
	$(ruff) check src/ --fix

.PHONY: typecheck
typecheck:
	$(pyright)

.PHONY: typecheck-stats
typecheck-stats:
	$(pyright) --stats

.PHONY: checkall
checkall: format typecheck lint
