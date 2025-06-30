# IAM Role Mapper for OpenSearch

This document describes the IAM Role Mapper Lambda function, which automates the mapping of AWS IAM roles to OpenSearch security roles.

## Overview

The IAM Role Mapper Lambda function enables smooth integration between AWS IAM roles and OpenSearch security roles. It:

1. Maps AWS IAM roles to OpenSearch security roles
2. Preserves all existing mappings to maintain access control integrity
3. Ensures service roles (like Lambda functions) can access OpenSearch securely
4. Prevents permission loss during role mapping operations

## Key Features

### 1. IAM Role Mapping

- Maps IAM roles by name or ARN to OpenSearch security roles
- Supports mapping to any predefined security role
- Configurable through simple API parameters
- Enables service-to-service authentication

### 2. Preservation of Existing Mappings

- Retrieves current role mappings before making changes
- Preserves all existing users in the role mapping
- Always ensures `admin` user remains in the `all_access` role
- Maintains existing backend roles (other role ARNs) when adding new ones
- Prevents accidental lockouts and permission loss during updates

### 3. Flexible Configuration

- Accepts role name or full ARN
- Can determine AWS account ID automatically if not provided
- Works with custom roles and custom IAM role names

## Usage

Invoke the Lambda function with a JSON payload:

```json
{
  "roleName": "dev-opensearch-snapshot-lambda-execution-role",
  "opensearchRole": "all_access",
  "accountId": "123456789012"  // Optional
}
```

### Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `roleName` | Name of the IAM role to map | - | Yes (if roleArn not provided) |
| `roleArn` | Full ARN of the IAM role to map | - | Yes (if roleName not provided) |
| `opensearchRole` | OpenSearch role to map to | `all_access` | No |
| `accountId` | AWS account ID for role ARN construction | Current account | No |

### Response

```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully mapped role dev-opensearch-snapshot-lambda-execution-role to all_access role",
    "mapping": {
      "users": ["admin"],
      "backend_roles": [
        "arn:aws:iam::123456789012:role/dev-opensearch-snapshot-lambda-execution-role"
      ]
    }
  }
}
```

## How Mapping Preservation Works

The Lambda function follows these steps to preserve existing mappings:

1. **Retrieval**: Gets current role mappings from the OpenSearch security API
2. **Copying**: Makes a complete copy of ALL existing mapping fields
3. **Verification**: Checks if role is already mapped to avoid duplicates
4. **Augmentation**: Adds the new role to backend_roles array without removing existing entries
5. **Admin Protection**: Ensures admin user always remains in the all_access role's users array
6. **Full Preservation**: Maintains all other fields like hosts, users, etc.
7. **Update**: Applies the updated mapping with all original entries preserved

## Common Use Cases

### 1. Fixing the Snapshot Lambda Permissions

```json
{
  "roleName": "dev-opensearch-snapshot-lambda-execution-role",
  "opensearchRole": "all_access"
}
```

### 2. Granting Dashboard Access to EC2 Instances

```json
{
  "roleName": "analytics-ec2-role",
  "opensearchRole": "kibana_user"
}
```

### 3. Mapping Multiple Roles

Invoke the function multiple times to map a role to multiple OpenSearch roles:

```json
// First call
{
  "roleName": "data-pipeline-role",
  "opensearchRole": "index_manager"
}

// Second call
{
  "roleName": "data-pipeline-role",
  "opensearchRole": "cluster_monitor"
}
```

## Helper Script: invoke-for-snapshot.py

A helper Python script is included for automating the mapping of snapshot Lambda roles:

```bash
python lambda/role_mapper/invoke-for-snapshot.py --region us-east-1 --environment dev
```

The script:
- Automatically discovers the snapshot Lambda's execution role ARN
- Maps the role to multiple required OpenSearch roles:
  - `all_access` - For general OpenSearch access
  - `manage_snapshots` - For snapshot creation/management
  - `cluster_admin` - For cluster-level operations

## Troubleshooting

### Status Codes

- **200**: Success - Role was mapped successfully
- **400**: Invalid request - Missing required parameters
- **404**: Role not found or mapping not found
- **500**: Internal error - Check CloudWatch logs for details

### Common Issues

1. **"MASTER_PASSWORD environment variable not set"**
   - Ensure the Lambda has the MASTER_PASSWORD environment variable

2. **"Error getting role mappings"**
   - Check OpenSearch connectivity and security group settings
   - Verify OpenSearch domain status

3. **"Permission denied" errors in target Lambda**
   - Verify the role was properly mapped
   - Check that the IAM role has appropriate IAM policies
   - Ensure role ARN format is correct

## Integration with CI/CD

This Lambda can be integrated into CI/CD pipelines to automate role mapping:

```yaml
# Example GitLab CI job
map_roles:
  stage: deploy
  script:
    - aws lambda invoke --function-name dev-opensearch-role-mapper --payload '{"roleName":"ci-pipeline-role","opensearchRole":"read_only"}' response.json
    - cat response.json
```

## Security Considerations

1. **Role Mapping**: Only map roles to the minimum required OpenSearch roles
2. **Role Assignment**: Follow the principle of least privilege when assigning roles
3. **Audit Trail**: All role mapping actions are logged in CloudTrail
4. **Regular Reviews**: Periodically review role mappings to ensure proper access control 