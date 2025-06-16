# OpenSearch IAM Authentication Issue

## Issue Description

The current OpenSearch deployment is configured to use internal user database authentication rather than IAM authentication for dashboard login. This creates a discrepancy between how the Lambda functions are designed to work and how users can actually access the dashboard:

1. The IAM User Mapper Lambda function successfully creates IAM users and maps them to OpenSearch roles as backend roles
2. However, users cannot log in to the OpenSearch dashboard using IAM credentials because the dashboard doesn't show an AWS IAM authentication option

## Root Cause

The OpenSearch domain is configured with internal user database authentication in the Terraform configuration:

```terraform
advanced_security_options {
  enabled                        = true
  internal_user_database_enabled = true
  master_user_options {
    master_user_name     = var.master_user_name
    master_user_password = var.master_user_password
  }
}
```

This configuration:
- Enables fine-grained access control
- Uses an internal user database (not IAM)
- Sets up a master user with username/password authentication

For IAM authentication to be available in the dashboard login, the OpenSearch domain must be configured to use IAM for the master user instead of internal user database.

## Current Behavior

1. Lambda function creates IAM users and maps them to OpenSearch roles as backend roles
2. These IAM users can access OpenSearch APIs programmatically using AWS SDK or CLI with their IAM credentials
3. However, when trying to log in to the dashboard, only basic authentication is available (username/password)
4. There is no AWS IAM authentication option in the login screen

## Possible Solutions

### Option 1: Continue with Current Setup (No Dashboard Changes)

- Create internal users in the OpenSearch dashboard for UI access
- Use IAM users for programmatic access only
- Keep the Lambda function for automating IAM user mapping for API access

### Option 2: Reconfigure OpenSearch for IAM Authentication (Requires Downtime)

Modify the Terraform configuration to use IAM authentication:

```terraform
advanced_security_options {
  enabled                        = true
  internal_user_database_enabled = false  # Disable internal user database
  master_user_options {
    master_user_arn = "arn:aws:iam::ACCOUNT_ID:user/admin-user"  # Use IAM user ARN
  }
}
```

This change would:
- Require redeploying the OpenSearch domain (causing downtime)
- Enable IAM authentication in the dashboard login
- Allow users to log in with their IAM credentials

### Option 3: Hybrid Approach

1. Keep the current OpenSearch configuration with internal user database
2. Modify the Lambda function to:
   - Create IAM users for programmatic access
   - Also create corresponding internal users with the same username/password
   - Map both to appropriate roles

## Recommended Approach

For production environments, Option 2 (reconfiguring for IAM authentication) is generally the most secure and maintainable approach. However, it requires downtime to implement.

For the current development environment, Option 1 (continuing with the current setup) is the simplest approach:

1. Create internal users in the OpenSearch dashboard for UI access
2. Use the Lambda function to map IAM users for programmatic access
3. Document this limitation for users

## How to Create Internal Users for Dashboard Access

1. Log in to the OpenSearch dashboard using the master credentials
2. Navigate to Security → Internal Users
3. Click "Create user"
4. Set username and password
5. Go to Security → Roles
6. Select the appropriate role (e.g., "all_access")
7. Map the internal user to this role

## Testing IAM User Access to APIs

While IAM users cannot log in to the dashboard, they can still access OpenSearch APIs programmatically:

```python
import boto3
from requests_aws4auth import AWS4Auth
import requests

# Set up AWS credentials for the IAM user
session = boto3.Session(
    aws_access_key_id='IAM_USER_ACCESS_KEY',
    aws_secret_access_key='IAM_USER_SECRET_KEY'
)

# Create AWS4Auth for the IAM user
credentials = session.get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    'REGION',
    'es',
    session_token=credentials.token
)

# Make an authenticated request to OpenSearch
response = requests.get(
    'https://OPENSEARCH_ENDPOINT/_cluster/health',
    auth=awsauth
)

print(response.text)
```

This script should work if the IAM user has been properly mapped to a role with sufficient permissions. 