# Fetch latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create the jump server instance
resource "aws_instance" "jump_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y curl jq
    
    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    yum install -y unzip
    unzip awscliv2.zip
    ./aws/install
  EOF

  tags = {
    Name = "${var.environment}-opensearch-jump-server"
  }
}

# Allocate Elastic IP
resource "aws_eip" "jump_server_eip" {
  domain = "vpc"
  instance = aws_instance.jump_server.id

  tags = {
    Name = "${var.environment}-opensearch-jump-server-eip"
  }
} 