variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "domain_name" {
  description = "Name of the OpenSearch domain"
  type        = string
  default     = "opensearch-domain"
}

variable "engine_version" {
  description = "Version of OpenSearch"
  type        = string
  default     = "OpenSearch_2.5"
}

variable "instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
  default     = "t3.small.search"
}

variable "instance_count" {
  description = "Number of data nodes in the OpenSearch cluster"
  type        = number
  default     = 3
}

variable "volume_size" {
  description = "Size of EBS volume per node in GB"
  type        = number
  default     = 10
}

variable "subnet_ids" {
  description = "Subnet IDs for OpenSearch domain"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for OpenSearch domain"
  type        = string
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