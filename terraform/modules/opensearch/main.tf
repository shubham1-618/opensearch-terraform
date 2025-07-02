# Create service-linked role for OpenSearch
resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "opensearchservice.amazonaws.com"
  description      = "Service-linked role for OpenSearch to access VPC resources"
  count = 0  # Don't try to create the role since it already exists
}

# Reference existing service-linked role
data "aws_iam_role" "opensearch_service_linked_role" {
  name = "AWSServiceRoleForAmazonOpenSearchService"
}

# S3 bucket for snapshots
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

# OpenSearch domain
resource "aws_opensearch_domain" "opensearch_domain" {
  domain_name    = "dev-opensearch"
  engine_version = "OpenSearch_2.5"

  cluster_config {
    instance_type            = "t3.small"
    instance_count           = 3
    zone_awareness_enabled   = true
    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  vpc_options {
    subnet_ids         = ["subnet-0123456789abcdef1", "subnet-0123456789abcdef2", "subnet-0123456789abcdef3"]
    security_group_ids = ["sg-0123456789abcdef0"]
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "admin"
      master_user_password = "StrongPassword123!"
    }
  }
  
  node_to_node_encryption {
    enabled = true
  }
  
  encrypt_at_rest {
    enabled = true
  }
  
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:us-east-2:123456789012:domain/dev-opensearch/*"
    }
  ]
}
CONFIG

  snapshot_options {
    automated_snapshot_start_hour = 1
  }

  tags = {
    Name        = "dev-opensearch-domain"
    Environment = "dev"
  }
  
  # Wait for the service-linked role to be available
  depends_on = [aws_iam_service_linked_role.opensearch]
}

# Create fine-grained access control
resource "aws_opensearch_domain_policy" "main" {
  domain_name = aws_opensearch_domain.opensearch_domain.domain_name
  
  access_policies = <<POLICIES
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Resource": "${aws_opensearch_domain.opensearch_domain.arn}/*"
    }
  ]
}
POLICIES
} 