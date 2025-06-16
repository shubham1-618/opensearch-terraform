# Fixing OpenSearch Snapshot Lambda Permissions

## Current Issue

The snapshot Lambda function is encountering a permissions error:

```
"no permissions for [cluster:admin/repository/put] and User [name=arn:aws:iam::318096621822:role/dev-opensearch-snapshot-lambda-execution-role]"
```

This means the Lambda execution role doesn't have permission to create a repository in OpenSearch.

## Solution: Map Lambda Execution Role to all_access Role

1. **Log in to OpenSearch Dashboard**:
   - Use the SSH tunnel command: 
     ```
     ssh -i opensearch-jump-server-key.pem -L 9200:vpc-dev-opensearch-h7u3ctssekdzed4rfg5j5vvmgi.us-east-2.es.amazonaws.com:443 ec2-user@18.223.37.158
     ```
   - Access the dashboard at: `https://localhost:9200/_dashboards/`
   - Log in with the master credentials (admin/your-password)

2. **Navigate to Security Settings**:
   - Click on "Security" in the left sidebar
   - Click on "Roles"
   - Find and click on the "all_access" role

3. **Map the Lambda Execution Role**:
   - Click on the "Mapped users" tab
   - Click "Edit" or "Map users"
   - In the "Backend roles" section, add:
     ```
     arn:aws:iam::318096621822:role/dev-opensearch-snapshot-lambda-execution-role
     ```
   - Click "Map" or "Save"

4. **Test the Lambda Function Again**:
   ```
   aws lambda invoke --function-name dev-opensearch-snapshot-lambda --payload '{}' snapshot-response.json --region us-east-2
   ```

## Alternative: Using the Dev Tools Console

If you prefer, you can also map the role using the Dev Tools console:

```
PUT _plugins/_security/api/rolesmapping/all_access
{
  "backend_roles": [
    "arn:aws:iam::318096621822:role/dev-opensearch-snapshot-lambda-execution-role"
  ]
}
```

Note: This will replace any existing backend role mappings. If you already have other backend roles mapped, you should include them in the array.

## Verifying the Fix

After mapping the role:

1. Invoke the Lambda function again
2. Check if a new repository named "s3-snapshots" appears in the Snapshot Management section
3. Verify that snapshots are being created in the S3 bucket

## Permanent Solution via Terraform

For a more permanent solution, you can add this role mapping to your Terraform configuration by creating a custom resource that calls the OpenSearch API after the domain is created. 