environment = "dev"
region     = "us-east-2"

# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
azs                 = ["us-east-2a", "us-east-2b", "us-east-2c"]

# Jump Server Configuration
jump_server_instance_type = "t3.micro"
key_name                 = "opensearch-jump-server-key"

# OpenSearch Configuration
domain_name            = "dev-opensearch"
engine_version         = "OpenSearch_2.5"
opensearch_instance_type = "t3.small.search"
opensearch_instance_count = 3
opensearch_volume_size   = 10
create_snapshot        = true

# Credentials (override these in your local environment or CI/CD pipeline)
master_user_name     = "admin"
master_user_password = "ChangeMe123!" # Change this in production! 