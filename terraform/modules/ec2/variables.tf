variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key name for EC2 instance"
  type        = string
  default     = "opensearch-jump-server-key"
}

variable "subnet_id" {
  description = "Subnet ID for the jump server"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for the jump server"
  type        = string
} 