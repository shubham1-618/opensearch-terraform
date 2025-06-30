# Automated IAM Role Mapping for OpenSearch

This document explains how to use the automated role mapping solution for AWS OpenSearch.

## Overview

The OpenSearch security plugin uses the concept of "backend roles" to map AWS IAM roles and users to OpenSearch roles. This mapping is required for AWS authentication methods like IAM and Cognito to work properly.

Our solution provides two Lambda functions to automatically handle this mapping:

1. **IAM User Mapper (opensearch-iam-user-mapper)**: Maps IAM users to OpenSearch roles
2. **IAM Role Mapper (opensearch-role-mapper)**: Maps IAM roles to OpenSearch roles

## Role Mapper Lambda Function

The Role Mapper Lambda function maps AWS IAM roles to OpenSearch security roles. This is particularly useful for ensuring Lambda functions or other AWS services can access OpenSearch with the right permissions.

### When to Use Role Mapper

Use the Role Mapper Lambda when:

1. You need to grant OpenSearch access to a service using an IAM role
2. You're experiencing authentication errors with the Snapshot Lambda or other services
3. You want to automatically map IAM roles to specific OpenSearch security roles

### How to Use Role Mapper

#### Option 1: AWS Console

1. Navigate to the AWS Lambda console
2. Find the "opensearch-role-mapper" Lambda function
3. Create a test event with the following JSON structure:

```json
{
  "roleName": "role-to-map",
  "roleArn": "arn:aws:iam::123456789012:role/role-name",
  "opensearchRole": "all_access"
}
```

4. Execute the test event to map the role

#### Option 2: Using the invoke-for-snapshot.py Script

We provide a Python script to automatically map the Snapshot Lambda's execution role:

1. Ensure you have the AWS CLI configured with appropriate permissions
2. Run the script:

```bash
python lambda/role_mapper/invoke-for-snapshot.py --region us-east-1 --environment dev
```

This script will:
- Find the Snapshot Lambda's execution role
- Map it to the "all_access", "manage_snapshots", and "cluster_admin" roles in OpenSearch
- Output the results of each mapping operation

## Debugging Common Issues

### Snapshot Lambda "security_exception" Error

If you see an error like:

```
"Error taking snapshot: Failed to create repository: {\"error\":{\"root_cause\":[{\"type\":\"security_exception\",\"reason\":\"no permissions for [cluster:admin/repository/put] and User [name=arn:aws:iam::123456789012:role/role-name, backend_roles=[...]}]"
```

This indicates that the Lambda execution role is not properly mapped to OpenSearch roles. To fix:

1. Run the role_mapper Lambda to map the role to all necessary OpenSearch roles
2. Ensure the role has the appropriate IAM permissions
3. Verify the mapping in the OpenSearch dashboard under Security > Roles > (select role) > Mapped users

### Verifying Role Mappings

To verify role mappings in OpenSearch:

1. Log in to the OpenSearch dashboard
2. Navigate to Security > Roles 
3. Select a role (e.g., all_access)
4. Check the "Mapped users" tab
5. Verify the IAM role ARN is listed under "Backend roles" 