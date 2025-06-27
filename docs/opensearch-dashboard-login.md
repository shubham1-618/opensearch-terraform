# Logging into OpenSearch Dashboard

This guide explains how to log into the OpenSearch dashboard using the newly created IAM user credentials.

## Prerequisites

- Successfully executed the IAM User Mapper Lambda function
- SSH access to the jump server
- The credentials returned by the Lambda function

## Step 1: Set Up SSH Tunnel

First, establish an SSH tunnel to the OpenSearch domain through the jump server:

```bash
ssh -i opensearch-jump-server-key.pem -L 9200:OPENSEARCH_ENDPOINT:443 ec2-user@JUMP_SERVER_PUBLIC_IP
```

Replace:
- `OPENSEARCH_ENDPOINT` with your OpenSearch domain endpoint (without https://)
- `JUMP_SERVER_PUBLIC_IP` with the public IP of the jump server

## Step 2: Access the Dashboard

Once the SSH tunnel is established, open your web browser and navigate to:

```
https://localhost:9200/_dashboards/
```

You might see a security warning about the certificate. This is expected because you're accessing the service through localhost. You can proceed safely.

## Step 3: Login with IAM Credentials

On the login screen, you'll have two options:

1. **Basic Authentication**
   - Username: The IAM username (e.g., `test-opensearch-user`)
   - Password: The temporary password provided in the Lambda function response

2. **IAM Authentication**
   - If you have AWS CLI configured with the user's access keys, you can use IAM authentication

For first-time login, use the Basic Authentication method with the temporary password. You'll be prompted to change this password.

## Step 4: Change Password

After your first login with the temporary password, you'll be required to set a new password. Make sure to:

1. Choose a strong password
2. Store it securely
3. Follow your organization's password policy

## Step 5: Verify Access

After logging in, you should have access to the OpenSearch dashboard with all_access permissions. You can:

- Create and manage indices
- Set up visualizations
- Configure alerts
- Access all dashboard features

## Troubleshooting

If you encounter issues logging in:

1. **Access Denied**
   - Verify the user was successfully mapped by checking the Lambda function logs
   - Ensure the user has been added to the correct role in OpenSearch

2. **Cannot Connect to Dashboard**
   - Check that your SSH tunnel is properly established
   - Verify the OpenSearch domain endpoint is correct

3. **Password Issues**
   - If you've forgotten the password, you can reset it through the AWS IAM console
   - Then use the IAM User Mapper function again to refresh the mapping

4. **Certificate Warnings**
   - These are expected when using SSH tunneling
   - You can safely proceed past these warnings in your browser 