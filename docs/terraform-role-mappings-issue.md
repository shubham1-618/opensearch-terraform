# Terraform and OpenSearch Role Mappings Issue

## Issue Description

When using Terraform to manage OpenSearch infrastructure, there's an important limitation to be aware of: **Terraform will overwrite manual security configuration changes** when you run `terraform apply`.

Specifically, any role mappings, users, or permissions that are manually configured through the OpenSearch dashboard will be reset to the state defined in your Terraform configuration whenever you apply changes.

This happens because:
1. Terraform manages infrastructure as code and enforces the state defined in your configuration files
2. Manual changes made outside of Terraform aren't tracked in the Terraform state
3. The OpenSearch domain configuration doesn't include fine-grained security settings like role mappings

## Impact

This issue affects:
- User mappings to roles (e.g., mapping `admin` to `all_access`)
- Backend role mappings (e.g., mapping Lambda execution roles)
- Custom roles and permissions
- Internal users created through the dashboard

## Solutions

### 1. Include Role Mappings in Terraform Configuration

Create a custom Terraform resource that runs after the OpenSearch domain is created:

```hcl
resource "null_resource" "opensearch_role_mappings" {
  depends_on = [module.opensearch]

  provisioner "local-exec" {
    command = <<EOF
      curl -X PUT "https://${module.opensearch.opensearch_endpoint}/_plugins/_security/api/rolesmapping/all_access" \
        -H "Content-Type: application/json" \
        -u "${var.master_user_name}:${var.master_user_password}" \
        -d '{"users": ["admin"], "backend_roles": ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-opensearch-snapshot-lambda-execution-role"]}'
    EOF
  }
}
```

**Pros:**
- Role mappings are managed as code
- Changes are applied consistently with each deployment
- Configuration is version-controlled

**Cons:**
- Requires storing master credentials in Terraform variables
- Might have connectivity issues if OpenSearch is in a VPC

### 2. Use a Post-Deployment Script

Create a separate script that runs after Terraform deployment:

```bash
#!/bin/bash

# Get OpenSearch endpoint from Terraform output
ENDPOINT=$(terraform output -raw opensearch_endpoint)

# Apply role mappings
curl -X PUT "https://$ENDPOINT/_plugins/_security/api/rolesmapping/all_access" \
  -H "Content-Type: application/json" \
  -u "$MASTER_USER:$MASTER_PASSWORD" \
  -d '{"users": ["admin"], "backend_roles": ["arn:aws:iam::318096621822:role/dev-opensearch-snapshot-lambda-execution-role"]}'
```

**Pros:**
- Keeps sensitive credentials out of Terraform code
- Can be run selectively when needed
- Can include more complex logic

**Cons:**
- Requires manual execution
- Not automatically tied to Terraform deployments

### 3. Modify the Terraform OpenSearch Module

Update your OpenSearch module to accept role mappings as variables:

```hcl
variable "role_mappings" {
  description = "Map of role names to users and backend roles"
  type = map(object({
    users = list(string)
    backend_roles = list(string)
  }))
  default = {}
}

# Then use null_resource to apply these mappings
```

**Pros:**
- Most flexible solution
- Fully integrated with Terraform
- Allows different mappings per environment

**Cons:**
- Requires more complex Terraform code
- Still needs to use API calls to configure OpenSearch

## Recommended Approach

For most use cases, option 1 (Include Role Mappings in Terraform Configuration) provides the best balance of simplicity and consistency. It ensures that your security settings are applied with every deployment and are version-controlled alongside your infrastructure code.

## Implementation Steps

1. Add the `null_resource` to your Terraform configuration
2. Include all required role mappings in the API call
3. Make sure to handle errors and retries for API calls
4. Document the role mappings that are automatically applied

## Important Notes

- Always store sensitive credentials securely, preferably using AWS Secrets Manager or similar
- Consider using Terraform's `sensitive` attribute for password variables
- Test the role mapping process thoroughly before deploying to production
- Include appropriate wait conditions if the OpenSearch domain needs time to become available 