# Lambda Function Permissions for OpenSearch

## Issue: Lambda Functions Cannot Create Repositories or Snapshots

The Lambda function execution role (`dev-opensearch-snapshot-lambda-execution-role`) lacks the necessary permissions in OpenSearch to create repositories and snapshots, even though it has the correct IAM permissions.

This happens because:

1. OpenSearch uses a fine-grained access control system separate from IAM
2. IAM roles need to be explicitly mapped to OpenSearch roles
3. Terraform doesn't manage these mappings automatically

## Required Permissions

For the snapshot Lambda function to work properly, it needs:

1. **IAM Permissions**:
   - `iam:PassRole` - To pass the snapshot role to OpenSearch
   - `s3:*` - To access the S3 bucket for snapshots
   - `es:*` - To make API calls to OpenSearch

2. **OpenSearch Permissions**:
   - `cluster:admin/repository/*` - To create and manage repositories
   - `cluster:admin/snapshot/*` - To create and manage snapshots

## Solution: Map Lambda Execution Role to all_access Role

### Manual Steps (Required After Each Deployment)

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

### Using the Dev Tools Console

You can also map the role using the Dev Tools console:

```
PUT _plugins/_security/api/rolesmapping/all_access
{
  "backend_roles": [
    "arn:aws:iam::318096621822:role/dev-opensearch-snapshot-lambda-execution-role"
  ]
}
```

Note: If you already have other backend roles mapped, include them in the array to avoid overwriting.

## Automating the Process

To avoid manual steps, you can automate this process by adding a `null_resource` to your Terraform configuration:

```hcl
resource "null_resource" "opensearch_role_mappings" {
  depends_on = [module.opensearch, module.snapshot_lambda]

  provisioner "local-exec" {
    command = <<EOF
      curl -X PUT "https://${module.opensearch.opensearch_endpoint}/_plugins/_security/api/rolesmapping/all_access" \
        -H "Content-Type: application/json" \
        -u "${var.master_user_name}:${var.master_user_password}" \
        -d '{
          "backend_roles": ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/dev-opensearch-snapshot-lambda-execution-role"]
        }'
    EOF
  }
}
```

Add this to your `terraform/environments/dev/main.tf` file after the Lambda module definitions.

## Testing the Configuration

After mapping the role, test the Lambda function:

```bash
aws lambda invoke --function-name dev-opensearch-snapshot-lambda --payload '{}' snapshot-response.json --region us-east-2
```

Then check the response:

```bash
cat snapshot-response.json
```

If successful, you should see a 200 status code and a message indicating the snapshot was initiated successfully.

## Verifying Snapshots in S3

After the Lambda function runs successfully, check your S3 bucket for snapshots:

```bash
aws s3 ls s3://dev-opensearch-snapshots-e1431cba --recursive
```

You should see files related to the snapshots in the bucket.

## Important Notes

1. This role mapping will be lost if you manually rebuild the OpenSearch domain
2. The Lambda function must be in the same VPC as the OpenSearch domain to connect to it
3. The security group for the Lambda function must allow outbound connections to the OpenSearch domain
4. The OpenSearch domain's access policy must allow the Lambda execution role to access it 