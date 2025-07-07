# Environment Setup for OpenSearch Lambda Automation

This document outlines the environment setup required for deploying the Lambda functions and S3 bucket to work with an existing OpenSearch domain.

## Prerequisites

1. **AWS Account**
   - Active AWS account with appropriate permissions
   - AWS CLI configured with admin credentials

2. **Existing OpenSearch Domain**
   - Working OpenSearch/Elasticsearch domain
   - Admin credentials for the domain
   - Domain endpoint URL

3. **Development Environment**
   - Terraform >= 1.0.0
   - Python 3.9+
   - PowerShell (for Windows) or Bash (for Linux/Mac)

## Environment Variables

Before deployment, update the following environment variables in `terraform/environments/dev/main.tf`:

```terraform
environment_variables = {
  OPENSEARCH_ENDPOINT = "your-opensearch-domain.us-east-2.es.amazonaws.com"
  REGION              = "us-east-2"
  MASTER_USERNAME     = "admin"
  MASTER_PASSWORD     = "YourStrongPassword123!"
}
```

## AWS Region Configuration

This project is configured for the `us-east-2` region. If your OpenSearch domain is in a different region:

1. Update the region in the AWS provider:
   ```terraform
   provider "aws" {
     region = "your-region"
   }
   ```

2. Update region references in the Lambda functions:
   ```terraform
   environment_variables = {
     REGION = "your-region"
     # Other variables...
   }
   ```

3. Update region in the Lambda Python code (if hardcoded):
   ```python
   region = os.environ.get('REGION', "your-region")
   ```

## S3 Bucket Configuration

The S3 bucket name must be globally unique. Update the bucket name in `terraform/environments/dev/main.tf`:

```terraform
resource "aws_s3_bucket" "snapshot_bucket" {
  bucket = "your-unique-bucket-name"
  # ...
}
```

## IAM Role Names

The IAM role names should be unique in your AWS account. Update role names if needed:

```terraform
resource "aws_iam_role" "opensearch_snapshot_role" {
  name = "your-environment-opensearch-snapshot-role"
  # ...
}
```

## Lambda Function Configuration

For each Lambda function, you may need to adjust:

1. **Function Name**: Update function names to prevent conflicts
2. **Memory Size**: Adjust based on workload (default: 128MB/256MB)
3. **Timeout**: Adjust based on workload (default: 120s/300s)
4. **Runtime**: Use Python 3.9 or compatible version

Example:
```terraform
module "snapshot_lambda" {
  # ...
  lambda_name   = "your-env-opensearch-snapshot-lambda"
  memory_size   = 256
  timeout       = 300
  runtime       = "python3.9"
  # ...
}
```

## Lambda Package Preparation

Before deploying, prepare the Lambda packages:

1. Windows:
   ```powershell
   .\prepare-lambda-packages.ps1
   ```

2. Linux/Mac:
   ```bash
   chmod +x prepare-lambda-packages.sh
   ./prepare-lambda-packages.sh
   ```

This script will:
- Install required Python dependencies
- Package Lambda functions with dependencies
- Create ZIP files in the `terraform/modules/lambda/files` directory

## OpenSearch Domain Permissions

Ensure your existing OpenSearch domain has the necessary permissions:

1. **Fine-Grained Access Control**: Must be enabled for internal user mapping
2. **Domain Access Policy**: Must allow access from Lambda functions
3. **Service-Linked Role**: Must exist for OpenSearch service

Example OpenSearch domain access policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/lambda-execution-role"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:us-east-2:123456789012:domain/your-domain-name/*"
    }
  ]
}
```

## Environment Customization

To customize for different environments (dev, test, prod):

1. Create separate environment directories:
   ```
   terraform/environments/dev/
   terraform/environments/test/
   terraform/environments/prod/
   ```

2. Copy and customize `main.tf` for each environment

3. Use environment-specific variables:
   ```terraform
   environment = "dev" # or "test", "prod"
   ```

## Deployment Steps

1. Configure AWS CLI:
   ```bash
   aws configure
   ```

2. Update environment variables in `terraform/environments/dev/main.tf`

3. Prepare Lambda packages:
   ```powershell
   .\prepare-lambda-packages.ps1
   ```

4. Navigate to the environment directory:
   ```bash
   cd terraform/environments/dev
   ```

5. Initialize Terraform:
   ```bash
   terraform init
   ```

6. Preview changes:
   ```bash
   terraform plan
   ```

7. Apply changes:
   ```bash
   terraform apply
   ```

## Post-Deployment Verification

After deployment, verify:

1. S3 bucket was created successfully
2. Lambda functions were created and configured correctly
3. IAM roles and policies were created with proper permissions
4. CloudWatch Event rule for snapshot schedule was created

Use the AWS Management Console or CLI to check these resources. 