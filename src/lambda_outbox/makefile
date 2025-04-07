# Azure specific build
.PHONY: azure-build
azure-build:
	mkdir -p dist
	cp -r src/* dist/
	# Install dependencies targeting the Azure Functions Linux AMD64 environment
	pip install \
		--platform $(PIP_PLATFORM) \
		--implementation cp \
		--python-version $(PYTHON_VERSION) \
		--only-binary=:all: \
		--target=dist/ \
		-r requirements.txt
	cd dist && zip -r ../function.zip *
	echo "Azure Function package created at function.zip"

# The manylinux2014_x86_64 platform tag ensures broad compatibility with Linux distributions used in Azure.
# --only-binary=:all: prevents pip from trying to build packages from source, ensuring you only get pre-compiled wheels for the target platform.
# If a package doesn't have a wheel for the specified platform, this command will fail,  which is often desired behavior
# as it indicates a potential deployment issue early.
