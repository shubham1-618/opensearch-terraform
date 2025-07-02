# OpenSearch Snapshot Scheduling

This document explains how OpenSearch snapshots are scheduled and managed in our infrastructure.

## Overview

OpenSearch snapshots are a crucial backup mechanism that allows us to store indices data in an external location (S3) and restore it when needed. Our infrastructure uses AWS Lambda functions scheduled via CloudWatch Events to automate the snapshot process.

## Architecture

The snapshot solution consists of the following components:

1. **S3 Bucket**: Stores the actual snapshot data
2. **IAM Role**: Allows OpenSearch to access the S3 bucket
3. **Lambda Function**: Handles the snapshot creation process
4. **CloudWatch Event Rule**: Schedules the Lambda function execution
5. **OpenSearch Repository**: A location configuration in OpenSearch that points to our S3 bucket

## Snapshot Process Flow

1. The CloudWatch Event Rule triggers the Lambda function based on a configured schedule
2. The Lambda function checks if a repository exists in OpenSearch
3. If no repository exists, it creates one pointing to the S3 bucket
4. The Lambda function initiates a snapshot with a timestamp-based name
5. OpenSearch performs the snapshot asynchronously

## Configuration Details

### S3 Bucket

The S3 bucket is created with the following naming convention:
```
${environment}-opensearch-snapshots-${random_suffix}
```

### IAM Role

A dedicated IAM role (`${environment}-opensearch-snapshot-role`) is created with permissions to:
- List the S3 bucket contents
- Get, put, and delete objects in the S3 bucket

### Lambda Function

The Lambda function (`${environment}-opensearch-snapshot-lambda`) is configured with:
- Python 3.9 runtime
- 256 MB memory
- 5-minute timeout
- VPC access to reach the OpenSearch domain
- Environment variables:
  - `OPENSEARCH_ENDPOINT`: Domain endpoint without https://
  - `BUCKET_NAME`: S3 bucket name for snapshots
  - `REGION`: AWS region
  - `ROLE_ARN`: IAM role ARN for OpenSearch to access S3

### Scheduling

The Lambda function is scheduled to run hourly using a CloudWatch Event Rule with the following cron expression:
```
cron(0 * * * ? *)
```
This means the snapshot process is initiated at the 0th minute of every hour, every day.

### Repository Configuration

The repository is configured with the following settings:
```json
{
  "type": "s3",
  "settings": {
    "bucket": "${bucket_name}",
    "region": "${region}",
    "role_arn": "${role_arn}"
  }
}
```

### Snapshot Settings

Each snapshot includes:
- All indices (`"indices": "*"`)
- Global state (`"include_global_state": true`)
- Handling of unavailable indices (`"ignore_unavailable": true`)

## Snapshot Naming

Snapshots are named using the following format:
```
snapshot-YYYY-MM-DD-HH-MM-SS
```
Where YYYY-MM-DD-HH-MM-SS is the timestamp when the snapshot was initiated.

## OpenSearch Automated Snapshots

In addition to the Lambda-based snapshots, OpenSearch also has built-in automated snapshots configured to start at hour 1 (1:00 AM UTC). These snapshots are managed by the OpenSearch service and are stored within AWS's infrastructure, not in our S3 bucket.

## Troubleshooting

If snapshots are not being created:
1. Check CloudWatch Logs for the Lambda function execution
2. Verify the Lambda function has proper VPC access to OpenSearch
3. Ensure the IAM role permissions are correct
4. Check if the S3 bucket exists and is accessible

## Restoring from Snapshots

To restore from a snapshot, you can use the OpenSearch API:
```
PUT /_snapshot/s3-snapshots/snapshot-{timestamp}/_restore
```

Additional restore options and parameters can be found in the [OpenSearch documentation](https://opensearch.org/docs/latest/opensearch/snapshot-restore/). 