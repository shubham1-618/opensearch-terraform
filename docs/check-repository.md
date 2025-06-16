# Checking OpenSearch Repository Configuration

To check the configuration of the "cs-automated-enc" repository, run the following command in the OpenSearch Dev Tools console:

```
GET _snapshot/cs-automated-enc
```

This will show the S3 bucket name and settings being used by the repository. The output should look something like:

```json
{
  "cs-automated-enc": {
    "type": "s3",
    "settings": {
      "bucket": "bucket-name",
      "region": "us-east-2",
      "role_arn": "arn:aws:iam::account-id:role/role-name",
      "base_path": "optional/path/prefix"
    }
  }
}
```

Compare these settings with the S3 bucket you're checking:
- Make sure the bucket name matches "dev-opensearch-snapshots-e1431cba"
- Check if there's a base_path that might be directing snapshots to a subfolder

## Possible Issues and Solutions

### 1. Wrong Bucket Configuration

If the repository is configured to use a different bucket than "dev-opensearch-snapshots-e1431cba", you'll need to:
- Create a new repository pointing to the correct bucket, or
- Reconfigure the existing repository to use the correct bucket

### 2. Permission Issues

If the bucket name is correct but snapshots aren't being stored, check:
- The IAM role has proper permissions to write to the S3 bucket
- The OpenSearch domain has permission to assume the role

### 3. Checking CloudWatch Logs

Check the CloudWatch logs for the snapshot Lambda function to see if there are any errors:

1. Go to AWS CloudWatch console
2. Navigate to Log Groups
3. Find the log group for the snapshot Lambda function
4. Look for any error messages related to S3 access or permissions

### 4. Manual Repository Creation

If needed, you can create a new repository with the correct settings:

```
PUT _snapshot/new-s3-repository
{
  "type": "s3",
  "settings": {
    "bucket": "dev-opensearch-snapshots-e1431cba",
    "region": "us-east-2",
    "role_arn": "arn:aws:iam::318096621822:role/dev-opensearch-snapshot-role"
  }
}
```

Replace the role_arn with the correct role ARN from your environment. 