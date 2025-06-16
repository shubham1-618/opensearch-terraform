# Testing Lambda Functions

This guide explains how to test the OpenSearch Lambda functions to ensure they're working properly.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Access to the AWS Management Console
- The Lambda functions have been deployed using Terraform

## Testing the IAM User Mapper Function

The IAM User Mapper function can create IAM users and map them to the OpenSearch dashboard automatically.

### Method 1: Using AWS CLI

1. **Create a test event JSON file**:

   Create a file named `test-iam-mapper.json` with the following content:
   ```json
   {
     "userName": "test-opensearch-user",
     "createIfMissing": true
   }
   ```

2. **Invoke the Lambda function**:

   ```bash
   aws lambda invoke \
     --function-name dev-opensearch-iam-user-mapper \
     --payload file://test-iam-mapper.json \
     response.json
   ```

3. **Check the response**:

   ```bash
   cat response.json
   ```

   You should see a response with a success message and, if a new user was created, credentials for the user.

### Method 2: Using AWS Console

1. **Open the AWS Lambda console**
2. **Navigate to the IAM mapper function** (should be named `dev-opensearch-iam-user-mapper`)
3. **Create a test event**:
   - Click the "Test" tab
   - Create a new test event
   - Paste this JSON:
     ```json
     {
       "userName": "test-opensearch-user",
       "createIfMissing": true
     }
     ```
   - Save the test event
4. **Click "Test"** to execute the function
5. **Review the results** in the execution results panel

### Verifying IAM User Creation

1. **Check that the IAM user exists**:
   ```bash
   aws iam get-user --user-name test-opensearch-user
   ```

2. **Check OpenSearch dashboard access**:
   - Open the OpenSearch dashboard URL
   - Sign in as the IAM user using the temporary password (you'll be asked to change it)
   - Verify you have access to the dashboard

## Testing the Snapshot Function

The Snapshot Lambda function creates hourly backups of your OpenSearch domain.

### Manual Testing

1. **Invoke the Lambda function**:

   ```bash
   aws lambda invoke \
     --function-name dev-opensearch-snapshot-lambda \
     --payload '{}' \
     snapshot-response.json
   ```

2. **Check the OpenSearch snapshots**:

   ```bash
   # First get the OpenSearch endpoint
   export OS_ENDPOINT=$(aws opensearchservice describe-domain \
     --domain-name dev-opensearch \
     --query 'DomainStatus.Endpoints.vpc' \
     --output text)

   # Check snapshots (requires curl and jq)
   curl -X GET "https://$OS_ENDPOINT/_snapshot/s3-snapshots/_all" \
     -u "master-user:YourPassword" | jq
   ```

### Verifying Scheduled Execution

1. **Check CloudWatch Logs**:
   - Open the AWS CloudWatch console
   - Navigate to Log Groups
   - Find the log group for the snapshot Lambda function
   - Check the most recent log streams to verify hourly execution

2. **Check CloudWatch Events**:
   - Open the CloudWatch console
   - Go to Events > Rules
   - Find the rule for the snapshot Lambda function
   - Verify it's enabled and has the correct schedule expression

3. **Verify S3 bucket contents**:
   - Open the S3 console
   - Navigate to the snapshot bucket
   - Verify that snapshot files are being created

## Troubleshooting

### IAM User Mapper Issues

1. **Function fails with "Access Denied"**:
   - Verify the Lambda execution role has the necessary IAM permissions
   - Check the VPC configuration allows the Lambda to reach both IAM and OpenSearch

2. **User created but not mapped to OpenSearch**:
   - Verify the OpenSearch domain's access policy allows the IAM user
   - Check if the OpenSearch security plugin is configured correctly

### Snapshot Issues

1. **Repository creation fails**:
   - Verify the S3 bucket exists and Lambda has access to it
   - Check that the OpenSearch domain has permissions to assume the snapshot role

2. **Scheduled snapshots not running**:
   - Check the CloudWatch rule is enabled
   - Verify the Lambda function timeout is sufficient (should be at least 5 minutes)
   - Review the CloudWatch logs for error messages

## Creating a User and Mapping in One Step

For production use, you can create a script or workflow that:

1. Creates a new IAM user
2. Invokes the Lambda function to map the user to OpenSearch
3. Provides the credentials to the user securely

Example script (bash):

```bash
#!/bin/bash

# Parameters
USER_NAME=$1
FUNCTION_NAME="dev-opensearch-iam-user-mapper"

if [ -z "$USER_NAME" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

# Invoke Lambda
echo "Creating and mapping user: $USER_NAME"
aws lambda invoke \
  --function-name $FUNCTION_NAME \
  --payload "{\"userName\":\"$USER_NAME\",\"createIfMissing\":true}" \
  response.json

# Display results
echo "Result:"
cat response.json | jq
```

Save this as `create-opensearch-user.sh`, make it executable, and use it to create users:

```bash
./create-opensearch-user.sh john.doe
``` 