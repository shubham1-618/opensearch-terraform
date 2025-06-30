# IAM User Mapper for OpenSearch

This document describes the IAM User Mapper Lambda function, which automates the creation and mapping of IAM users to OpenSearch roles.

## Overview

The IAM User Mapper Lambda function provides a streamlined way to create and manage users for OpenSearch access. It:

1. Creates AWS IAM users (if requested)
2. Creates matching internal OpenSearch users (if requested)
3. Maps users to specified OpenSearch security roles
4. Preserves all existing mappings to maintain system stability

## Key Features

### 1. IAM User Creation

- Creates IAM users with console access (password) and programmatic access (access keys)
- Sets password reset on first login for security
- Tags users for easier management
- Returns generated credentials securely

### 2. Internal OpenSearch User Creation

- Creates matching users in OpenSearch's internal user database
- Uses the same password as the IAM user for consistency
- Maps internal users to appropriate roles
- Enables dashboard login without IAM credentials

### 3. Role Mapping

- Maps users to any OpenSearch security role (all_access, dashboard_user, etc.)
- Configurable through the opensearchRole parameter
- Maintains proper separation of duties through role assignment

### 4. Preservation of Existing Mappings

- Retrieves current role mappings before making changes
- Preserves all existing users in each role mapping
- Always ensures admin user remains in the all_access role
- Maintains existing backend roles when adding new ones
- Prevents accidental lockouts and permission loss during updates

## Usage

Invoke the Lambda function with a JSON payload:

```json
{
  "userName": "analyst-user",
  "createIfMissing": true,
  "createInternalUser": true,
  "opensearchRole": "dashboard_user"
}
```

### Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `userName` | Name of the IAM user to map | - | Yes |
| `createIfMissing` | Create the IAM user if it doesn't exist | `true` | No |
| `createInternalUser` | Create matching internal user in OpenSearch | `true` | No |
| `opensearchRole` | OpenSearch role to map the user to | `all_access` | No |

### Response

```json
{
  "statusCode": 200,
  "body": {
    "message": "Successfully mapped user analyst-user to dashboard_user role",
    "userStatus": "created",
    "credentials": {
      "username": "analyst-user",
      "password": "generated-password",
      "access_key_id": "AKIAXXXXXXXXXXXXXXXX",
      "secret_access_key": "secret-key-value"
    },
    "mapping": {
      "users": ["admin", "analyst-user"],
      "backend_roles": ["arn:aws:iam::123456789012:user/analyst-user"]
    }
  }
}
```

## How Mapping Preservation Works

The Lambda function follows these steps to preserve existing mappings:

1. **Retrieval**: Gets current role mappings from OpenSearch security API
2. **Copying**: Makes a complete copy of the existing mapping configuration
3. **Verification**: Checks if user is already mapped to avoid duplicates
4. **Augmentation**: Adds the new user to backend_roles array without removing existing entries
5. **Admin Protection**: Ensures admin user always remains in the all_access role's users array
6. **Full Preservation**: Maintains all other fields like hosts, users, etc.
7. **Update**: Applies the updated mapping with all original entries preserved

This ensures no existing permissions are lost when adding new users.

## Common Use Cases

### 1. Creating New Analysts with Dashboard Access

```json
{
  "userName": "data-analyst",
  "opensearchRole": "kibana_user"
}
```

### 2. Adding an Admin User

```json
{
  "userName": "admin-user",
  "opensearchRole": "all_access"
}
```

### 3. Adding User to Custom Role

```json
{
  "userName": "read-only-user",
  "opensearchRole": "readonly_access"
}
```

## Troubleshooting

### Status Codes

- **200**: Success - User was created/mapped successfully
- **400**: Invalid request - Missing required parameters
- **404**: User not found - When createIfMissing is false
- **500**: Internal error - Check CloudWatch logs for details

### Common Issues

1. **"MASTER_PASSWORD environment variable not set"**
   - Ensure the Lambda has the MASTER_PASSWORD environment variable

2. **"Error getting role mappings"**
   - Check OpenSearch connectivity and security group settings
   - Verify OpenSearch domain status

3. **"Error creating internal user"**
   - Check if OpenSearch fine-grained access control is enabled
   - Verify master user has sufficient permissions

## Integration with CI/CD

This Lambda can be integrated into CI/CD pipelines to automate user provisioning:

```yaml
# Example GitLab CI job
create_user:
  stage: deploy
  script:
    - aws lambda invoke --function-name dev-opensearch-iam-user-mapper --payload '{"userName":"ci-user"}' response.json
    - cat response.json
```

## Security Considerations

1. **Password Handling**: Generated passwords are returned once and should be securely transmitted to users
2. **Role Assignment**: Follow the principle of least privilege when assigning roles
3. **Audit Trail**: All user creation actions are logged in CloudTrail
4. **Credentials**: Access keys and passwords should be rotated regularly 