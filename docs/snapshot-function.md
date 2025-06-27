# OpenSearch Snapshot Lambda Function

## Overview

The OpenSearch Snapshot Lambda function automates the process of creating backups (snapshots) of your OpenSearch domain. These snapshots are stored in an S3 bucket, providing a reliable backup solution for your OpenSearch data.

## How It Works

### Process Flow

1. **Function Trigger**:
   - The function is typically triggered on a schedule via CloudWatch Events/EventBridge
   - It can also be invoked manually for on-demand snapshots

2. **Repository Management**:
   - The function first checks if the S3 repository for snapshots already exists by making a GET request to `/_snapshot/s3-snapshots`
   - If the repository doesn't exist, it creates one with the specified S3 bucket and IAM role

3. **Snapshot Creation**:
   - Generates a unique timestamp-based name for the snapshot (format: `snapshot-YYYY-MM-DD-HH-MM-SS`)
   - Makes a PUT request to OpenSearch to initiate the snapshot
   - Configures the snapshot to include all indices and global state

4. **Response Handling**:
   - Returns success (200) if the snapshot is successfully initiated
   - Returns error (500) if any issues occur during the process

### Authentication

The function uses AWS4Auth to sign requests to OpenSearch using the Lambda function's execution role credentials, ensuring secure communication.

## Implementation Details

### Function Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENSEARCH_ENDPOINT` | The endpoint URL of your OpenSearch domain (without https://) |
| `REGION` | AWS region where the OpenSearch domain is deployed |
| `BUCKET_NAME` | Name of the S3 bucket where snapshots will be stored |
| `ROLE_ARN` | ARN of the IAM role that OpenSearch will assume to access the S3 bucket |

### IAM Permissions Required

The Lambda execution role needs:
- `es:ESHttpGet`, `es:ESHttpPut` - To interact with OpenSearch APIs
- `iam:PassRole` - To pass the S3 access role to OpenSearch

### Repository Configuration

The S3 repository is created with the following settings:
- **Type**: `s3` (S3 repository plugin)
- **Bucket**: Specified by the `BUCKET_NAME` environment variable
- **Region**: Same region as the OpenSearch domain
- **Role ARN**: IAM role that OpenSearch will assume to access S3

### Snapshot Configuration

Each snapshot is created with these settings:
- **Indices**: `*` (All indices)
- **Ignore Unavailable**: `true` (Skip indices that don't exist)
- **Include Global State**: `true` (Include cluster settings and templates)

### Code Structure

- **Imports**: boto3, datetime, requests, and requests_aws4auth libraries
- **Helper Functions**:
  - `create_repository()`: Sets up the S3 snapshot repository
  - `take_snapshot()`: Initiates the actual snapshot process
- **Handler Function**: Main entry point that orchestrates the process
- **Error Handling**: Comprehensive try/except blocks with logging

## Deployment

This Lambda function is deployed using Terraform with the following components:

1. **Lambda Function Resource**: Defines the function configuration
2. **IAM Role**: Provides necessary permissions
3. **Environment Variables**: Sets required configuration
4. **CloudWatch Event Rule**: Sets up scheduled execution (e.g., daily)

## Scheduling

The function is typically scheduled to run on a regular basis:
- **Daily backups**: `rate(1 day)` or `cron(0 0 * * ? *)`
- **Weekly backups**: `rate(7 days)` or `cron(0 0 ? * SUN *)`

This scheduling is configured in the Terraform module via the `schedule_expression` parameter.

## Backup Strategy Considerations

### Retention Policy

This function does not implement a snapshot retention policy. For a complete backup strategy, consider:
- Implementing a separate function to delete old snapshots
- Using S3 lifecycle policies to manage snapshot storage costs

### Monitoring

Monitor successful snapshot creation by:
- Setting up CloudWatch Alarms on Lambda failures
- Implementing a notification system for failed snapshots
- Checking snapshot status via the OpenSearch API

## Troubleshooting

### Common Issues

1. **Repository Creation Failures**:
   - Verify the IAM role has proper permissions to access the S3 bucket
   - Ensure the S3 bucket exists and is in the correct region

2. **Snapshot Failures**:
   - Check for disk space issues in the OpenSearch cluster
   - Verify network connectivity between Lambda and OpenSearch

3. **Permission Errors**:
   - Ensure the `ROLE_ARN` is correctly configured and has the necessary trust relationship
   - Verify OpenSearch domain access policy allows the Lambda function's role

### Logging

The function logs detailed information to CloudWatch Logs, including:
- Repository existence checks
- Repository creation status
- Snapshot initiation status
- Any errors encountered 