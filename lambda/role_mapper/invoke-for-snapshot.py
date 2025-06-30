import boto3
import json
import os
import argparse

def main():
    parser = argparse.ArgumentParser(description='Map snapshot Lambda execution role to OpenSearch roles')
    parser.add_argument('--region', required=False, default='us-east-1', help='AWS region')
    parser.add_argument('--environment', required=False, default='dev', help='Environment (dev, prod, etc.)')
    args = parser.parse_args()

    region = args.region
    environment = args.environment

    # Initialize AWS clients
    lambda_client = boto3.client('lambda', region_name=region)
    
    # Get the function ARNs
    role_mapper_lambda_name = f"{environment}-opensearch-role-mapper"
    snapshot_lambda_name = f"{environment}-opensearch-snapshot-lambda"
    
    # Get the snapshot Lambda's execution role
    try:
        snapshot_lambda_config = lambda_client.get_function(FunctionName=snapshot_lambda_name)
        snapshot_lambda_role_arn = snapshot_lambda_config['Configuration']['Role']
        
        print(f"Found snapshot Lambda role ARN: {snapshot_lambda_role_arn}")
        
        # Extract the role name from ARN
        # Format: arn:aws:iam::123456789012:role/role-name
        role_name = snapshot_lambda_role_arn.split('/')[-1]
        
        # Invoke the role mapper Lambda to map the snapshot Lambda role to all_access
        payload = {
            "roleName": role_name,
            "roleArn": snapshot_lambda_role_arn,
            "opensearchRole": "all_access"  # Map to all_access for full permissions
        }
        
        print(f"Invoking role mapper with payload: {json.dumps(payload)}")
        
        # Invoke role mapper Lambda
        response = lambda_client.invoke(
            FunctionName=role_mapper_lambda_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(payload)
        )
        
        # Parse response
        response_payload = json.loads(response['Payload'].read().decode())
        print(f"Role mapper response: {json.dumps(response_payload, indent=2)}")
        
        # Map to additional roles if needed
        additional_roles = ["manage_snapshots", "cluster_admin"]
        for role in additional_roles:
            payload["opensearchRole"] = role
            print(f"Mapping to role: {role}")
            
            response = lambda_client.invoke(
                FunctionName=role_mapper_lambda_name,
                InvocationType='RequestResponse',
                Payload=json.dumps(payload)
            )
            
            response_payload = json.loads(response['Payload'].read().decode())
            print(f"Response for {role}: {json.dumps(response_payload, indent=2)}")
        
        print("\nSnapshot Lambda role has been mapped to OpenSearch roles successfully!")
        print("The snapshot Lambda should now be able to create repositories and snapshots.")
        
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main() 