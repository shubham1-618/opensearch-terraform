import boto3
import os
import json
import requests
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

def lambda_handler(event, context):
    """
    Maps an IAM role to an OpenSearch role.
    
    Event structure should include:
    {
        "roleName": "role-to-map",
        "roleArn": "arn:aws:iam::123456789012:role/role-name", 
        "opensearchRole": "opensearch-role-name",  # Default to 'all_access' if not specified
        "accountId": "123456789012"  # AWS account ID (optional if roleArn is provided)
    }
    """
    try:
        # Extract parameters from event
        role_name = event.get('roleName')
        role_arn = event.get('roleArn')
        opensearch_role = event.get('opensearchRole', 'all_access')
        account_id = event.get('accountId')
        
        # Validate required parameters
        if not (role_name or role_arn):
            return {
                'statusCode': 400,
                'body': json.dumps('Either roleName or roleArn parameter is required')
            }
            
        # Construct role ARN if not provided
        if not role_arn:
            if not account_id:
                # Get the AWS account ID if not provided
                sts = boto3.client('sts')
                account_id = sts.get_caller_identity()["Account"]
            
            role_arn = f"arn:aws:iam::{account_id}:role/{role_name}"
        
        # Check if master password is available
        if not master_password:
            return {
                'statusCode': 500,
                'body': json.dumps('MASTER_PASSWORD environment variable not set')
            }
        
        # Map the role to specified OpenSearch role
        role_mapping_endpoint = f'https://{host}/_plugins/_security/api/rolesmapping/{opensearch_role}'
        
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
            
            # Check if role is already mapped
            backend_roles = update_payload.get('backend_roles', [])
            
            # If role is already mapped, return success
            if role_arn in backend_roles:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': f'Role {role_name} is already mapped to {opensearch_role} role'
                    })
                }
            
            # Add role to existing backend roles
            backend_roles.append(role_arn)
            update_payload['backend_roles'] = backend_roles
        else:
            # If no existing mapping, create a new one with just the backend_roles
            update_payload = {
                "backend_roles": [role_arn]
            }
        
        # Make sure 'users' field exists to preserve admin user
        if 'users' not in update_payload:
            update_payload['users'] = []
        
        # Always ensure 'admin' is in the users list for all_access role
        if opensearch_role == 'all_access' and 'admin' not in update_payload['users']:
            update_payload['users'].append('admin')
        
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
                    'message': f'Successfully mapped role {role_name} to {opensearch_role} role',
                    'mapping': update_payload
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
            'body': json.dumps(f'Error mapping IAM role: {str(e)}')
        } 