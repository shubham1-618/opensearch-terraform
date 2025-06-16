# OpenSearch AWS Terraform Project

This project deploys a fully configured OpenSearch domain on AWS with automated snapshots, IAM user mapping, and secure access via a jump server.

## Architecture

![Project Architecture](https://mermaid.ink/img/pako:eNp1kslqwzAQhl9FzCkFd6dO6KXQkr2hjRfRstaOK0uuJSdgyLt3ZDnQLnrQzP9_g5ZDapRI1NQrl_VJQcOd5zqrqbYt9BqK3KjGvmvnHRSEWe9B2s5BYbXHrmWkeJY6W4Fw4z5C4aRmweFOhsIaYSTAYYrdMSvACGkOYWEsfAfYMx15r1BerJp1wMMXJ3Qno3ztBy-NTmajmTGSWxnELys3SP0fP_GDQYPXfatEfBtjO-l1A9XiGxf2gRnJvDexduk36wOLH8K7x8wbl73FaZ80FRjbxfXlYVHbYt5eSov3PEtRjG-J-A--2F8w-ju8YrqKmKbDpBZTUZlQNMswP6eqGWL7po6UcZlaz1QYoZfBxLQbQyG_Spj4nFYSBXfKnIJZIFvLG6qDu6SXdKOxPVGmJz_mG9U?)

The project creates:

- OpenSearch domain with 3 data nodes using t3.small instances
- S3 bucket for storing snapshots
- Lambda functions for automated snapshots and IAM user mapping
- VPC with public and private subnets
- Security groups for controlled access
- EC2 jump server for secure access via SSH tunneling

## Features

- **Parameterized snapshots**: Enable/disable snapshot creation via Terraform variables
- **Automated hourly snapshots**: Lambda function scheduled to take snapshots every hour
- **IAM user mapping**: Automatic mapping of IAM users to the OpenSearch dashboard
- **Fine-grained access control**: Secure access to the OpenSearch domain
- **SSH tunneling**: Access OpenSearch dashboard securely through the jump server
- **Modular design**: Easy to customize and extend

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate permissions
- SSH key pair named 'opensearch-jump-server-key' (see manual steps)
- Python 3.9+ (for local Lambda development)

## Directory Structure

```
opensearch-terraform/
├── docs/
│   └── manualstep.md         # Manual steps documentation
├── lambda/
│   ├── snapshot/             # Lambda code for snapshot automation
│   │   ├── index.py          # Main Lambda function code
│   │   └── requirements.txt  # Python dependencies
│   └── iam_mapper/           # Lambda code for IAM user mapping
│       ├── index.py          # Main Lambda function code
│       └── requirements.txt  # Python dependencies
└── terraform/
    ├── environments/
    │   └── dev/              # Development environment configuration
    │       ├── main.tf       # Main Terraform configuration
    │       ├── variables.tf  # Variable definitions
    │       ├── outputs.tf    # Output definitions
    │       └── terraform.tfvars # Variable values
    └── modules/
        ├── ec2/              # Jump server module
        ├── lambda/           # Lambda functions module
        ├── opensearch/       # OpenSearch domain module
        └── vpc/              # VPC and networking module
```

## Deployment Instructions

1. Clone the repository
2. Make sure you have the necessary AWS credentials configured
3. Create the SSH key pair in AWS Console (see docs/manualstep.md)
4. Modify variables in `terraform/environments/dev/terraform.tfvars` as needed
5. Deploy the infrastructure:

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

## Usage

Once deployed, you can:

1. Connect to the OpenSearch dashboard using SSH tunneling (see docs/manualstep.md)
2. Map IAM users to the OpenSearch dashboard by using the Lambda function (see docs/manualstep.md)
3. Take manual snapshots or rely on the hourly automated snapshots

## Cleaning Up

To destroy all created resources:

```bash
# Navigate to the environment directory
cd opensearch-terraform/terraform/environments/dev

# Destroy resources
terraform destroy
```

## Manual Steps

For required manual steps, please refer to [Manual Steps Documentation](./docs/manualstep.md). 