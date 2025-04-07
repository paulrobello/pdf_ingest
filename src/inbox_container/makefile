NEW_CKSUM := $(shell md5sum  src/* src/ai_ocr/* src/ai_ocr/lib/* ../lib/*.py ../lib/utils/*.py ./makefile ./Dockerfile 2>/dev/null| md5sum | cut -f1 -d' ')

CURRENT_DIR := $(shell basename $(CURDIR))

# Get the parent directory name
PARENT_DIR := $(shell basename $(shell dirname $(CURDIR)))

# Get the root directory of the project
ROOT_DIR := $(shell git rev-parse --show-toplevel)

# Include the root makefile
include $(ROOT_DIR)/envs.azure.makefile


clean:
	docker rmi $(ACR_NAME).azurecr.io/$(CURRENT_DIR):latest || true
	docker rmi $(ACR_NAME).azurecr.io/inbox_container:latest || true

# Azure specific assemble target
assemble:
	mkdir -p build
	cp -R requirements.txt build
	cp -R src build
	cp -R ../lib build/src/ai_ocr

# Azure specific build
.PHONY: azure-build
azure-build:
	# Create Docker image for Azure Function
	docker build --platform linux/amd64 -t $(ACR_NAME).azurecr.io/inbox_container:latest .

	# Tag for Azure Container Registry (will be pushed by Terraform)
	echo "Docker image $(ACR_NAME).azurecr.io/inbox_container:latest created for Azure deployment"

	# Write checksum file
	echo $(NEW_CKSUM) > checksum
