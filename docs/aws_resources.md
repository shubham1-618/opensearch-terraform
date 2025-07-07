# AWS Resources for OpenSearch Lambda Automation

This document outlines all the AWS resources required for the Lambda functions and S3 bucket in the lambda-manual branch.

## Overview of Required Resources

1. **S3 Bucket**
   - Used for storing OpenSearch snapshots
   - Accessible by OpenSearch domain

2. **IAM Roles**
   - OpenSearch Snapshot Role: Allows OpenSearch to write to S3 bucket
   - Lambda Execution Roles: One for each Lambda function

3. **Lambda Functions**
   - IAM User Mapper Lambda
   - Role Mapper Lambda
   - Snapshot Lambda

4. **CloudWatch Event Rule**
   - For triggering the snapshot Lambda on a schedule

## Resource Details

### S3 Bucket

```terraform
resource "aws_s3_bucket" "snapshot_bucket" {
  bucket = "dev-opensearch-snapshots-abcdef123456"
  
  tags = {
    Name        = "dev-opensearch-snapshots"
    Environment = "dev"
  }
}
```

### IAM Roles and Policies

#### OpenSearch Snapshot Role

```terraform
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
```

#### Lambda Execution Role (Snapshot Lambda)

```terraform
# IAM role for Lambda execution
resource "aws_iam_role" "snapshot_lambda_role" {
  name = "dev-opensearch-snapshot-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy for snapshot Lambda
resource "aws_iam_policy" "snapshot_lambda_policy" {
  name        = "dev-opensearch-snapshot-lambda-policy"
  description = "Policy for snapshot Lambda function"

  policy = jsonencode({
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
}
```

#### Lambda Execution Role (IAM User Mapper Lambda)

```terraform
resource "aws_iam_policy" "iam_mapper_lambda_policy" {
  name        = "dev-opensearch-iam-user-mapper-policy"
  description = "Policy for IAM user mapper Lambda function"

  policy = jsonencode({
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
}
```

#### Lambda Execution Role (Role Mapper Lambda)

```terraform
resource "aws_iam_policy" "role_mapper_lambda_policy" {
  name        = "dev-opensearch-role-mapper-policy"
  description = "Policy for role mapper Lambda function"

  policy = jsonencode({
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
}
```

### Lambda Functions

For all Lambda functions, the following resources are created:

1. Lambda function resource
2. IAM execution role
3. IAM policies for permissions
4. CloudWatch event trigger (for snapshot Lambda only)

Example for the Snapshot Lambda:

```terraform
resource "aws_lambda_function" "snapshot_lambda" {
  function_name    = "dev-opensearch-snapshot-lambda"
  role             = aws_iam_role.snapshot_lambda_role.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  filename         = "snapshot_lambda.zip"  # ZIP package with all dependencies
  timeout          = 300
  memory_size      = 256
  
  environment {
    variables = {
      OPENSEARCH_ENDPOINT = "search-dev-opensearch-abcdef1234567890.us-east-2.es.amazonaws.com"
      BUCKET_NAME         = aws_s3_bucket.snapshot_bucket.id
      REGION              = "us-east-2"
      ROLE_ARN            = aws_iam_role.opensearch_snapshot_role.arn
    }
  }
}
```

### CloudWatch Event Rule for Snapshot Schedule

```terraform
resource "aws_cloudwatch_event_rule" "snapshot_schedule" {
  name                = "dev-opensearch-snapshot-schedule"
  description         = "Schedule for OpenSearch snapshot Lambda function"
  schedule_expression = "cron(0 * * * ? *)"  # Every hour
}

resource "aws_cloudwatch_event_target" "snapshot_target" {
  rule      = aws_cloudwatch_event_rule.snapshot_schedule.name
  target_id = "dev-opensearch-snapshot-lambda"
  arn       = aws_lambda_function.snapshot_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.snapshot_schedule.arn
}
```

## Relationship Between Resources

1. **S3 Bucket**
   - Used by the snapshot Lambda function to store snapshots
   - Accessed by OpenSearch domain via the snapshot IAM role

2. **OpenSearch Snapshot Role**
   - Allows the OpenSearch domain to write to the S3 bucket
   - Referenced by snapshot Lambda function in environment variables

3. **Lambda Functions**
   - Each function has its own execution role with specific permissions
   - The snapshot Lambda is triggered hourly by CloudWatch Events
   - IAM user mapper and role mapper are triggered manually or via API

## Implementation Considerations

1. **Security**
   - Each Lambda has the minimal permissions required
   - OpenSearch snapshot role is scoped to only the specific S3 bucket

2. **Scheduling**
   - Snapshot Lambda runs every hour automatically
   - Other Lambda functions are invoked on-demand

3. **Configuration**
   - All domain-specific values are set in environment variables
   - Update the OpenSearch endpoint, region, username, and password as needed 