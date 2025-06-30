# Preserving OpenSearch Role Mappings

This document explains how our Lambda functions preserve existing role mappings in OpenSearch, preventing permission loss and access issues.

## The Problem

OpenSearch role mappings can be easily overwritten when making updates through the API. This can lead to:

- Accidental removal of admin user from `all_access` role
- Loss of backend role assignments when adding new roles
- Security exceptions and permission denied errors
- Complete lockout from OpenSearch requiring manual recovery

## Our Solution

Both our IAM User Mapper and IAM Role Mapper Lambda functions implement a secure approach that:

1. Always retrieves current mappings before making changes
2. Preserves all existing mappings while adding new ones
3. Ensures critical users (like admin) are never removed
4. Returns the full mapping in the response for verification

## How Preservation Works

### The Preservation Algorithm

```
1. GET current mappings from /_plugins/_security/api/rolesmapping/{role}
2. Save complete mapping configuration (users, backend_roles, hosts, etc.)
3. IF role/user already exists in mapping
   THEN return success (no changes needed)
4. ELSE
   Add new role/user to appropriate array (backend_roles or users)
   Ensure admin remains in users array for all_access role
   PUT updated mapping with ALL original entries preserved
5. Return full mapping in response
```

### Code Implementation

The core preservation logic in our Lambda functions:

```python
# Get current mappings
get_response = requests.get(role_mapping_endpoint, auth=auth, verify=True)
current_mappings = get_response.json()

# Initialize update_payload with all existing mappings to preserve them
update_payload = {}
if opensearch_role in current_mappings:
    # Copy all existing mapping fields (users, hosts, etc.)
    update_payload = current_mappings[opensearch_role]
    
    # Check if user/role is already mapped
    backend_roles = update_payload.get('backend_roles', [])
    if role_arn in backend_roles:
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f'Role {role_name} is already mapped to {opensearch_role} role'
            })
        }
    
    # Add role to existing backend roles
    backend_roles.append(role_arn)
    update_payload['backend_roles'] = backend_roles
else:
    # Create new mapping with the user/role
    update_payload = {
        "backend_roles": [role_arn]
    }

# Make sure 'users' field exists to preserve admin user
if 'users' not in update_payload:
    update_payload['users'] = []

# Always ensure 'admin' is in the users list for all_access role
if opensearch_role == 'all_access' and 'admin' not in update_payload['users']:
    update_payload['users'].append('admin')

# Update role mapping with preserved values
put_response = requests.put(
    role_mapping_endpoint,
    auth=auth,
    json=update_payload,
    headers=headers,
    verify=True
)
```

## Why Preservation Matters

### Admin User Loss

Without proper preservation, it's easy to lose the admin user mapping:

```json
// Before: Current mapping
{
  "all_access": {
    "users": ["admin"],
    "backend_roles": []
  }
}

// Naive update (overwrites users array)
{
  "backend_roles": ["arn:aws:iam::123456789012:role/my-role"]
}

// After: Admin user lost!
{
  "all_access": {
    "backend_roles": ["arn:aws:iam::123456789012:role/my-role"]
  }
}
```

### With our solution:

```json
// Before: Current mapping
{
  "all_access": {
    "users": ["admin"],
    "backend_roles": []
  }
}

// Our update (preserves users array)
{
  "users": ["admin"],
  "backend_roles": ["arn:aws:iam::123456789012:role/my-role"]
}

// After: Admin user preserved!
{
  "all_access": {
    "users": ["admin"],
    "backend_roles": ["arn:aws:iam::123456789012:role/my-role"]
  }
}
```

## Common Mapping Issues and Solutions

### 1. Security Exceptions

```
"Error taking snapshot: Failed to create repository: {\"error\":
{\"root_cause\":[{\"type\":\"security_exception\",\"reason\":\"no permissions for 
[cluster:admin/repository/put] and User [name=arn:aws:iam::account:role/role-name, 
backend_roles=[...]}]"
```

**Solution**: Use the role_mapper Lambda to map the execution role to all_access:

```json
{
  "roleName": "lambda-execution-role",
  "opensearchRole": "all_access"
}
```

### 2. Admin User Locked Out

**Solution**: Re-run the role_mapper Lambda - it will ensure admin is added back to the all_access role:

```json
{
  "roleName": "any-role",
  "opensearchRole": "all_access"
}
```

### 3. Multiple Roles Lost During Update

**Solution**: Both mappers automatically preserve all existing roles when adding new ones.

## Best Practices

1. **Always use our mapper Lambdas** instead of directly calling the OpenSearch API
2. **Run mappers after infrastructure changes** to ensure role mappings are intact
3. **Verify mappings** in responses to ensure they contain expected values
4. **Use the invoke-for-snapshot.py helper** for reliable snapshot Lambda permissions
5. **Create CI/CD hooks** to automatically map roles after deployments

## Testing Role Preservation

To verify that mappings are preserved:

1. Add multiple users and roles to a role mapping
2. Use a Lambda function to add another user/role
3. Check the response mapping to confirm all original entries still exist
4. Verify in OpenSearch dashboard that permissions work correctly 