output "jump_server_id" {
  description = "ID of the jump server"
  value       = aws_instance.jump_server.id
}

output "jump_server_public_ip" {
  description = "Public IP address of the jump server"
  value       = aws_eip.jump_server_eip.public_ip
}

output "jump_server_private_ip" {
  description = "Private IP address of the jump server"
  value       = aws_instance.jump_server.private_ip
} 