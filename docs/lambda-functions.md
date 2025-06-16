# Lambda Functions Documentation

This document explains the Lambda functions used in the OpenSearch terraform project.

## Overview

The project uses two main Lambda functions:

1. **IAM User Mapper** - Maps IAM users to OpenSearch roles
2. **Snapshot Function** - Creates backups of the OpenSearch domain

## IAM User Mapper Function

### Purpose
The IAM User Mapper function automates the process of granting IAM users access to OpenSearch by mapping them to OpenSearch security roles.

### How It Works
1. **Receives Request**: The function expects an event with a `userName` parameter.
2. **Retrieves IAM ARN**: It uses the AWS SDK to get the ARN (Amazon Resource Name) of the specified IAM user.
3. **Maps User to Role**: It maps the user ARN to the "all_access" role in OpenSearch by:
   - Retrieving current role mappings
   - Checking if the user is already mapped
   - Appending the user ARN to the role if not already present
   - Updating the role mapping via the OpenSearch API

### Configuration
- **Runtime**: Python
- **Required Environment Variables**:
  - `OPENSEARCH_ENDPOINT`: The endpoint of your OpenSearch domain (without https://)
  - `REGION`: AWS region where OpenSearch is deployed

### Invocation
This function can be invoked manually or through other services with the following event structure:
```json
{
  "userName": "example-user"
}
```

## Snapshot Function

### Purpose
This function automates the backup process for OpenSearch by creating and managing snapshots that are stored in an S3 bucket.

### How It Works
1. **Repository Management**: 
   - Checks if an S3 repository for snapshots exists
   - Creates the repository if it doesn't exist
   
2. **Snapshot Creation**:
   - Generates a timestamped name for the snapshot
   - Initiates a snapshot of all OpenSearch indices
   - Includes global state in the backup

### Configuration
- **Runtime**: Python
- **Required Environment Variables**:
  - `OPENSEARCH_ENDPOINT`: The endpoint of your OpenSearch domain (without https://)
  - `REGION`: AWS region where OpenSearch is deployed
  - `BUCKET_NAME`: Name of the S3 bucket to store snapshots
  - `ROLE_ARN`: ARN of the IAM role that OpenSearch service will assume to access the S3 bucket

### Scheduling
This function is typically scheduled to run on a regular basis (e.g., daily) using CloudWatch Events/EventBridge.

## Terraform Integration

These Lambda functions are deployed through the Terraform configuration in `terraform/modules/lambda/main.tf`, which:

1. Creates an IAM role with appropriate permissions
2. Packages the Lambda code
3. Deploys the Lambda function
4. Sets up environment variables
5. Configures CloudWatch scheduling if specified

## Dependencies

Both functions require:
- `boto3`: AWS SDK for Python
- `requests`: HTTP library for API calls
- `requests_aws4auth`: Library for AWS request signing

These dependencies are defined in the respective `requirements.txt` files in each function's directory.

## Troubleshooting

Common issues:
- **403 Forbidden errors**: Check IAM permissions and role assignments
- **Connection errors**: Verify VPC configuration if Lambda is deployed in a VPC
- **Timeout errors**: Consider increasing the Lambda timeout setting 