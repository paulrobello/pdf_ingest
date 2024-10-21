# Infrastructure as Code (IaC) Documentation

This document provides an overview of the Terraform resources used in this project and their dependencies.

## Resources

1. **AWS S3 Bucket (data source)**
   - File: `s3.tf`
   - Purpose: References an existing S3 bucket
   - Dependencies: None

2. **S3 Bucket Notification**
   - File: `s3.tf`
   - Purpose: Sets up notifications for S3 bucket events
   - Dependencies: S3 Bucket, SQS Queue, Lambda Function (outbox)

3. **ECR Repository**
   - File: `lambda_inbox_container.tf`
   - Purpose: Stores Docker images for the inbox container
   - Dependencies: None

4. **Docker Image Build and Push**
   - File: `lambda_inbox_container.tf`
   - Purpose: Builds and pushes Docker image to ECR
   - Dependencies: ECR Repository

5. **Lambda Function (inbox)**
   - File: `lambda_inbox_container.tf`
   - Purpose: Processes incoming documents
   - Dependencies: ECR Repository, Docker Image

6. **IAM Role Policies for Lambda (inbox)**
   - File: `lambda_inbox_container.tf`
   - Purpose: Grants necessary permissions to the inbox Lambda
   - Dependencies: Lambda Function (inbox)

7. **Lambda Function (outbox)**
   - File: `lambda_outbox.tf`
   - Purpose: Processes outgoing documents
   - Dependencies: Custom Lambda Layer

8. **IAM Role Policies for Lambda (outbox)**
   - File: `lambda_outbox.tf`
   - Purpose: Grants necessary permissions to the outbox Lambda
   - Dependencies: Lambda Function (outbox)

9. **SQS Queue**
   - File: `sqs.tf`
   - Purpose: Queues incoming S3 events for processing
   - Dependencies: None

10. **SQS Queue Policy**
    - File: `sqs.tf`
    - Purpose: Allows S3 to send messages to the SQS queue
    - Dependencies: SQS Queue, S3 Bucket

11. **Lambda Event Source Mapping**
    - File: `sqs.tf`
    - Purpose: Connects SQS queue to inbox Lambda function
    - Dependencies: SQS Queue, Lambda Function (inbox)

12. **Custom Lambda Layer**
    - File: `lambda_custom_layer.tf`
    - Purpose: Provides shared code for Lambda functions
    - Dependencies: None

## Dependency Graph

```
S3 Bucket (existing)
  ↓
S3 Bucket Notification → SQS Queue ← SQS Queue Policy
  ↓                        ↓
Lambda (outbox)     Lambda Event Source Mapping
  ↑                        ↓
Custom Lambda Layer  Lambda (inbox) ← Docker Image ← ECR Repository
```

## Notes

- The project uses a mix of container-based (inbox) and regular (outbox) Lambda functions.
- IAM policies are attached to Lambda roles to grant necessary permissions.
- The S3 bucket is pre-existing and referenced as a data source.
- Docker image building and pushing is managed through Terraform null_resources.

Remember to review the `variables.tf` file for customizable parameters and the `outputs.tf` file for important information exposed after applying the Terraform configuration.
