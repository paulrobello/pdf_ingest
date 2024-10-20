# AI Vision Contract OCR

## Overview
![Arch Diagram](./arch-diagram.png)

This project uses can use Amazon Bedrock, Anthropic or OpenAI vision models to perform OCR on pdf documents uploaded to a S3 bucket.  
Results are stored as markdown files in a S3 bucket for further processing and storage in a database.  

## Pricing and Metrics for AI portion of the project using Amazon Bedrock
* Claude 3.5 Sonnet input: $0.003/1K, output: $0.015/1K
* It takes roughly 1.5 minutes to OCR a 12-page document. Currently, the project is setup for processing 1 document at a time.
* Vision OCR averages per page: InputTokens:1633  OutputTokens:1095  Latency:33278ms Cost: $0.021324 x12 = $0.255888
* Extracting terms and conditions from the resulting text averages: InputTokens:12555  OutputTokens:520 Latency:16808ms Cost: $0.045465
* Total cost per document: $0.301353
* Total cost per month assuming 4k 12 page documents per month: $3.62

## Pricing for infrastructure
* RDS is a shared resource and should not increase the cost of the project
* S3 storage and data transfer less than $5/mo
* Lambda assuming 4k 12 page documents per month $10/mo
* VPC Bedrock Endpoints $43/mo
* Total cost per month assuming 4k 12 page documents per month: $68/mo

## Total cost per month assuming 4k 12 page documents per month: $68 + $3.62 = $71.62

## Prerequisites for Bedrock
* Bedrock Anthropic models must be enabled in the account
* The following VPC endpoints are required if using in a private SUBNET which is the default for this project:
  * bedrock - Amazon Bedrock Control Plane API actions
  * bedrock-runtime - Amazon Bedrock Runtime API actions
* Not all Bedrock models support all regions us-east-1 is recommended

## Prerequisites for LocalStack deployment

- Generic Development Container (GDC) repo cloned and configured with a LocalStack Pro key. [GDC](https://github.com/devxpod/GDC)

## Prerequisites for OpenAI and other providers (Required if deploying locally)
* Set the environment variable for your chosen provider like OPENAI_API_KEY to your OpenAI API key.
* For local deployment or testing you can create a .env file in the repo root with needed API Keys.
* Example .env file
```bash
OPENAI_API_KEY=your_api_key
ANTHROPIC_API_KEY=your_api_key
# Tracing (optional)
LANGCHAIN_TRACING_V2=false
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
LANGCHAIN_API_KEY=your_api_key
LANGCHAIN_PROJECT=pdf_ingestion
```

## Deploying the project
* For local deployment or testing you can create a .env file in the repo root with needed API Keys.
* From the repo root run:
```bash
run-dev-container.sh
```
* In a separate terminal run the following to open a shell into the GDC:
```bash
docker exec -it pdf_igst-dev-1 bash -l
```
* All future commands will be run in the GDC shell.
* Run the following command to deploy the project to localstack:
```bash
export AWS_PROFILE=localstack
make local-aws-init
make local-deploy
```

## Testing
* Run the following command to test the project locally:
```bash
make local-upload-pdf
make local-list-outbox
```
The s3 listing should show a folder with the name of the request id.  
If you then list that folder you should see the pages of the pdf in image and markdown format.  
There will be a file with a suffix of "-final.md" this is the final output of the pdf.  
Example command to copy final output to local GDC: (Replace 2d85d46b with your request id)
```bash
aws s3 cp s3://pdf-ingestion-lcl-us-east-1/outbox/2d85d46b/pdf-text-normal-final.md .
```

## Configuration
You can select the AI provider you want by setting AI_PROVIDER in the envs.xxx.makefile for the target environment.  
Available providers are Bedrock, Anthropic and OpenAI.  
You can also select the desired model by setting AI_MODEL in the envs.xxx.makefile for the target environment. If you do not select one a default vision model will be used.
