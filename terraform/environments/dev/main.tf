provider "aws" {
  region = "us-east-2"
}

# Create S3 bucket for snapshots
resource "aws_s3_bucket" "snapshot_bucket" {
  bucket = "dev-opensearch-snapshots-abcdef123456"
  
  tags = {
    Name        = "dev-opensearch-snapshots"
    Environment = "dev"
  }
}

# IAM role for OpenSearch snapshot creation
resource "aws_iam_role" "opensearch_snapshot_role" {
  name = "dev-opensearch-snapshot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["opensearch.amazonaws.com", "es.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy for OpenSearch snapshot role
resource "aws_iam_policy" "opensearch_snapshot_policy" {
  name        = "dev-opensearch-snapshot-policy"
  description = "Policy for OpenSearch to create snapshots in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = [
          aws_s3_bucket.snapshot_bucket.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${aws_s3_bucket.snapshot_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "snapshot_policy_attachment" {
  role       = aws_iam_role.opensearch_snapshot_role.name
  policy_arn = aws_iam_policy.opensearch_snapshot_policy.arn
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
    MASTER_PASSWORD     = "StrongPassword123!"
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
          aws_s3_bucket.snapshot_bucket.arn,
          "${aws_s3_bucket.snapshot_bucket.arn}/*"
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
          aws_iam_role.opensearch_snapshot_role.arn
        ]
      }
    ]
  })
  
  environment_variables = {
    OPENSEARCH_ENDPOINT = "search-dev-opensearch-abcdef1234567890.us-east-2.es.amazonaws.com"
    BUCKET_NAME         = aws_s3_bucket.snapshot_bucket.id
    REGION              = "us-east-2"
    ROLE_ARN            = aws_iam_role.opensearch_snapshot_role.arn
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
          "iam:AddUserToGroup",
          "iam:UpdateLoginProfile",
          "iam:ListAccessKeys",
          "iam:DeleteAccessKey",
          "sts:GetCallerIdentity"
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
    MASTER_PASSWORD     = "StrongPassword123!"
  }
} 