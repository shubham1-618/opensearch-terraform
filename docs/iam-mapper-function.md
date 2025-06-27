# IAM User Mapper Lambda Function

## Overview

The IAM User Mapper Lambda function automates the process of granting AWS IAM users access to your OpenSearch domain by mapping IAM user ARNs to OpenSearch security roles. This integration is critical for maintaining secure access control without manual intervention.

## How It Works

### Request Flow

1. **Function Trigger**:
   - The function receives an event with a `userName` parameter
   - This can be triggered manually, through API Gateway, or other AWS services

2. **IAM User Lookup**:
   - The function uses the AWS SDK's IAM client to retrieve the full ARN for the specified user
   - If the user doesn't exist, the function returns a 404 error

3. **OpenSearch Role Mapping Retrieval**:
   - Connects to OpenSearch's security plugin API endpoint: `/_plugins/_security/api/rolesmapping/all_access`
   - Retrieves current role mappings using AWS Signature V4 authentication
   - Parses the JSON response to extract existing backend roles

4. **Role Mapping Update**:
   - If the user's ARN is already mapped to the role, the function returns success without changes
   - If not already mapped, the function adds the user's ARN to the list of backend roles
   - Updates the role mapping in OpenSearch via a PUT request

5. **Response**:
   - Returns a JSON response with status code and a message indicating success or failure

### Authentication

The function uses AWS4Auth to sign requests to OpenSearch using the Lambda function's execution role credentials. This ensures secure communication between the Lambda function and your OpenSearch domain.

## Implementation Details

### Function Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENSEARCH_ENDPOINT` | The endpoint URL of your OpenSearch domain (without https://) |
| `REGION` | AWS region where the OpenSearch domain is deployed |

### IAM Permissions Required

The Lambda execution role needs:
- `iam:GetUser` - To retrieve user ARN information
- `es:ESHttpGet`, `es:ESHttpPut` - To interact with OpenSearch APIs

### Code Structure

- **Imports**: boto3, requests, and requests_aws4auth libraries
- **Credentials Setup**: Creates AWS4Auth object for OpenSearch authentication
- **Handler Function**: Main entry point that processes the event
- **Error Handling**: Comprehensive try/except blocks with meaningful error messages

### Example Event

```json
{
  "userName": "opensearch-admin"
}
```

### Example Response (Success)

```json
{
  "statusCode": 200,
  "body": "Successfully mapped user opensearch-admin to all_access role"
}
```

## Deployment

This Lambda function is deployed using Terraform with the following components:

1. **Lambda Function Resource**: Defines the function, its runtime, memory, and timeout
2. **IAM Role**: Provides necessary permissions
3. **Environment Variables**: Sets required configuration

## Troubleshooting

### Common Issues

1. **403 Forbidden Errors**:
   - Verify Lambda execution role has necessary permissions
   - Check OpenSearch domain access policy allows the Lambda function's role

2. **Role Mapping Failures**:
   - Ensure OpenSearch security plugin is properly configured
   - Verify endpoint URL is correct and accessible from Lambda's network

3. **IAM User Not Found**:
   - Confirm the user exists in the AWS account
   - Check for typos in the userName parameter

### Logging

The function logs its operations to CloudWatch Logs, which can be monitored for errors and execution tracking. 