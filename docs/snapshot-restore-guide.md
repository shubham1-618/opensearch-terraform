# Restoring Indexes from OpenSearch Snapshots

This guide explains how to restore indexes from snapshots in AWS OpenSearch.

## Understanding OpenSearch Snapshots

Snapshots in OpenSearch are backups of indexes and cluster state. Our system automatically creates snapshots using the snapshot Lambda function. These snapshots are stored in an S3 bucket configured in the Terraform setup.

## Prerequisites for Restoring Indexes

Before restoring an index from a snapshot:

1. The snapshot repository must be properly configured (handled by our snapshot Lambda)
2. You need appropriate permissions to access the snapshot repository
3. If restoring to a different cluster, the destination cluster must have:
   - Same or newer version of OpenSearch
   - Access to the same S3 bucket containing the snapshots

## Listing Available Snapshots

Before you can restore an index, you need to identify which snapshot to use.

### Using the OpenSearch API

```bash
# Get a list of repositories
curl -X GET "https://<opensearch-endpoint>/_snapshot?pretty" \
  -u '<username>:<password>'

# List snapshots in a repository
curl -X GET "https://<opensearch-endpoint>/_snapshot/s3-snapshots/_all?pretty" \
  -u '<username>:<password>'
```

### Using the OpenSearch Dashboard

1. Log in to the OpenSearch Dashboard
2. Navigate to Management > Snapshot Management
3. Select the "s3-snapshots" repository
4. View the list of available snapshots

## Restoring an Index from a Snapshot

You can restore specific indexes or all indexes from a snapshot.

### Using the OpenSearch API

```bash
# Restore specific indexes from a snapshot
curl -X POST "https://<opensearch-endpoint>/_snapshot/s3-snapshots/snapshot-2023-06-15-14-30-00/_restore" \
  -H "Content-Type: application/json" \
  -u '<username>:<password>' \
  -d '{
    "indices": "index-name",
    "rename_pattern": "index-(.+)",
    "rename_replacement": "restored-index-$1",
    "include_global_state": false,
    "ignore_unavailable": true,
    "include_aliases": false
  }'
```

### Using the OpenSearch Dashboard

1. Log in to the OpenSearch Dashboard
2. Navigate to Management > Snapshot Management
3. Select the "s3-snapshots" repository
4. Click on the snapshot you want to restore from
5. Click "Restore" button
6. Select the indexes you wish to restore
7. Configure restore options:
   - Rename pattern/replacement (optional)
   - Include aliases (optional)
   - Include global state (usually set to false)
8. Click "Restore" to begin the process

## Restore Options Explained

- **indices**: Comma-separated list of indexes to restore. Omit to restore all indexes.
- **rename_pattern** and **rename_replacement**: Regex pattern and replacement to rename indexes during restore.
- **ignore_unavailable**: Skip restore of indexes that don't exist in the snapshot.
- **include_global_state**: Whether to restore cluster global state.
- **include_aliases**: Whether to restore associated aliases.
- **index_settings**: Override index settings during restore.
- **partial**: Allow partial restore if some shards are missing.

## Example: Restoring with Index Renaming

To restore an index with a new name to avoid conflicts with existing indexes:

```bash
curl -X POST "https://<opensearch-endpoint>/_snapshot/s3-snapshots/snapshot-name/_restore" \
  -H "Content-Type: application/json" \
  -u '<username>:<password>' \
  -d '{
    "indices": "original-index",
    "rename_pattern": "original-(.*)",
    "rename_replacement": "restored-$1",
    "include_global_state": false
  }'
```

This will restore "original-index" as "restored-index".

## Monitoring Restore Progress

### Using the API

```bash
# Check restore progress
curl -X GET "https://<opensearch-endpoint>/_cat/recovery?v" \
  -u '<username>:<password>'
```

### Using the Dashboard

1. Navigate to Management > Index Management
2. Look for your newly restored index
3. Check the status and health of the index

## Verifying the Restored Index

After restoration, verify that your index is working correctly:

```bash
# Get index information
curl -X GET "https://<opensearch-endpoint>/<restored-index-name>/_stats?pretty" \
  -u '<username>:<password>'

# Count documents in the restored index
curl -X GET "https://<opensearch-endpoint>/<restored-index-name>/_count?pretty" \
  -u '<username>:<password>'
```

## Common Issues and Troubleshooting

### 1. Insufficient Disk Space

Error: `[FORBIDDEN/12/index read-only / allow delete (api)]`

Solution:
- Free up disk space
- Adjust cluster settings:
```bash
curl -X PUT "https://<opensearch-endpoint>/_cluster/settings" \
  -H "Content-Type: application/json" \
  -u '<username>:<password>' \
  -d '{"persistent": {"cluster.routing.allocation.disk.threshold_enabled": false}}'
```
- After restore, reset the setting to true

### 2. Index Already Exists

Error: `[CONFLICT/1/index exists while performing restore operation]`

Solutions:
- Use index renaming during restore
- Delete the existing index first (caution!)
- Set `"include_aliases": false` to avoid alias conflicts

### 3. Version Compatibility Issues

Error: `[SNAPSHOT_RESTORE_EXCEPTION/unable to restore snapshot due to version incompatibility]`

Solution: Only restore snapshots to same-version or newer OpenSearch clusters

### 4. Permission Denied

Error: `[SECURITY_EXCEPTION/no permissions for [cluster:admin/snapshot/restore] for user]`

Solution: Ensure the user has appropriate permissions. Map the user to a role with snapshot restore permissions:

```json
{
  "userName": "admin-user",
  "opensearchRole": "snapshot_manager"
}
```

## Using AWS CLI with Lambda for Restoration

You can trigger a restoration using our Lambda functions:

```bash
aws lambda invoke \
  --function-name <environment>-opensearch-snapshot-restore \
  --payload '{
    "snapshotName": "snapshot-2023-06-15-14-30-00",
    "indexName": "index-name",
    "renamePattern": "index-(.*)",
    "renameReplacement": "restored-$1"
  }' \
  response.json
```

## Automating Restores with Scripts

For frequent restoration needs, you can use this Python script:

```python
import boto3
import json
import requests
from requests_aws4auth import AWS4Auth

# Configuration
host = 'your-opensearch-endpoint'  
region = 'us-east-1'
repository_name = 's3-snapshots'
snapshot_name = 'snapshot-2023-06-15-14-30-00'
indices = 'index-name'
rename_pattern = 'index-(.*)'
rename_replacement = 'restored-$1'

# AWS authentication
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, 
                  region, 'es', session_token=credentials.token)

# Restore API call
restore_url = f'https://{host}/_snapshot/{repository_name}/{snapshot_name}/_restore'
payload = {
    'indices': indices,
    'rename_pattern': rename_pattern,
    'rename_replacement': rename_replacement,
    'include_global_state': False
}

headers = {"Content-Type": "application/json"}
response = requests.post(restore_url, auth=awsauth, json=payload, headers=headers)

print(f"Restore response: {response.status_code}")
print(response.text)
```

## Best Practices

1. **Test Restores Regularly**: Periodically test the restore process to ensure snapshots are valid
2. **Rename Indexes During Restore**: Use renaming to avoid conflicts with existing indexes
3. **Avoid Including Global State**: Unless specifically needed, set `include_global_state` to false
4. **Monitor Disk Space**: Ensure sufficient disk space before large restores
5. **Document Snapshot Contents**: Keep records of what each snapshot contains
6. **Restore to Test Cluster First**: For critical data, validate restored indexes in a test environment 