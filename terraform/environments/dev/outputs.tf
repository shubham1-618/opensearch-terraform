output "opensearch_endpoint" {
  description = "OpenSearch domain endpoint"
  value       = module.opensearch.opensearch_endpoint
}

output "opensearch_dashboard_endpoint" {
  description = "OpenSearch dashboard endpoint"
  value       = module.opensearch.opensearch_dashboard_endpoint
}

output "jump_server_public_ip" {
  description = "Public IP address of the jump server"
  value       = module.jump_server.jump_server_public_ip
}

output "snapshot_bucket_name" {
  description = "Name of the S3 bucket for snapshots"
  value       = module.opensearch.snapshot_bucket_name
}

output "snapshot_lambda_function_name" {
  description = "Name of the snapshot Lambda function"
  value       = module.snapshot_lambda.lambda_function_name
}

output "iam_mapper_lambda_function_name" {
  description = "Name of the IAM user mapper Lambda function"
  value       = module.iam_mapper_lambda.lambda_function_name
}

output "ssh_tunnel_command" {
  description = "Command to establish SSH tunnel to the OpenSearch dashboard"
  value       = "ssh -i ${var.key_name}.pem -L 9200:${module.opensearch.opensearch_endpoint}:443 ec2-user@${module.jump_server.jump_server_public_ip}"
} 