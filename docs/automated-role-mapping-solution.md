# Automated Role Mapping Solution for OpenSearch

## Current Issues

1. **Lambda Execution Roles Need OpenSearch Permissions**:
   - `dev-opensearch-snapshot-lambda-execution-role` - Needs permissions for snapshot operations
   - `dev-opensearch-iam-user-mapper-execution-role` - Needs permissions to map users

2. **IAM Users Created by Lambda Are Only Backend Roles**:
   - Users created by the IAM mapper Lambda function are mapped as backend roles
   - They can't log in to the OpenSearch dashboard directly
   - They need to be mapped to internal users or given dashboard access

3. **Manual Mappings Are Lost After Terraform Apply**:
   - Any manual role mappings are lost when Terraform is applied
   - This requires repeating manual steps after each deployment

## Comprehensive Solution

### 1. Create a Post-Deployment Script

Create a script that automatically sets up all required role mappings after Terraform deployment:

```bash
#!/bin/bash
# File: setup-opensearch-permissions.sh

# Get OpenSearch endpoint from Terraform output
cd terraform/environments/dev
ENDPOINT=$(terraform output -raw opensearch_endpoint)
MASTER_USER=$(terraform output -raw master_user_name)
MASTER_PASSWORD=$(terraform output -raw master_user_password)
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
cd ../../

echo "Setting up OpenSearch permissions..."

# Create a temporary JSON file for the all_access role mapping
cat > all_access_mapping.json << EOF
{
  "backend_roles": [
    "arn:aws:iam::${ACCOUNT_ID}:role/dev-opensearch-snapshot-lambda-execution-role",
    "arn:aws:iam::${ACCOUNT_ID}:role/dev-opensearch-iam-user-mapper-execution-role"
  ],
  "hosts": [],
  "users": ["admin"]
}
EOF

# Apply the all_access role mapping
curl -X PUT "https://${ENDPOINT}/_plugins/_security/api/rolesmapping/all_access" \
  -H "Content-Type: application/json" \
  -u "${MASTER_USER}:${MASTER_PASSWORD}" \
  -d @all_access_mapping.json \
  --insecure

echo "Role mappings applied successfully!"

# Clean up
rm all_access_mapping.json
```

### 2. Integrate with Terraform Using null_resource

Add this to your `terraform/environments/dev/main.tf` file:

```hcl
# Get current account ID
data "aws_caller_identity" "current" {}

# Create role mappings after OpenSearch deployment
resource "null_resource" "opensearch_role_mappings" {
  depends_on = [module.opensearch, module.snapshot_lambda, module.iam_mapper_lambda]

  # Trigger this resource whenever the OpenSearch domain changes
  triggers = {
    opensearch_domain_id = module.opensearch.opensearch_domain_id
  }

  provisioner "local-exec" {
    command = <<EOF
      # Wait for OpenSearch domain to be fully available
      sleep 60

      # Create mapping JSON
      cat > all_access_mapping.json << EOL
      {
        "backend_roles": [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-opensearch-snapshot-lambda-execution-role",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-opensearch-iam-user-mapper-execution-role"
        ],
        "hosts": [],
        "users": ["admin"]
      }
      EOL

      # Apply the role mapping
      curl -X PUT "https://${module.opensearch.opensearch_endpoint}/_plugins/_security/api/rolesmapping/all_access" \
        -H "Content-Type: application/json" \
        -u "${var.master_user_name}:${var.master_user_password}" \
        -d @all_access_mapping.json \
        --insecure

      # Clean up
      rm all_access_mapping.json
    EOF
  }
}
```

### 3. Modify the IAM Mapper Lambda Function

To solve the issue with IAM users being only backend roles, modify the Lambda function to also create internal OpenSearch users:

```python
# Add to the lambda_handler function in lambda/iam_mapper/index.py

def lambda_handler(event, context):
    # ... existing code ...
    
    # After mapping the IAM user to the backend role, also create an internal user
    if user_arn and status == "created" and credentials:
        try:
            # Create internal user with same name
            internal_user_endpoint = f'https://{host}/_plugins/_security/api/internalusers/{user_name}'
            
            # Set up internal user with the same password
            internal_user_payload = {
                "password": credentials["password"],
                "backend_roles": [user_arn]
            }
            
            # Create the internal user
            internal_user_response = requests.put(
                internal_user_endpoint,
                auth=(master_username, master_password),
                json=internal_user_payload,
                headers={"Content-Type": "application/json"},
                verify=True
            )
            
            if internal_user_response.status_code >= 200 and internal_user_response.status_code < 300:
                print(f"Successfully created internal user {user_name}")
            else:
                print(f"Failed to create internal user: {internal_user_response.text}")
        
        except Exception as e:
            print(f"Error creating internal user: {str(e)}")
    
    # ... rest of the existing code ...
```

