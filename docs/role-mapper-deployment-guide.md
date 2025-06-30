# Role Mapper Lambda Deployment Guide

This guide walks through the steps to deploy the IAM Role Mapper Lambda function and fix snapshot permissions issues.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed
- Python 3.9+ installed

## Deployment Steps

Follow these steps to deploy the role mapper Lambda and fix snapshot permissions:

### 1. Prepare the Lambda Package

First, prepare the Lambda package using the provided PowerShell script:

```powershell
.\prepare-lambda-packages.ps1
```

This script:
- Creates the package directory structure
- Installs dependencies for the role_mapper Lambda
- Copies the Lambda code to the package directory

### 2. Deploy Using Terraform

Apply the Terraform configuration to deploy the Role Mapper Lambda:

```bash
cd terraform/environments/dev
terraform init
terraform apply
```

This will:
- Create the role_mapper Lambda function
- Configure its permissions and environment variables
- Connect it to the VPC and security groups

### 3. Map the Snapshot Lambda Role

Once the Role Mapper Lambda is deployed, use the provided script to map the Snapshot Lambda's IAM role:

```bash
python ../../../lambda/role_mapper/invoke-for-snapshot.py --region <your-region> --environment dev
```

This script will:
- Get the Snapshot Lambda's execution role ARN
- Invoke the Role Mapper Lambda to map it to OpenSearch roles
- Print the response for each mapping operation

### 4. Test the Snapshot Lambda

Test the Snapshot Lambda to ensure it can now create repositories and snapshots:

```bash
aws lambda invoke --function-name dev-opensearch-snapshot-lambda \
  --payload '{}' snapshot-test-response.json
```

Check the response in the output file:

```bash
cat snapshot-test-response.json
```

If successful, you should see a 200 status code and a message indicating the snapshot was initiated successfully.

## Manual Mapping (If Needed)

If you need to map roles manually, you can directly invoke the Role Mapper Lambda:

```bash
aws lambda invoke --function-name dev-opensearch-role-mapper \
  --payload '{
    "roleName": "dev-opensearch-snapshot-lambda-execution-role",
    "opensearchRole": "all_access"
  }' map-role-response.json
```

## Troubleshooting

### Common Issues

1. **VPC Access Issues**: Ensure the Lambda function has proper VPC access to the OpenSearch domain.

2. **OpenSearch Security Plugin**: Verify that the OpenSearch security plugin is properly configured.

3. **Terraform State**: If you've previously manually configured role mappings, Terraform might overwrite them. Use the Role Mapper Lambda after each Terraform apply.

4. **IAM Permissions**: Ensure the Role Mapper Lambda has the necessary IAM permissions to retrieve role information.

### Verifying Role Mappings

To verify the role mappings in OpenSearch:

1. Log in to the OpenSearch dashboard
2. Navigate to Security > Roles > all_access
3. Check the "Mapped users" tab
4. Verify the Snapshot Lambda's execution role ARN is listed under "Backend roles"

## Maintenance

After updates or redeployments of the OpenSearch domain, you may need to re-map roles. Use the invoke-for-snapshot.py script to quickly re-establish the necessary role mappings. 