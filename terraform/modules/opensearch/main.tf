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
  bucket = "${var.environment}-opensearch-snapshots-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "${var.environment}-opensearch-snapshots"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# IAM role for OpenSearch snapshot creation
resource "aws_iam_role" "opensearch_snapshot_role" {
  name = "${var.environment}-opensearch-snapshot-role"

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
  name        = "${var.environment}-opensearch-snapshot-policy"
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
  domain_name    = var.domain_name
  engine_version = var.engine_version

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    zone_awareness_enabled   = true
    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.volume_size
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.master_user_name
      master_user_password = var.master_user_password
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
      "Resource": "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.domain_name}/*"
    }
  ]
}
CONFIG

  snapshot_options {
    automated_snapshot_start_hour = 1
  }

  tags = {
    Name        = "${var.environment}-opensearch-domain"
    Environment = var.environment
  }
  
  # Wait for the service-linked role to be available
  depends_on = [aws_iam_service_linked_role.opensearch]
}

# Get current account ID
data "aws_caller_identity" "current" {}

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