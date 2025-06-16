output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.opensearch_vpc.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public_subnets[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private_subnets[*].id
}

output "opensearch_sg_id" {
  description = "ID of the OpenSearch security group"
  value       = aws_security_group.opensearch_sg.id
}

output "jump_server_sg_id" {
  description = "ID of the Jump Server security group"
  value       = aws_security_group.jump_server_sg.id
} 