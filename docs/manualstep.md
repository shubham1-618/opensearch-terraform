# Manual Steps for OpenSearch Terraform Project

This document outlines manual steps required for complete setup of the OpenSearch environment.

## Terraform Deployment Instructions

To deploy the OpenSearch infrastructure using Terraform:

1. Ensure you have Terraform installed (version >= 1.0.0)
2. Navigate to the environment directory:
   ```
   cd opensearch-terraform/terraform/environments/dev
   ```
3. Initialize Terraform to download providers and modules:
   ```
   terraform init
   ```
4. Create a plan to see what resources will be created:
   ```
   terraform plan
   ```
5. Apply the configuration to create the resources:
   ```
   terraform apply
   ```
6. When you're done with the resources, you can destroy them:
   ```
   terraform destroy
   ```

## Important Notes

### OpenSearch Service-Linked Roles

This Terraform configuration creates an AWS service-linked role for OpenSearch. This role is required to give Amazon OpenSearch Service permissions to access your VPC. 

If you've previously created this role in your AWS account, you may see an error message like:
```
Error: Error creating service-linked role with name AWSServiceRoleForAmazonOpenSearchService: InvalidInput: Service-linked role AWSServiceRoleForAmazonOpenSearchService already exists.
```

This error can be safely ignored, as it means the role already exists in your account and can be used by the OpenSearch domain.

### OpenSearch Instance Types

When choosing an instance type for OpenSearch, make sure to use the proper format with the `.search` suffix. For example:
- `t3.small.search` instead of `t3.small`
- `m5.large.search` instead of `m5.large`

AWS only allows specific instance types for OpenSearch domains. If you encounter an error related to instance types, check the error message for a list of supported types or refer to the AWS documentation.

## SSH Key Creation

Before deploying the infrastructure with Terraform, create an SSH key pair in the AWS console:

1. Go to EC2 dashboard in the AWS console
2. Navigate to "Key Pairs" in the left sidebar
3. Click "Create key pair"
4. Enter name: `opensearch-jump-server-key`
5. Select key pair type: RSA
6. Select format: .pem
7. Click "Create key pair"
8. The private key file (.pem) will download automatically
9. Save this file securely - you will need it to SSH into the jump server

## SSH Tunneling Instructions

To securely access the OpenSearch dashboard through the jump server:

1. Make sure you have the `opensearch-jump-server-key.pem` file saved locally
2. Set proper permissions on the key file:

```bash
chmod 400 opensearch-jump-server-key.pem
```

3. Create an SSH tunnel with port forwarding to the OpenSearch dashboard:

```bash
ssh -i opensearch-jump-server-key.pem -L 9200:OPENSEARCH_ENDPOINT:443 ec2-user@JUMP_SERVER_PUBLIC_IP
```

Replace:
- `OPENSEARCH_ENDPOINT` with your OpenSearch domain endpoint (without https://)
- `JUMP_SERVER_PUBLIC_IP` with the public IP of the jump server

4. Once the SSH tunnel is established, access the OpenSearch dashboard at:

```
https://localhost:9200/_dashboards/
```

5. Sign in using your IAM credentials

## Configuring S3 Snapshot Repository

### Manual Configuration (via Dashboard)

1. Access the OpenSearch dashboard using SSH tunneling
2. Navigate to "Snapshots Management" > "Repositories"
3. Click "Create repository"
4. Enter the following details:
   - Repository name: `s3-snapshots`
   - Repository type: `S3`
   - Bucket name: Use the bucket created by Terraform
   - Path: `snapshots`
   - Role ARN: Use the role ARN for the OpenSearch snapshot role
5. Click "Create"

### Automated Configuration

The Terraform configuration automatically sets up the S3 repository via the Lambda function. No manual steps are required unless you want to verify the configuration via the dashboard.

## Steps to Restore Snapshot

To restore data from a snapshot:

1. Access the OpenSearch dashboard using SSH tunneling
2. Navigate to "Snapshots Management" > "Snapshots"
3. Select the repository containing the snapshot
4. Find the snapshot you want to restore and click "Restore"
5. In the dialog:
   - Select indices to restore
   - Rename pattern (optional)
   - Adjust restore settings as needed
6. Click "Restore" to begin the restoration process
7. Monitor the restore job in the "Restore Status" section

## Triggering Lambda Functions

### Mapping IAM User to OpenSearch Dashboard

The IAM user mapping Lambda function is triggered automatically when a new IAM user is created. For manual triggering:

1. Go to AWS Lambda console
2. Find the function named `opensearch-iam-user-mapper`
3. Click "Test" tab
4. Create a new test event with the following JSON structure:

```json
{
  "userName": "USERNAME_TO_MAP"
}
```

5. Click "Test" to trigger the function

### Manually Triggering Snapshot Lambda

To manually trigger the snapshot Lambda function:

1. Go to AWS Lambda console
2. Find the function named `dev-opensearch-snapshot-lambda`
3. Click "Test" tab
4. Create a new test event with an empty JSON structure: `{}`
5. Click "Test" to trigger the function

## Troubleshooting

### Dashboard Access Issues

- Verify that the SSH tunnel is properly established
- Check that your IAM user has been mapped correctly
- Review the security group rules for both jump server and OpenSearch domain

### Snapshot Issues

- Check Lambda function CloudWatch logs for errors
- Verify IAM role permissions for the S3 bucket
- Ensure OpenSearch service has permissions to assume the snapshot role

### IAM Mapping Issues

- Check Lambda function CloudWatch logs
- Verify that fine-grained access control is enabled on the OpenSearch domain
- Ensure the mapping role has proper permissions 