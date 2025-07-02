# Attempt to find the existing service-linked role
data "aws_iam_role" "opensearch_service_linked_role" {
  count = var.use_existing_service_linked_role ? 1 : 0
  name = "AWSServiceRoleForAmazonOpenSearchService"
}

# Create service-linked role for OpenSearch - only if it doesn't exist and we want to create it
resource "aws_iam_service_linked_role" "opensearch" {
  count = var.create_service_linked_role && !var.use_existing_service_linked_role ? 1 : 0
  aws_service_name = "opensearchservice.amazonaws.com"
  description      = "Service-linked role for OpenSearch to access VPC resources"
  
  # Ignore errors if the role already exists
  lifecycle {
    ignore_changes = [aws_service_name]
    create_before_destroy = true
  }
  
  # Custom error handling for role already exists case
  provisioner "local-exec" {
    on_failure = continue
    command = "echo 'Info: Service linked role may already exist, continuing...'"
  }
}

# Get current account ID
data "aws_caller_identity" "current" {}

# Use a local value with try() to handle the case when the role doesn't exist
locals {
  opensearch_service_linked_role_arn = var.use_existing_service_linked_role ? (
    try(data.aws_iam_role.opensearch_service_linked_role[0].arn, "")
  ) : (
    var.create_service_linked_role ? (
      try(aws_iam_service_linked_role.opensearch[0].arn, "")
    ) : ""
  )
  snapshot_bucket_name = var.create_snapshot ? aws_s3_bucket.snapshot_bucket[0].bucket : "no-snapshot-bucket"
  snapshot_bucket_arn = var.create_snapshot ? aws_s3_bucket.snapshot_bucket[0].arn : "no-snapshot-bucket-arn"
  snapshot_role_arn = var.create_snapshot ? aws_iam_role.opensearch_snapshot_role[0].arn : "no-snapshot-role"
}

# S3 bucket for snapshots - only if snapshots are enabled
resource "aws_s3_bucket" "snapshot_bucket" {
  count = var.create_snapshot ? 1 : 0
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
  count = var.create_snapshot ? 1 : 0
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
  count = var.create_snapshot ? 1 : 0
  name        = "${var.environment}-opensearch-snapshot-policy"
  description = "Policy for OpenSearch to create snapshots in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = [
          local.snapshot_bucket_arn
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
          "${local.snapshot_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "snapshot_policy_attachment" {
  count      = var.create_snapshot ? 1 : 0
  role       = aws_iam_role.opensearch_snapshot_role[0].name
  policy_arn = aws_iam_policy.opensearch_snapshot_policy[0].arn
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
      availability_zone_count = length(var.subnet_ids) >= 3 ? 3 : length(var.subnet_ids)
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
  
  # Use static depends_on, the service-linked role is already conditional via count
  depends_on = [aws_iam_service_linked_role.opensearch]
  
  # Error handling for domain creation
  timeouts {
    update = "2h"
    create = "2h"
    delete = "2h"
  }
  
  # Handle importing existing domains by ignoring certain attributes
  lifecycle {
    ignore_changes = [
      # Ignore changes to the advanced_security_options as they may be modified outside of Terraform
      advanced_security_options,
      # Ignore changes to tags
      tags,
      # Ignore changes to the access policies as they may be modified outside of Terraform
      access_policies
    ]
  }
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