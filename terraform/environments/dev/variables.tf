variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

# EC2 Jump Server Variables
variable "jump_server_instance_type" {
  description = "Instance type for the jump server"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key name for the jump server"
  type        = string
  default     = "opensearch-jump-server-key"
}

# OpenSearch Variables
variable "domain_name" {
  description = "Name of the OpenSearch domain"
  type        = string
  default     = "dev-opensearch"
}

variable "engine_version" {
  description = "Version of OpenSearch"
  type        = string
  default     = "OpenSearch_2.5"
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
  default     = "t3.small"
}

variable "opensearch_instance_count" {
  description = "Number of data nodes in the OpenSearch cluster"
  type        = number
  default     = 3
}

variable "opensearch_volume_size" {
  description = "Size of EBS volume per node in GB"
  type        = number
  default     = 10
}

variable "master_user_name" {
  description = "Master user name for OpenSearch"
  type        = string
  default     = "admin"
}

variable "master_user_password" {
  description = "Master user password for OpenSearch"
  type        = string
  sensitive   = true
}

variable "create_snapshot" {
  description = "Whether to enable snapshot creation"
  type        = bool
  default     = true
} 