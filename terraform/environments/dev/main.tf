provider "aws" {
  region = "us-east-2"
}

# Create VPC and networking
module "vpc" {
  source = "../../modules/vpc"

  environment         = "dev"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  azs                 = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

# Create the jump server
module "jump_server" {
  source = "../../modules/ec2"

  environment      = "dev"
  instance_type    = "t3.micro"
  key_name         = "opensearch-jump-server-key"
  subnet_id        = "subnet-0123456789abcdef1"  # Hardcoded value
  security_group_id = "sg-0123456789abcdef0"     # Hardcoded value
}

# Create the OpenSearch domain
module "opensearch" {
  source = "../../modules/opensearch"

  environment          = "dev"
  region               = "us-east-2"
  domain_name          = "dev-opensearch"
  engine_version       = "OpenSearch_2.5"
  instance_type        = "t3.small"
  instance_count       = 3
  volume_size          = 10
  create_snapshot      = true
  subnet_ids           = ["subnet-0123456789abcdef4", "subnet-0123456789abcdef5", "subnet-0123456789abcdef6"]  # Hardcoded value
  security_group_id    = "sg-0123456789abcdef0"     # Hardcoded value
  master_user_name     = "admin"
  master_user_password = "StrongPassword123!" # Hardcoded password for demo, use a secure method in production
}

# Create role mapper Lambda function
module "role_mapper_lambda" {
  source = "../../modules/lambda"

  environment       = "dev"
  lambda_name       = "opensearch-role-mapper"
  lambda_source_path = "../../../lambda/role_mapper"
  handler           = "index.lambda_handler"
  runtime           = "python3.9"
  timeout           = 120
  memory_size       = 128
  
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPut",
          "es:ESHttpPost",
          "iam:GetRole",
          "sts:GetCallerIdentity"
        ]
        Resource = [
          "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*",
          "*"
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = "search-dev-opensearch-abcdef1234567890.us-east-2.es.amazonaws.com"
    REGION              = "us-east-2"
    MASTER_USERNAME     = "admin"
    MASTER_PASSWORD     = "StrongPassword123!" # Hardcoded password for demo, use a secure method in production
  }
  
  vpc_config = {
    subnet_ids         = ["subnet-0123456789abcdef4", "subnet-0123456789abcdef5", "subnet-0123456789abcdef6"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }
}

# Create snapshot Lambda function
module "snapshot_lambda" {
  source = "../../modules/lambda"

  environment       = "dev"
  lambda_name       = "opensearch-snapshot-lambda"
  lambda_source_path = "../../../lambda/snapshot"
  handler           = "index.lambda_handler"
  runtime           = "python3.9"
  timeout           = 300
  memory_size       = 256
  
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::dev-opensearch-snapshots-abcdef123456",
          "arn:aws:s3:::dev-opensearch-snapshots-abcdef123456/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPut",
          "es:ESHttpPost",
          "es:ESHttpDelete"
        ]
        Resource = [
          "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::123456789012:role/dev-opensearch-snapshot-role"
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = "search-dev-opensearch-abcdef1234567890.us-east-2.es.amazonaws.com"
    BUCKET_NAME         = "dev-opensearch-snapshots-abcdef123456"
    REGION              = "us-east-2"
    ROLE_ARN            = "arn:aws:iam::123456789012:role/dev-opensearch-snapshot-role"
  }
  
  vpc_config = {
    subnet_ids         = ["subnet-0123456789abcdef4", "subnet-0123456789abcdef5", "subnet-0123456789abcdef6"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }
  
  # Run every hour (0th minute of every hour, every day)
  schedule_expression = "cron(0 * * * ? *)"
}

# Create IAM user mapper Lambda function
module "iam_mapper_lambda" {
  source = "../../modules/lambda"

  environment       = "dev"
  lambda_name       = "opensearch-iam-user-mapper"
  lambda_source_path = "../../../lambda/iam_mapper"
  handler           = "index.lambda_handler"
  runtime           = "python3.9"
  timeout           = 120
  memory_size       = 128
  
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPut",
          "es:ESHttpPost",
          "iam:GetUser",
          "iam:CreateUser",
          "iam:TagUser",
          "iam:CreateLoginProfile",
          "iam:CreateAccessKey",
          "iam:ListGroupsForUser",
          "iam:AddUserToGroup"
        ]
        Resource = [
          "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*",
          "arn:aws:iam::*:user/*",
          "arn:aws:iam::*:group/*"
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = "search-dev-opensearch-abcdef1234567890.us-east-2.es.amazonaws.com"
    REGION              = "us-east-2"
    MASTER_USERNAME     = "admin"
    MASTER_PASSWORD     = "StrongPassword123!" # Hardcoded password for demo, use a secure method in production
  }
  
  vpc_config = {
    subnet_ids         = ["subnet-0123456789abcdef4", "subnet-0123456789abcdef5", "subnet-0123456789abcdef6"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }
} 