# Manual Steps for OpenSearch Lambda Automation

This document outlines the manual steps required to work with the Lambda functions and your existing OpenSearch domain.

## Table of Contents
1. [Updating Lambda Environment Variables](#updating-lambda-environment-variables)
2. [Triggering Lambda Functions Manually](#triggering-lambda-functions-manually)
3. [Creating and Configuring S3 Snapshot Repository](#creating-and-configuring-s3-snapshot-repository)
4. [Restoring from Snapshots](#restoring-from-snapshots)
5. [Accessing OpenSearch Dashboard](#accessing-opensearch-dashboard)

## Updating Lambda Environment Variables

Before deploying with Terraform, update the environment variables in `terraform/environments/dev/main.tf` with your existing OpenSearch domain information:

1. Open `terraform/environments/dev/main.tf`
2. Find each Lambda function configuration and update:
   - `OPENSEARCH_ENDPOINT`: Your OpenSearch domain endpoint (without https://)
   - `REGION`: AWS region where your OpenSearch domain is located
   - `MASTER_USERNAME`: Admin username for your OpenSearch domain
   - `MASTER_PASSWORD`: Admin password for your OpenSearch domain

Example:
```terraform
environment_variables = {
  OPENSEARCH_ENDPOINT = "your-opensearch-domain.region.es.amazonaws.com"
  REGION              = "us-east-2"
  MASTER_USERNAME     = "your-admin-username"
  MASTER_PASSWORD     = "your-admin-password"
}
```

## Triggering Lambda Functions Manually

### IAM User Mapper Lambda

This Lambda function maps IAM users to OpenSearch roles.

1. Open the AWS Lambda console
2. Navigate to the function `dev-opensearch-iam-user-mapper`
3. Click on the "Test" tab
4. Create a new event with the following JSON structure:

```json
{
  "userName": "opensearch-user",
  "createIfMissing": true,
  "createInternalUser": true,
  "opensearchRole": "all_access",
  "forceCredentialReset": false
}
```

5. Click "Test" to invoke the function
6. The function will:
   - Create the IAM user if it doesn't exist
   - Generate a secure password and access keys
   - Create an internal user in OpenSearch
   - Map the user to the specified role

### Role Mapper Lambda

This Lambda function maps IAM roles to OpenSearch roles.

1. Open the AWS Lambda console
2. Navigate to the function `dev-opensearch-role-mapper`
3. Click on the "Test" tab
4. Create a new event with the following JSON structure:

```json
{
  "roleName": "your-role-name",
  "opensearchRole": "all_access"
}
```

5. Click "Test" to invoke the function
6. The function will map the IAM role to the specified OpenSearch role

## Creating and Configuring S3 Snapshot Repository

### Automatic Configuration

The snapshot Lambda function automatically creates an S3 repository when it runs for the first time. No manual action is required.

### Manual Configuration via Dashboard

If you want to verify or manually configure the S3 repository:

1. Log in to your OpenSearch Dashboard
2. Navigate to "Management" > "Snapshot Management" > "Repositories"
3. Click "Register repository"
4. Select "S3" as the repository type
5. Enter:
   - Repository name: `s3-snapshots`
   - Bucket name: `dev-opensearch-snapshots-abcdef123456` (or your actual bucket name)
   - Region: `us-east-2` (or your actual region)
   - Role ARN: `arn:aws:iam::123456789012:role/dev-opensearch-snapshot-role` (from Terraform output)

## Restoring from Snapshots

To restore an index from a snapshot:

1. Log in to your OpenSearch Dashboard
2. Navigate to "Management" > "Snapshot Management" > "Snapshots"
3. Find the snapshot you want to restore from
4. Click "Restore" next to the snapshot
5. In the restore dialog:
   - Select the indices you want to restore
   - Optionally, rename indices during restore
   - Configure additional restore settings
6. Click "Restore" to start the restoration process

### Restore via API

You can also restore snapshots via the API:

```bash
# Get a list of available snapshots
curl -XGET "https://your-opensearch-endpoint.us-east-2.es.amazonaws.com/_snapshot/s3-snapshots/_all" -u "admin:password"

# Restore a specific snapshot
curl -XPOST "https://your-opensearch-endpoint.us-east-2.es.amazonaws.com/_snapshot/s3-snapshots/snapshot-name/_restore" -u "admin:password" -d '{
  "indices": "index-to-restore",
  "rename_pattern": "index-(.+)",
  "rename_replacement": "restored-index-$1"
}'
```

## Accessing OpenSearch Dashboard

To access your OpenSearch Dashboard:

1. Navigate to your OpenSearch Dashboard URL:
   `https://your-opensearch-endpoint.us-east-2.es.amazonaws.com/_dashboards/`

2. Log in with:
   - Username: The admin username for your domain
   - Password: The admin password for your domain

3. If you've mapped IAM users, they can also log in with their credentials

### For Public Access OpenSearch Domains

If your OpenSearch domain has public access:
- Access the dashboard directly using the dashboard URL

### For VPC OpenSearch Domains

If your OpenSearch domain is in a VPC:
1. Connect to a bastion host or EC2 instance in the same VPC
2. Set up an SSH tunnel:

```bash
ssh -i your-key.pem -N -L 9200:your-opensearch-endpoint.us-east-2.es.amazonaws.com:443 ec2-user@bastion-host-ip
```

3. Access the dashboard through: `https://localhost:9200/_dashboards/`

## Troubleshooting

### Lambda Function Errors

If the Lambda functions encounter errors:
1. Check CloudWatch Logs for the specific function
2. Verify the OpenSearch domain endpoint and credentials
3. Ensure IAM permissions are correctly configured

### Snapshot Failures

If snapshots fail:
1. Check that the S3 bucket exists
2. Verify the OpenSearch domain has permissions to access the bucket
3. Check the IAM role has the correct permissions

### Authentication Issues

If you can't authenticate:
1. Verify admin credentials
2. Check that the user is correctly mapped to a role
3. Look for any security group restrictions 