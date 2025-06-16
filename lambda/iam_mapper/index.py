import boto3
import os
import json
import requests
import string
import random
import uuid
import base64
from botocore.exceptions import ClientError
from requests_aws4auth import AWS4Auth

# Environment variables
host = os.environ['OPENSEARCH_ENDPOINT']  # OpenSearch domain endpoint without https://
region = os.environ['REGION']
master_username = os.environ.get('MASTER_USERNAME', 'admin')  # Default to 'admin' if not set
master_password = os.environ.get('MASTER_PASSWORD')  # This should be set in the Lambda environment

# AWS credentials for signing requests
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, 'es', session_token=credentials.token)

# AWS clients
iam = boto3.client('iam')

def generate_password(length=12):
    """Generate a secure random password"""
    chars = string.ascii_letters + string.digits + "!@#$%^&*()"
    return ''.join(random.choice(chars) for _ in range(length))

def create_iam_user(user_name):
    """
    Creates an IAM user if it doesn't exist and returns the user ARN
    """
    try:
        # Try to get the user first to see if they exist
        try:
            user_response = iam.get_user(UserName=user_name)
            return user_response['User']['Arn'], None, "existing"
        except iam.exceptions.NoSuchEntityException:
            # User doesn't exist, create them
            user_response = iam.create_user(
                UserName=user_name,
                Tags=[
                    {
                        'Key': 'CreatedBy',
                        'Value': 'opensearch-iam-mapper'
                    },
                    {
                        'Key': 'Purpose',
                        'Value': 'OpenSearch Access'
                    }
                ]
            )
            
            # Generate a strong password
            password = generate_password(16)
            
            # Create login profile (console access)
            iam.create_login_profile(
                UserName=user_name,
                Password=password,
                PasswordResetRequired=True
            )
            
            # Create access key (programmatic access)
            access_key_response = iam.create_access_key(
                UserName=user_name
            )
            
            credentials = {
                "username": user_name,
                "password": password,
                "access_key_id": access_key_response['AccessKey']['AccessKeyId'],
                "secret_access_key": access_key_response['AccessKey']['SecretAccessKey']
            }
            
            return user_response['User']['Arn'], credentials, "created"
    
    except Exception as e:
        raise Exception(f"Error creating IAM user: {str(e)}")

def lambda_handler(event, context):
    """
    Maps an IAM user to an OpenSearch role.
    If the user doesn't exist, it creates the user first.
    
    Event structure should include:
    {
        "userName": "username-to-map",
        "createIfMissing": true  # Optional, defaults to true
    }
    """
    try:
        # Get the username from the event
        user_name = event.get('userName')
        create_if_missing = event.get('createIfMissing', True)
        
        if not user_name:
            return {
                'statusCode': 400,
                'body': json.dumps('userName parameter is required')
            }
        
        # Get or create the IAM user ARN
        if create_if_missing:
            try:
                user_arn, credentials, status = create_iam_user(user_name)
            except Exception as e:
                return {
                    'statusCode': 500,
                    'body': json.dumps(f'Error creating/getting IAM User: {str(e)}')
                }
        else:
            # Just get the user ARN if it exists
            try:
                user_response = iam.get_user(UserName=user_name)
                user_arn = user_response['User']['Arn']
                credentials = None
                status = "existing"
            except Exception as e:
                return {
                    'statusCode': 404,
                    'body': json.dumps(f'IAM User not found: {str(e)}')
                }
        
        # Check if master password is available
        if not master_password:
            return {
                'statusCode': 500,
                'body': json.dumps('MASTER_PASSWORD environment variable not set')
            }
        
        # Map the user to all_access role in OpenSearch
        role_mapping_endpoint = f'https://{host}/_plugins/_security/api/rolesmapping/all_access'
        
        # Use basic auth for OpenSearch request
        auth = (master_username, master_password)
        
        # First get current mappings
        get_response = requests.get(role_mapping_endpoint, auth=auth, verify=True)
        
        if get_response.status_code != 200:
            return {
                'statusCode': get_response.status_code,
                'body': json.dumps(f'Error getting role mappings: {get_response.text}')
            }
        
        # Parse existing mappings
        current_mappings = get_response.json()
        
        # Check if user is already mapped
        if 'all_access' in current_mappings:
            backend_roles = current_mappings['all_access'].get('backend_roles', [])
            
            # If user is already mapped, return success
            if user_arn in backend_roles:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': f'User {user_name} is already mapped to all_access role',
                        'userStatus': status,
                        'credentials': credentials
                    })
                }
            
            # Add user to existing backend roles
            backend_roles.append(user_arn)
        else:
            # Create new mapping with the user
            backend_roles = [user_arn]
        
        # Prepare update payload
        update_payload = {
            "backend_roles": backend_roles
        }
        
        # Update role mapping
        headers = {"Content-Type": "application/json"}
        put_response = requests.put(
            role_mapping_endpoint,
            auth=auth,
            json=update_payload,
            headers=headers,
            verify=True
        )
        
        if put_response.status_code >= 200 and put_response.status_code < 300:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Successfully mapped user {user_name} to all_access role',
                    'userStatus': status,
                    'credentials': credentials
                })
            }
        else:
            return {
                'statusCode': put_response.status_code,
                'body': json.dumps(f'Error updating role mappings: {put_response.text}')
            }
            
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error mapping IAM user: {str(e)}')
        } 