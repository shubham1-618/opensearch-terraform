import boto3
import json
import requests
import os
from requests_aws4auth import AWS4Auth
from datetime import datetime

# Environment variables with hardcoded fallbacks for client's existing OpenSearch domain
host = os.environ.get('OPENSEARCH_ENDPOINT', "search-dev-opensearch-abcdef1234567890.us-east-2.es.amazonaws.com")
region = os.environ.get('REGION', "us-east-2")
bucket_name = os.environ.get('BUCKET_NAME', "dev-opensearch-snapshots-abcdef123456")
role_arn = os.environ.get('ROLE_ARN', "arn:aws:iam::123456789012:role/dev-opensearch-snapshot-role")

# AWS credentials for signing requests
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, 'es', session_token=credentials.token)

# Endpoints for repository and snapshot API
repository_endpoint = f'https://{host}/_snapshot/s3-snapshots'

def lambda_handler(event, context):
    """
    Lambda function handler that creates a repository (if it doesn't exist) and takes a snapshot.
    """
    try:
        # First check if repository exists
        repo_check = requests.get(repository_endpoint, auth=awsauth)
        
        # If repository doesn't exist, create it
        if repo_check.status_code != 200:
            print("Repository doesn't exist. Creating...")
            create_repository()
        else:
            print("Repository already exists.")
            
        # Take snapshot
        take_snapshot()
        
        return {
            'statusCode': 200,
            'body': json.dumps('Snapshot successfully initiated!')
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error taking snapshot: {str(e)}')
        }

def create_repository():
    """
    Creates an S3 repository for OpenSearch snapshots
    """
    payload = {
        "type": "s3",
        "settings": {
            "bucket": bucket_name,
            "region": region,
            "role_arn": role_arn
        }
    }
    
    headers = {"Content-Type": "application/json"}
    
    response = requests.put(
        repository_endpoint,
        auth=awsauth,
        json=payload,
        headers=headers
    )
    
    if response.status_code >= 200 and response.status_code < 300:
        print("Repository created successfully!")
    else:
        raise Exception(f"Failed to create repository: {response.text}")

def take_snapshot():
    """
    Takes a snapshot of the OpenSearch domain
    """
    # Generate timestamp for snapshot name
    timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M-%S')
    snapshot_name = f"snapshot-{timestamp}"
    
    # API endpoint for this specific snapshot
    snapshot_url = f"{repository_endpoint}/{snapshot_name}"
    
    # Request body (optional settings)
    payload = {
        "indices": "*",  # All indices
        "ignore_unavailable": True,
        "include_global_state": True
    }
    
    headers = {"Content-Type": "application/json"}
    
    # Initiate snapshot
    response = requests.put(
        snapshot_url,
        auth=awsauth,
        json=payload,
        headers=headers
    )
    
    if response.status_code >= 200 and response.status_code < 300:
        print(f"Snapshot {snapshot_name} initiated successfully!")
    else:
        raise Exception(f"Failed to initiate snapshot: {response.text}") 