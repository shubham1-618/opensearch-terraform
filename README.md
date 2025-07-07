# OpenSearch AWS Lambda Automation

This project provides Lambda functions and S3 bucket configurations for enhancing an existing OpenSearch domain with automated snapshots and IAM user/role mapping.

## Overview

This project deploys:

1. **Lambda Functions**:
   - **IAM User Mapper**: Maps IAM users to OpenSearch roles and creates internal users
   - **Role Mapper**: Maps IAM roles to OpenSearch roles
   - **Snapshot**: Creates and manages automated hourly snapshots

2. **S3 Bucket**:
   - Securely configured for storing OpenSearch snapshots

## Features

- **Automated hourly snapshots**: Lambda function scheduled to take snapshots every hour
- **IAM user/role mapping**: Automatic mapping of IAM users and roles to OpenSearch roles
- **Fine-grained access control**: Secure access management for OpenSearch
- **Hardcoded credentials**: Simplified setup using hardcoded credentials for the existing OpenSearch domain

## Documentation

- [Environment Setup Guide](./docs/environment_setup.md) - How to set up your environment
- [AWS Resources](./docs/aws_resources.md) - Details of all AWS resources created
- [Manual Steps](./docs/manualstep.md) - Manual steps required after deployment
- [Manual Lambda Creation Guide](./docs/manual_lambda_creation.md) - Step-by-step instructions for creating Lambda functions in AWS Console

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate permissions
- Existing OpenSearch domain
- Python 3.9+ (for local Lambda development)

## Directory Structure

```
opensearch-terraform/
├── docs/
│   ├── aws_resources.md        # Details of AWS resources
│   ├── environment_setup.md    # Environment setup guide
│   ├── manual_lambda_creation.md # Guide for manual Lambda creation
│   └── manualstep.md           # Manual steps documentation
├── lambda/
│   ├── snapshot/             # Lambda code for snapshot automation
│   │   ├── index.py          # Main Lambda function code
│   │   └── requirements.txt  # Python dependencies
│   ├── iam_mapper/           # Lambda code for IAM user mapping
│   │   ├── index.py          # Main Lambda function code
│   │   └── requirements.txt  # Python dependencies
│   └── role_mapper/          # Lambda code for IAM role mapping
│       ├── index.py          # Main Lambda function code
│       └── requirements.txt  # Python dependencies
├── terraform/
│   ├── environments/
│   │   └── dev/              # Development environment configuration
│   │       └── main.tf       # Main Terraform configuration
│   └── modules/
│       └── lambda/           # Lambda functions module
└── prepare-lambda-packages.ps1  # Script to prepare Lambda packages
```

## Deployment Instructions

1. Clone the repository
2. Update Lambda function variables in `terraform/environments/dev/main.tf`:
   - OpenSearch endpoint
   - Region
   - Admin username/password
3. Prepare the Lambda packages:

```powershell
# Run the prepare-lambda-packages script
.\prepare-lambda-packages.ps1
```

4. Deploy the infrastructure:

```bash
# Navigate to the environment directory
cd opensearch-terraform/terraform/environments/dev

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply
```

### Alternative: Manual Deployment

If you prefer to create resources manually through the AWS Console instead of using Terraform:

1. Follow the step-by-step instructions in [Manual Lambda Creation Guide](./docs/manual_lambda_creation.md)
2. This guide covers creating all required IAM roles, S3 bucket, and Lambda functions

## Using the Lambda Functions

### IAM User Mapper

Invoke with:

```json
{
  "userName": "opensearch-user",
  "createIfMissing": true,
  "createInternalUser": true,
  "opensearchRole": "all_access",
  "forceCredentialReset": false
}
```

### Role Mapper

Invoke with:

```json
{
  "roleName": "opensearch-role",
  "opensearchRole": "all_access"
}
```

### Snapshot

The snapshot Lambda function runs automatically every hour. No manual invocation needed.

## Cleaning Up

To destroy all created resources:

```bash
# Navigate to the environment directory
cd opensearch-terraform/terraform/environments/dev

# Destroy resources
terraform destroy
``` 