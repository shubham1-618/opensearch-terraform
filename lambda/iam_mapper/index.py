import boto3
import os
import json
import requests
from requests_aws4auth import AWS4Auth

# Environment variables
host = os.environ['OPENSEARCH_ENDPOINT']  # OpenSearch domain endpoint without https://
region = os.environ['REGION']

# AWS credentials for signing requests
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, 'es', session_token=credentials.token)

# IAM client
iam = boto3.client('iam')

def lambda_handler(event, context):
    """
    Maps an IAM user to an OpenSearch role.
    
    Event structure should include:
    {
        "userName": "username-to-map"
    }
    """
    try:
        # Get the username from the event
        user_name = event.get('userName')
        
        if not user_name:
            return {
                'statusCode': 400,
                'body': json.dumps('userName parameter is required')
            }
        
        # Get the IAM user ARN
        try:
            user_response = iam.get_user(UserName=user_name)
            user_arn = user_response['User']['Arn']
        except Exception as e:
            return {
                'statusCode': 404,
                'body': json.dumps(f'IAM User not found: {str(e)}')
            }
        
        # Map the user to all_access role in OpenSearch
        role_mapping_endpoint = f'https://{host}/_plugins/_security/api/rolesmapping/all_access'
        
        # First get current mappings
        get_response = requests.get(role_mapping_endpoint, auth=awsauth)
        
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
                    'body': json.dumps(f'User {user_name} is already mapped to all_access role')
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
            auth=awsauth,
            json=update_payload,
            headers=headers
        )
        
        if put_response.status_code >= 200 and put_response.status_code < 300:
            return {
                'statusCode': 200,
                'body': json.dumps(f'Successfully mapped user {user_name} to all_access role')
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