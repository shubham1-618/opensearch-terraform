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

def generate_password(length=16):
    """
    Generate a secure random password that meets OpenSearch requirements:
    - At least 8 characters
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    """
    if length < 8:
        length = 16  # Ensure minimum length
        
    lowercase = string.ascii_lowercase
    uppercase = string.ascii_uppercase
    digits = string.digits
    special = "!@#$%^&*()_+-=[]{}|;:,.<>?"
    
    # Ensure at least one of each required character type
    password = [
        random.choice(uppercase),
        random.choice(lowercase),
        random.choice(digits),
        random.choice(special)
    ]
    
    # Fill the rest with random characters from all types
    all_chars = lowercase + uppercase + digits + special
    password.extend(random.choice(all_chars) for _ in range(length - 4))
    
    # Shuffle the password characters
    random.shuffle(password)
    
    return ''.join(password)

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

def create_opensearch_internal_user(user_name, password, auth):
    """
    Creates an internal user in OpenSearch with the same name as the IAM user
    """
    try:
        # First check if user already exists
        internal_users_endpoint = f'https://{host}/_plugins/_security/api/internalusers/{user_name}'
        
        # Check if the user exists
        get_response = requests.get(internal_users_endpoint, auth=auth, verify=True)
        
        if get_response.status_code == 200:
            # User already exists
            return True, "existing"
        
        # If user doesn't exist (404), create it
        if get_response.status_code == 404:
            # Create the user with password and backend role
            account_id = boto3.client('sts').get_caller_identity()['Account']
            user_payload = {
                "password": password,
                "backend_roles": [f"arn:aws:iam::{account_id}:user/{user_name}"],
                "attributes": {
                    "created_by": "iam_mapper_lambda"
                }
            }
            
            headers = {"Content-Type": "application/json"}
            create_response = requests.put(
                internal_users_endpoint,
                auth=auth,
                json=user_payload,
                headers=headers,
                verify=True
            )
            
            if create_response.status_code >= 200 and create_response.status_code < 300:
                return True, "created"
            else:
                return False, f"Error creating internal user: {create_response.text}"
        
        # Any other status code indicates an error
        return False, f"Error checking if internal user exists: {get_response.text}"
    except Exception as e:
        return False, f"Exception creating internal user: {str(e)}"

def lambda_handler(event, context):
    """
    Maps an IAM user to an OpenSearch role.
    If the user doesn't exist, it creates the user first.
    Also creates a matching internal user in OpenSearch.
    
    Event structure should include:
    {
        "userName": "username-to-map",
        "createIfMissing": true,  # Optional, defaults to true
        "createInternalUser": true,  # Optional, defaults to true
        "opensearchRole": "all_access"  # Optional, defaults to all_access
    }
    """
    try:
        # Get the username from the event
        user_name = event.get('userName')
        create_if_missing = event.get('createIfMissing', True)
        create_internal_user = event.get('createInternalUser', True)
        opensearch_role = event.get('opensearchRole', 'all_access')
        
        if not user_name:
            return {
                'statusCode': 400,
                'body': json.dumps('userName parameter is required')
            }
        
        # Check if master password is available
        if not master_password:
            return {
                'statusCode': 500,
                'body': json.dumps('MASTER_PASSWORD environment variable not set')
            }
        
        # Use basic auth for OpenSearch request
        auth = (master_username, master_password)
        
        # Get or create the IAM user ARN
        if create_if_missing:
            try:
                user_arn, credentials, status = create_iam_user(user_name)
                
                # Create an internal user in OpenSearch if requested
                if create_internal_user and credentials:  # Only for newly created users
                    internal_user_success, internal_user_status = create_opensearch_internal_user(
                        user_name, 
                        credentials['password'], 
                        auth
                    )
                    if not internal_user_success:
                        return {
                            'statusCode': 500,
                            'body': json.dumps(f'Error creating internal OpenSearch user: {internal_user_status}')
                        }
                
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
        
        # Map the user to the specified OpenSearch role
        role_mapping_endpoint = f'https://{host}/_plugins/_security/api/rolesmapping/{opensearch_role}'
        
        # First get current mappings
        get_response = requests.get(role_mapping_endpoint, auth=auth, verify=True)
        
        if get_response.status_code != 200:
            return {
                'statusCode': get_response.status_code,
                'body': json.dumps(f'Error getting role mappings: {get_response.text}')
            }
        
        # Parse existing mappings
        current_mappings = get_response.json()
        
        # Initialize update_payload with all existing mappings to preserve them
        update_payload = {}
        
        if opensearch_role in current_mappings:
            # Copy all existing mapping fields (users, hosts, etc.)
            update_payload = current_mappings[opensearch_role]
            
            # Filter out reserved/hidden fields that might cause errors
            reserved_fields = ['hidden', 'reserved', '_meta']
            for field in reserved_fields:
                if field in update_payload:
                    del update_payload[field]
            
            backend_roles = update_payload.get('backend_roles', [])
            
            # If user is already mapped, return success
            if user_arn in backend_roles:
                response_data = {
                    'message': f'User {user_name} is already mapped to {opensearch_role} role',
                    'userStatus': status,
                }
                
                if credentials:
                    response_data['credentials'] = credentials
                
                return {
                    'statusCode': 200,
                    'body': json.dumps(response_data)
                }
            
            # Add user to existing backend roles
            backend_roles.append(user_arn)
            update_payload['backend_roles'] = backend_roles
        else:
            # Create new mapping with the user
            update_payload = {
                "backend_roles": [user_arn],
                "users": []
            }
        
        # Make sure 'users' field exists to preserve other users
        if 'users' not in update_payload:
            update_payload['users'] = []
        
        # Always ensure 'admin' is in the users list for all_access role
        if opensearch_role == 'all_access' and 'admin' not in update_payload['users']:
            update_payload['users'].append('admin')
        
        # If we created an internal user, add it to the users list for this role too
        if create_internal_user and status == "created" and user_name not in update_payload['users']:
            update_payload['users'].append(user_name)
        
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
            response_data = {
                'message': f'Successfully mapped user {user_name} to {opensearch_role} role',
                'userStatus': status,
                'mapping': update_payload
            }
            
            if credentials:
                response_data['credentials'] = credentials
                
            return {
                'statusCode': 200,
                'body': json.dumps(response_data)
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