### 4. Create a Custom Terraform Module for OpenSearch Security

For a more comprehensive solution, create a dedicated module for OpenSearch security:

```hcl
# terraform/modules/opensearch_security/main.tf

variable "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  type        = string
}

variable "master_user_name" {
  description = "OpenSearch master user name"
  type        = string
}

variable "master_user_password" {
  description = "OpenSearch master user password"
  type        = string
  sensitive   = true
}

variable "role_mappings" {
  description = "Map of role names to users and backend roles"
  type = map(object({
    users = list(string)
    backend_roles = list(string)
    hosts = list(string)
  }))
  default = {}
}

resource "null_resource" "opensearch_role_mappings" {
  for_each = var.role_mappings
  
  provisioner "local-exec" {
    command = <<EOF
      # Create mapping JSON
      cat > ${each.key}_mapping.json << EOL
      {
        "backend_roles": ${jsonencode(each.value.backend_roles)},
        "hosts": ${jsonencode(each.value.hosts)},
        "users": ${jsonencode(each.value.users)}
      }
      EOL

      # Apply the role mapping
      curl -X PUT "https://${var.opensearch_endpoint}/_plugins/_security/api/rolesmapping/${each.key}" \
        -H "Content-Type: application/json" \
        -u "${var.master_user_name}:${var.master_user_password}" \
        -d @${each.key}_mapping.json \
        --insecure

      # Clean up
      rm ${each.key}_mapping.json
    EOF
  }
}
```

Then use this module in your environment:

```hcl
# terraform/environments/dev/main.tf

module "opensearch_security" {
  source = "../../modules/opensearch_security"
  
  opensearch_endpoint  = module.opensearch.opensearch_endpoint
  master_user_name     = var.master_user_name
  master_user_password = var.master_user_password
  
  role_mappings = {
    all_access = {
      users = ["admin"]
      backend_roles = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-opensearch-snapshot-lambda-execution-role",
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-opensearch-iam-user-mapper-execution-role"
      ]
      hosts = []
    },
    readall = {
      users = []
      backend_roles = []
      hosts = []
    }
    # Add more role mappings as needed
  }
  
  depends_on = [module.opensearch]
}
```

## Implementation Guide

1. **Choose Your Approach**:
   - For simple deployments: Use the post-deployment script
   - For Terraform integration: Use the null_resource approach
   - For advanced configuration: Create the custom module

2. **Implement the Solution**:
   - Add the chosen code to your repository
   - Make sure to update the account IDs and role names as needed

3. **Test the Solution**:
   - Run the script or apply the Terraform configuration
   - Verify the role mappings in the OpenSearch dashboard
   - Test the Lambda functions to ensure they have the correct permissions

4. **Verify User Access**:
   - Create a test IAM user using the Lambda function
   - Verify they can access OpenSearch with the appropriate permissions

## Handling Different Environments

For multiple environments (dev, staging, prod), you can:

1. Parameterize the script with environment variables
2. Create environment-specific Terraform configurations
3. Use Terraform workspaces to manage different environments

## Security Considerations

1. **Credential Management**:
   - Don't hardcode credentials in scripts or Terraform files
   - Use AWS Secrets Manager or environment variables
   - Mark sensitive variables with the `sensitive = true` attribute

2. **Access Control**:
   - Only map roles and users that need access
   - Follow the principle of least privilege
   - Regularly audit role mappings

3. **Network Security**:
   - Ensure scripts can reach the OpenSearch endpoint
   - For VPC-based domains, run scripts from within the VPC
   - Consider using a bastion host or VPN for secure access

## Troubleshooting

If you encounter issues:

1. **Connection Problems**:
   - Verify network connectivity to the OpenSearch endpoint
   - Check VPC and security group configurations

2. **Authentication Issues**:
   - Verify master credentials are correct
   - Check for special characters in passwords that might need escaping

3. **Permission Denied**:
   - Verify the master user has permissions to modify security settings
   - Check if the OpenSearch domain has fine-grained access control enabled 