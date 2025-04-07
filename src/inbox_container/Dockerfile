FROM mcr.microsoft.com/azure-functions/python:4-python3.11

ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends poppler-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt /home/site/wwwroot/
RUN pip install --no-cache-dir -r /home/site/wwwroot/requirements.txt

# Create the function directory
RUN mkdir -p /home/site/wwwroot/QueueTrigger

# Copy function code
COPY src/handler.py /home/site/wwwroot/QueueTrigger/
COPY src/function.json /home/site/wwwroot/QueueTrigger/
COPY src/ai_ocr /home/site/wwwroot/ai_ocr/

# Copy host.json
COPY src/host.json /home/site/wwwroot/host.json