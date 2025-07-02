provider "aws" {
  region = var.region
}

# Create VPC and networking
module "vpc" {
  source = "../../modules/vpc"

  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  azs                 = var.azs
}

# Create the jump server
module "jump_server" {
  source = "../../modules/ec2"

  environment      = var.environment
  instance_type    = var.jump_server_instance_type
  key_name         = var.key_name
  subnet_id        = module.vpc.public_subnet_ids[0]
  security_group_id = module.vpc.jump_server_sg_id
}

# Create the OpenSearch domain
module "opensearch" {
  source = "../../modules/opensearch"

  environment          = var.environment
  region               = var.region
  domain_name          = var.domain_name
  engine_version       = var.engine_version
  instance_type        = var.opensearch_instance_type
  instance_count       = var.opensearch_instance_count
  volume_size          = var.opensearch_volume_size
  create_snapshot      = var.create_snapshot
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_id    = module.vpc.opensearch_sg_id
  master_user_name     = var.master_user_name
  master_user_password = var.master_user_password
  
  # Service-linked role configuration - disable creation if it already exists
  create_service_linked_role = false
  use_existing_service_linked_role = true
}

# Create role mapper Lambda function
module "role_mapper_lambda" {
  source = "../../modules/lambda"

  environment       = var.environment
  lambda_name       = "opensearch-role-mapper"
  lambda_source_path = "../../../lambda/role_mapper"
  handler           = "index.lambda_handler"
  runtime           = "python3.9"
  timeout           = 120
  memory_size       = 128
  
  # Set to false if log groups already exist
  create_log_group = false
  
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
          "${module.opensearch.opensearch_domain_id}/*",
          "*"
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = module.opensearch.opensearch_endpoint
    REGION              = var.region
    MASTER_USERNAME     = var.master_user_name
    MASTER_PASSWORD     = var.master_user_password
  }
  
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.opensearch_sg_id]
  }
}

# Create snapshot Lambda function
module "snapshot_lambda" {
  source = "../../modules/lambda"

  environment       = var.environment
  lambda_name       = "opensearch-snapshot-lambda"
  lambda_source_path = "../../../lambda/snapshot"
  handler           = "index.lambda_handler"
  runtime           = "python3.9"
  timeout           = 300
  memory_size       = 256
  
  # Error handling configuration
  max_retries       = 3
  retry_delay       = 5
  log_retention_days = 30
  create_error_alarm = true
  
  # Set to false if log groups already exist
  create_log_group = false
  
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
          "arn:aws:s3:::${module.opensearch.snapshot_bucket_name}",
          "arn:aws:s3:::${module.opensearch.snapshot_bucket_name}/*"
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
          "${module.opensearch.opensearch_domain_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          "${module.opensearch.snapshot_role_arn}"
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = module.opensearch.opensearch_endpoint
    BUCKET_NAME         = module.opensearch.snapshot_bucket_name
    REGION              = var.region
    ROLE_ARN            = module.opensearch.snapshot_role_arn
  }
  
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.opensearch_sg_id]
  }
  
  # Run every hour (0th minute of every hour, every day)
  schedule_expression = "cron(0 * * * ? *)"
}

# Create IAM user mapper Lambda function
module "iam_mapper_lambda" {
  source = "../../modules/lambda"

  environment       = var.environment
  lambda_name       = "opensearch-iam-user-mapper"
  lambda_source_path = "../../../lambda/iam_mapper"
  handler           = "index.lambda_handler"
  runtime           = "python3.9"
  timeout           = 120
  memory_size       = 128
  
  # Set to false if log groups already exist
  create_log_group = false
  
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
          "${module.opensearch.opensearch_domain_id}/*",
          "arn:aws:iam::*:user/*",
          "arn:aws:iam::*:group/*"
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = module.opensearch.opensearch_endpoint
    REGION              = var.region
    MASTER_USERNAME     = var.master_user_name
    MASTER_PASSWORD     = var.master_user_password
  }
  
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.opensearch_sg_id]
  }
} 