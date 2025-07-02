output "opensearch_domain_id" {
  description = "ID of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch_domain.id
}

output "opensearch_domain_name" {
  description = "Name of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch_domain.domain_name
}

output "opensearch_endpoint" {
  description = "Endpoint of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch_domain.endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "Dashboard endpoint of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch_domain.dashboard_endpoint
}

output "opensearch_arn" {
  description = "ARN of the OpenSearch domain"
  value       = aws_opensearch_domain.opensearch_domain.arn
}

output "snapshot_bucket_name" {
  description = "Name of the S3 bucket for snapshots"
  value       = local.snapshot_bucket_name
}

output "snapshot_role_arn" {
  description = "ARN of the IAM role for OpenSearch snapshots"
  value       = local.snapshot_role_arn
} 