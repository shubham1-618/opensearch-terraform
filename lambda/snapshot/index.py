import boto3
import os
import json
import requests
import logging
import time
from requests_aws4auth import AWS4Auth
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables with validation
try:
    host = os.environ['OPENSEARCH_ENDPOINT']  # OpenSearch domain endpoint without https://
    region = os.environ['REGION']
    bucket_name = os.environ['BUCKET_NAME']
    role_arn = os.environ['ROLE_ARN']
    max_retries = int(os.environ.get('MAX_RETRIES', '3'))
    retry_delay = int(os.environ.get('RETRY_DELAY', '5'))
except KeyError as e:
    logger.error(f"Missing required environment variable: {str(e)}")
    raise

# AWS credentials for signing requests
try:
    credentials = boto3.Session().get_credentials()
    awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, 'es', session_token=credentials.token)
except Exception as e:
    logger.error(f"Failed to initialize AWS credentials: {str(e)}")
    raise

# Endpoints for repository and snapshot API
repository_endpoint = f'https://{host}/_snapshot/s3-snapshots'
snapshot_endpoint = f'https://{host}/_snapshot/s3-snapshots/snapshot-'

def lambda_handler(event, context):
    """
    Lambda function handler that creates a repository (if it doesn't exist) and takes a snapshot.
    Includes error handling and retries for robustness.
    """
    try:
        logger.info("Starting snapshot process")
        logger.info(f"OpenSearch endpoint: {host}")
        
        # First check if repository exists
        repo_exists = check_repository_with_retry()
        
        # If repository doesn't exist, create it
        if not repo_exists:
            logger.info("Repository doesn't exist. Creating...")
            create_repository_with_retry()
        else:
            logger.info("Repository already exists.")
            
        # Take snapshot
        snapshot_name = take_snapshot_with_retry()
        
        # Check snapshot status
        status = check_snapshot_status(snapshot_name)
        
        logger.info(f"Snapshot process completed successfully: {snapshot_name}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Snapshot successfully initiated!',
                'snapshot_name': snapshot_name,
                'status': status
            })
        }
    except Exception as e:
        logger.error(f"Error during snapshot process: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'message': 'Error taking snapshot'
            })
        }

def check_repository_with_retry():
    """
    Check if repository exists with retry logic
    """
    for attempt in range(max_retries):
        try:
            logger.info(f"Checking if repository exists (attempt {attempt+1}/{max_retries})")
            repo_check = requests.get(repository_endpoint, auth=awsauth, timeout=30)
            
            if repo_check.status_code == 200:
                logger.info("Repository exists")
                return True
            elif repo_check.status_code == 404:
                logger.info("Repository does not exist")
                return False
            else:
                logger.warning(f"Unexpected status code while checking repository: {repo_check.status_code}")
                logger.warning(f"Response: {repo_check.text}")
                
            # Don't retry if we get a clear answer
            if repo_check.status_code in [200, 404]:
                break
                
        except requests.exceptions.RequestException as e:
            logger.warning(f"Request exception while checking repository: {str(e)}")
            
        if attempt < max_retries - 1:
            logger.info(f"Retrying in {retry_delay} seconds...")
            time.sleep(retry_delay)
    
    # If we've exhausted all retries, assume repository doesn't exist
    return False

def create_repository_with_retry():
    """
    Creates an S3 repository for OpenSearch snapshots with retry logic
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
    
    for attempt in range(max_retries):
        try:
            logger.info(f"Creating repository (attempt {attempt+1}/{max_retries})")
            response = requests.put(
                repository_endpoint,
                auth=awsauth,
                json=payload,
                headers=headers,
                timeout=30
            )
            
            if response.status_code >= 200 and response.status_code < 300:
                logger.info("Repository created successfully!")
                return True
            else:
                logger.warning(f"Failed to create repository: Status code {response.status_code}")
                logger.warning(f"Response: {response.text}")
                
        except requests.exceptions.RequestException as e:
            logger.warning(f"Request exception while creating repository: {str(e)}")
            
        if attempt < max_retries - 1:
            logger.info(f"Retrying in {retry_delay} seconds...")
            time.sleep(retry_delay)
    
    # If we've exhausted all retries
    error_message = f"Failed to create repository after {max_retries} attempts"
    logger.error(error_message)
    raise Exception(error_message)

def take_snapshot_with_retry():
    """
    Takes a snapshot of the OpenSearch domain with retry logic
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
    
    for attempt in range(max_retries):
        try:
            logger.info(f"Initiating snapshot {snapshot_name} (attempt {attempt+1}/{max_retries})")
            response = requests.put(
                snapshot_url,
                auth=awsauth,
                json=payload,
                headers=headers,
                timeout=30
            )
            
            if response.status_code >= 200 and response.status_code < 300:
                logger.info(f"Snapshot {snapshot_name} initiated successfully!")
                return snapshot_name
            else:
                logger.warning(f"Failed to initiate snapshot: Status code {response.status_code}")
                logger.warning(f"Response: {response.text}")
                
        except requests.exceptions.RequestException as e:
            logger.warning(f"Request exception while initiating snapshot: {str(e)}")
            
        if attempt < max_retries - 1:
            logger.info(f"Retrying in {retry_delay} seconds...")
            time.sleep(retry_delay)
    
    # If we've exhausted all retries
    error_message = f"Failed to initiate snapshot after {max_retries} attempts"
    logger.error(error_message)
    raise Exception(error_message)

def check_snapshot_status(snapshot_name):
    """
    Check the status of a snapshot
    """
    try:
        status_url = f"{repository_endpoint}/{snapshot_name}"
        response = requests.get(
            status_url,
            auth=awsauth,
            timeout=30
        )
        
        if response.status_code >= 200 and response.status_code < 300:
            status_data = response.json()
            logger.info(f"Snapshot status: {json.dumps(status_data)}")
            return status_data
        else:
            logger.warning(f"Failed to check snapshot status: {response.status_code}")
            logger.warning(f"Response: {response.text}")
            return {"status": "unknown", "reason": response.text}
            
    except Exception as e:
        logger.warning(f"Error checking snapshot status: {str(e)}")
        return {"status": "unknown", "reason": str(e)} 