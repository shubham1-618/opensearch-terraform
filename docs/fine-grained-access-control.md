# Fine-Grained Access Control in AWS OpenSearch

This document provides an overview of fine-grained access control in AWS OpenSearch as implemented in this project.

## Overview

Fine-grained access control (FGAC) in AWS OpenSearch enables administrators to control access to cluster operations, indices, documents, and fields at a granular level. This implementation uses a combination of AWS IAM authentication and the OpenSearch security plugin's role-based access control.

## Key Components

### 1. Authentication Methods

Our OpenSearch deployment supports multiple authentication methods:

- **Internal User Database**: Master username/password defined during domain creation
- **IAM Authentication**: AWS Identity and Access Management integration
- **SAML/LDAP**: (Optional) Can be configured for enterprise integration

### 2. Authorization Mechanisms

Authorization is managed through:

- **Role-Based Access Control**: Users and backend roles are mapped to OpenSearch security roles
- **Index-Level Security**: Control access at the index level
- **Document-Level Security**: Filter documents users can see based on document fields
- **Field-Level Security**: Restrict access to specific fields within documents

### 3. Security Roles

OpenSearch comes with several pre-configured security roles:

| Role | Description |
|------|-------------|
| `all_access` | Full admin access to the cluster |
| `security_manager` | Can manage users, roles, mappings |
| `kibana_user` | Basic access to Kibana/OpenSearch Dashboards |
| `snapshot_manager` | Can manage snapshots and restore operations |
| `cluster_admin` | Admin of cluster operations |

## Implementation Details

### Current Configuration

Our Terraform configuration includes:

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

Additionally, we implement:

- Node-to-node encryption
- Encryption at rest
- TLS for all connections
- VPC deployment for network isolation

### Automated Role Mapping

We've implemented automated role mapping using Lambda functions:

1. **IAM User Mapper**: Maps IAM users to OpenSearch roles
   - Creates IAM users if requested
   - Maps users to the appropriate OpenSearch role
   - Preserves existing mappings

2. **IAM Role Mapper**: Maps IAM roles to OpenSearch roles
   - Maps service roles (like Lambda execution roles)
   - Preserves existing mappings including admin users

## User Management

### Adding Users

Users can be added via:

1. **Internal user database**: Using the OpenSearch Dashboard
2. **IAM users**: Using the IAM User Mapper Lambda
   ```json
   {
     "userName": "new-analyst",
     "createIfMissing": true
   }
   ```

### Mapping IAM Roles

To map IAM roles:

```json
{
  "roleName": "role-to-map", 
  "opensearchRole": "security_manager"
}
```

## Best Practices

1. **Least Privilege**: Grant only necessary permissions
2. **Role Separation**: Create distinct roles for different functions (admins, analysts, readers)
3. **Regular Audits**: Review role mappings periodically
4. **Password Policies**: Enforce strong passwords for internal users
5. **Key Rotation**: Rotate access keys for IAM users regularly

## Security Configuration API

OpenSearch security plugin provides REST APIs for managing security:

- **Role mappings**: `/_plugins/_security/api/rolesmapping/{role}`
- **Users**: `/_plugins/_security/api/internalusers/{user}`
- **Roles**: `/_plugins/_security/api/roles/{role}`
- **Action groups**: `/_plugins/_security/api/actiongroups/{group}`

## Troubleshooting

### Common Issues

1. **Access Denied Errors**: 
   - Verify user/role is correctly mapped
   - Check permissions in IAM
   - Confirm OpenSearch role has appropriate permissions

2. **Missing Index Permissions**:
   ```json
   {
     "message": "no permissions for [indices:admin/get] and User [name=user1]"
   }
   ```
   - Solution: Ensure role has access to the required index pattern

3. **Role Mapping Lost After Updates**:
   - Use the role_mapper Lambda after infrastructure changes
   - Consider implementing post-deployment hooks in CI/CD

## Monitoring Security

Monitor security events through:

1. CloudWatch Logs for OpenSearch audit logs
2. CloudTrail for API calls
3. VPC Flow Logs for network traffic

## Resources

- [OpenSearch Security Plugin Documentation](https://opensearch.org/docs/latest/security-plugin/index/)
- [AWS OpenSearch FGAC Documentation](https://docs.aws.amazon.com/opensearch-service/latest/developerguide/fgac.html) 