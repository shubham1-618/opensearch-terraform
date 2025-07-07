# Manual Lambda Function Creation Guide

This document provides step-by-step instructions for manually creating the Lambda functions in the AWS Management Console rather than using Terraform.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [IAM Role Creation](#iam-role-creation)
3. [S3 Bucket Creation](#s3-bucket-creation)
4. [Lambda Function Package Preparation](#lambda-function-package-preparation)
5. [Snapshot Lambda Function](#snapshot-lambda-function)
6. [IAM User Mapper Lambda Function](#iam-user-mapper-lambda-function)
7. [Role Mapper Lambda Function](#role-mapper-lambda-function)
8. [Testing the Lambda Functions](#testing-the-lambda-functions)

## Prerequisites

- AWS account with administrator access
- Python 3.9+ installed locally
- Basic understanding of AWS services
- Existing OpenSearch domain

## IAM Role Creation

### Create OpenSearch Snapshot Role

1. Open the [IAM console](https://console.aws.amazon.com/iam/)
2. Navigate to **Roles** > **Create role**
3. Select **AWS service** as the trusted entity, then select **OpenSearch** as the use case
4. Click **Next: Permissions**
5. Create a new policy by clicking **Create policy**
   - In the new tab that opens, select the **JSON** tab
   - Enter the following policy:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": "s3:ListBucket",
           "Resource": "arn:aws:s3:::dev-opensearch-snapshots-abcdef123456"
         },
         {
           "Effect": "Allow",
           "Action": [
             "s3:GetObject",
             "s3:PutObject",
             "s3:DeleteObject"
           ],
           "Resource": "arn:aws:s3:::dev-opensearch-snapshots-abcdef123456/*"
         }
       ]
     }
     ```
   - Name the policy `dev-opensearch-snapshot-policy`
   - Click **Create policy**
6. Return to the role creation tab and refresh the policy list
7. Find and select the `dev-opensearch-snapshot-policy`
8. Click **Next: Tags** and add any tags if needed
9. Click **Next: Review**
10. Name the role `dev-opensearch-snapshot-role`
11. Add a description: "Role for OpenSearch to create snapshots in S3"
12. Click **Create role**

### Create Lambda Execution Roles

#### Snapshot Lambda Role

1. Navigate to **Roles** > **Create role**
2. Select **AWS service** as the trusted entity, then select **Lambda** as the use case
3. Click **Next: Permissions**
4. Select the following AWS managed policies:
   - `AWSLambdaBasicExecutionRole`
5. Create a new policy by clicking **Create policy**
   - Select the **JSON** tab
   - Enter the following policy:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "s3:GetObject",
             "s3:PutObject",
             "s3:ListBucket"
           ],
           "Resource": [
             "arn:aws:s3:::dev-opensearch-snapshots-abcdef123456",
             "arn:aws:s3:::dev-opensearch-snapshots-abcdef123456/*"
           ]
         },
         {
           "Effect": "Allow",
           "Action": [
             "es:ESHttpGet",
             "es:ESHttpPut",
             "es:ESHttpPost",
             "es:ESHttpDelete"
           ],
           "Resource": [
             "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*"
           ]
         },
         {
           "Effect": "Allow",
           "Action": [
             "iam:PassRole"
           ],
           "Resource": [
             "arn:aws:iam::123456789012:role/dev-opensearch-snapshot-role"
           ]
         }
       ]
     }
     ```
   - Replace `123456789012` with your AWS account ID
   - Name the policy `dev-opensearch-snapshot-lambda-policy`
   - Click **Create policy**
6. Return to the role creation tab and refresh the policy list
7. Find and select the `dev-opensearch-snapshot-lambda-policy`
8. Click **Next: Tags** and add any tags if needed
9. Click **Next: Review**
10. Name the role `dev-opensearch-snapshot-lambda-role`
11. Add a description: "Execution role for OpenSearch Snapshot Lambda"
12. Click **Create role**

#### IAM User Mapper Lambda Role

1. Navigate to **Roles** > **Create role**
2. Select **AWS service** as the trusted entity, then select **Lambda** as the use case
3. Click **Next: Permissions**
4. Select the following AWS managed policies:
   - `AWSLambdaBasicExecutionRole`
5. Create a new policy by clicking **Create policy**
   - Select the **JSON** tab
   - Enter the following policy:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "es:ESHttpGet",
             "es:ESHttpPut",
             "es:ESHttpPost",
             "iam:GetUser",
             "iam:CreateUser",
             "iam:TagUser",
             "iam:CreateLoginProfile",
             "iam:CreateAccessKey",
             "iam:ListGroupsForUser",
             "iam:AddUserToGroup",
             "iam:UpdateLoginProfile",
             "iam:ListAccessKeys",
             "iam:DeleteAccessKey",
             "sts:GetCallerIdentity"
           ],
           "Resource": [
             "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*",
             "arn:aws:iam::*:user/*",
             "arn:aws:iam::*:group/*"
           ]
         }
       ]
     }
     ```
   - Replace `123456789012` with your AWS account ID
   - Name the policy `dev-opensearch-iam-mapper-lambda-policy`
   - Click **Create policy**
6. Return to the role creation tab and refresh the policy list
7. Find and select the `dev-opensearch-iam-mapper-lambda-policy`
8. Click **Next: Tags** and add any tags if needed
9. Click **Next: Review**
10. Name the role `dev-opensearch-iam-mapper-lambda-role`
11. Add a description: "Execution role for OpenSearch IAM User Mapper Lambda"
12. Click **Create role**

#### Role Mapper Lambda Role

1. Navigate to **Roles** > **Create role**
2. Select **AWS service** as the trusted entity, then select **Lambda** as the use case
3. Click **Next: Permissions**
4. Select the following AWS managed policies:
   - `AWSLambdaBasicExecutionRole`
5. Create a new policy by clicking **Create policy**
   - Select the **JSON** tab
   - Enter the following policy:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "es:ESHttpGet",
             "es:ESHttpPut",
             "es:ESHttpPost",
             "iam:GetRole",
             "sts:GetCallerIdentity"
           ],
           "Resource": [
             "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*",
             "*"
           ]
         }
       ]
     }
     ```
   - Replace `123456789012` with your AWS account ID
   - Name the policy `dev-opensearch-role-mapper-lambda-policy`
   - Click **Create policy**
6. Return to the role creation tab and refresh the policy list
7. Find and select the `dev-opensearch-role-mapper-lambda-policy`
8. Click **Next: Tags** and add any tags if needed
9. Click **Next: Review**
10. Name the role `dev-opensearch-role-mapper-lambda-role`
11. Add a description: "Execution role for OpenSearch Role Mapper Lambda"
12. Click **Create role**

## S3 Bucket Creation

1. Open the [S3 console](https://console.aws.amazon.com/s3/)
2. Click **Create bucket**
3. Enter a unique bucket name: `dev-opensearch-snapshots-abcdef123456`
4. Select the region where your OpenSearch domain is located (e.g., us-east-2)
5. Leave default settings for "Block Public Access" (keep all blocks enabled)
6. Enable bucket versioning (recommended)
7. Add any tags if needed
8. Click **Create bucket**

## Lambda Function Package Preparation

### Prepare Packages Locally

1. Create a directory for each Lambda function:
   ```bash
   mkdir -p snapshot-lambda iam-mapper-lambda role-mapper-lambda
   ```

2. Copy the respective Lambda function code to each directory:
   - Copy `lambda/snapshot/index.py` to `snapshot-lambda/`
   - Copy `lambda/iam_mapper/index.py` to `iam-mapper-lambda/`
   - Copy `lambda/role_mapper/index.py` to `role-mapper-lambda/`

3. Install dependencies for each Lambda function:

   For Snapshot Lambda:
   ```bash
   cd snapshot-lambda
   pip install requests requests_aws4auth boto3 -t .
   ```

   For IAM User Mapper Lambda:
   ```bash
   cd ../iam-mapper-lambda
   pip install requests requests_aws4auth boto3 -t .
   ```

   For Role Mapper Lambda:
   ```bash
   cd ../role-mapper-lambda
   pip install requests requests_aws4auth boto3 -t .
   ```

4. Create ZIP packages for each Lambda function:

   For Windows:
   ```powershell
   # In snapshot-lambda directory
   Compress-Archive -Path * -DestinationPath ../snapshot-lambda.zip -Force

   # In iam-mapper-lambda directory
   Compress-Archive -Path * -DestinationPath ../iam-mapper-lambda.zip -Force

   # In role-mapper-lambda directory
   Compress-Archive -Path * -DestinationPath ../role-mapper-lambda.zip -Force
   ```

   For Linux/Mac:
   ```bash
   # In snapshot-lambda directory
   zip -r ../snapshot-lambda.zip .

   # In iam-mapper-lambda directory
   zip -r ../iam-mapper-lambda.zip .

   # In role-mapper-lambda directory
   zip -r ../role-mapper-lambda.zip .
   ```

## Snapshot Lambda Function

1. Open the [Lambda console](https://console.aws.amazon.com/lambda/)
2. Click **Create function**
3. Select **Author from scratch**
4. Enter function name: `dev-opensearch-snapshot-lambda`
5. Select runtime: **Python 3.9**
6. Under "Permissions", select **Use an existing role**
7. Select the role created earlier: `dev-opensearch-snapshot-lambda-role`
8. Click **Create function**
9. In the "Code" tab:
   - Delete any existing code in the editor
   - Click **Upload from** > **.zip file**
   - Upload the `snapshot-lambda.zip` file
   - Click **Save**
10. In the "Configuration" tab:
    - Click **Environment variables**
    - Add the following environment variables:
      - `OPENSEARCH_ENDPOINT`: Your OpenSearch domain endpoint (without https://)
      - `BUCKET_NAME`: `dev-opensearch-snapshots-abcdef123456`
      - `REGION`: `us-east-2` (or your region)
      - `ROLE_ARN`: The ARN of the OpenSearch snapshot role created earlier
    - Click **Save**
11. In the "General configuration" section:
    - Set memory to **256 MB**
    - Set timeout to **5 minutes**
    - Click **Save**
12. In the "Triggers" tab:
    - Click **Add trigger**
    - Select **EventBridge (CloudWatch Events)**
    - Select **Create a new rule**
    - Enter rule name: `dev-opensearch-snapshot-schedule`
    - Enter description: "Hourly trigger for OpenSearch snapshot Lambda"
    - Rule type: **Schedule expression**
    - Enter schedule expression: `cron(0 * * * ? *)`
    - Check **Enable trigger**
    - Click **Add**

## IAM User Mapper Lambda Function

1. Open the [Lambda console](https://console.aws.amazon.com/lambda/)
2. Click **Create function**
3. Select **Author from scratch**
4. Enter function name: `dev-opensearch-iam-user-mapper`
5. Select runtime: **Python 3.9**
6. Under "Permissions", select **Use an existing role**
7. Select the role created earlier: `dev-opensearch-iam-mapper-lambda-role`
8. Click **Create function**
9. In the "Code" tab:
   - Delete any existing code in the editor
   - Click **Upload from** > **.zip file**
   - Upload the `iam-mapper-lambda.zip` file
   - Click **Save**
10. In the "Configuration" tab:
    - Click **Environment variables**
    - Add the following environment variables:
      - `OPENSEARCH_ENDPOINT`: Your OpenSearch domain endpoint (without https://)
      - `REGION`: `us-east-2` (or your region)
      - `MASTER_USERNAME`: OpenSearch admin username
      - `MASTER_PASSWORD`: OpenSearch admin password
    - Click **Save**
11. In the "General configuration" section:
    - Set memory to **128 MB**
    - Set timeout to **2 minutes**
    - Click **Save**

## Role Mapper Lambda Function

1. Open the [Lambda console](https://console.aws.amazon.com/lambda/)
2. Click **Create function**
3. Select **Author from scratch**
4. Enter function name: `dev-opensearch-role-mapper`
5. Select runtime: **Python 3.9**
6. Under "Permissions", select **Use an existing role**
7. Select the role created earlier: `dev-opensearch-role-mapper-lambda-role`
8. Click **Create function**
9. In the "Code" tab:
   - Delete any existing code in the editor
   - Click **Upload from** > **.zip file**
   - Upload the `role-mapper-lambda.zip` file
   - Click **Save**
10. In the "Configuration" tab:
    - Click **Environment variables**
    - Add the following environment variables:
      - `OPENSEARCH_ENDPOINT`: Your OpenSearch domain endpoint (without https://)
      - `REGION`: `us-east-2` (or your region)
      - `MASTER_USERNAME`: OpenSearch admin username
      - `MASTER_PASSWORD`: OpenSearch admin password
    - Click **Save**
11. In the "General configuration" section:
    - Set memory to **128 MB**
    - Set timeout to **2 minutes**
    - Click **Save**

## Testing the Lambda Functions

### Test Snapshot Lambda

1. In the Lambda console, open the `dev-opensearch-snapshot-lambda` function
2. Click the **Test** tab
3. Create a new test event:
   - Enter event name: `TestSnapshotEvent`
   - Keep the default JSON payload (empty object `{}`)
   - Click **Save**
4. Click **Test**
5. Check the execution results and logs
6. Verify that a snapshot repository has been created in your OpenSearch domain

### Test IAM User Mapper Lambda

1. In the Lambda console, open the `dev-opensearch-iam-user-mapper` function
2. Click the **Test** tab
3. Create a new test event:
   - Enter event name: `TestUserMapperEvent`
   - Enter the following JSON:
     ```json
     {
       "userName": "test-opensearch-user",
       "createIfMissing": true,
       "createInternalUser": true,
       "opensearchRole": "all_access",
       "forceCredentialReset": false
     }
     ```
   - Click **Save**
4. Click **Test**
5. Check the execution results and logs
6. Verify that the IAM user has been created and mapped to the OpenSearch role

### Test Role Mapper Lambda

1. In the Lambda console, open the `dev-opensearch-role-mapper` function
2. Click the **Test** tab
3. Create a new test event:
   - Enter event name: `TestRoleMapperEvent`
   - Enter the following JSON:
     ```json
     {
       "roleName": "test-opensearch-role",
       "opensearchRole": "all_access"
     }
     ```
   - Click **Save**
4. Click **Test**
5. Check the execution results and logs
6. Verify that the IAM role has been mapped to the OpenSearch role

## Verifying the Setup

1. Check that the S3 bucket is created
2. Verify the IAM roles and policies
3. Ensure that all Lambda functions are configured correctly
4. Check that the CloudWatch Event rule is triggering the snapshot Lambda
5. Verify that snapshots are being created by:
   - Logging into your OpenSearch dashboard
   - Navigate to Snapshot Management
   - Check for successful snapshots 