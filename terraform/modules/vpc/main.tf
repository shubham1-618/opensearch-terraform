resource "aws_vpc" "opensearch_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev-opensearch-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = 3
  vpc_id            = aws_vpc.opensearch_vpc.id
  cidr_block        = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"][count.index]
  availability_zone = ["us-east-2a", "us-east-2b", "us-east-2c"][count.index]

  tags = {
    Name = "dev-opensearch-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = 3
  vpc_id            = aws_vpc.opensearch_vpc.id
  cidr_block        = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"][count.index]
  availability_zone = ["us-east-2a", "us-east-2b", "us-east-2c"][count.index]

  tags = {
    Name = "dev-opensearch-private-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.opensearch_vpc.id

  tags = {
    Name = "dev-opensearch-igw"
  }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "dev-opensearch-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "dev-opensearch-nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.opensearch_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "dev-opensearch-public-rt"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.opensearch_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "dev-opensearch-private-rt"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = 3
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = 3
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

# Security Groups
resource "aws_security_group" "opensearch_sg" {
  name        = "dev-opensearch-sg"
  description = "Security group for OpenSearch cluster"
  vpc_id      = aws_vpc.opensearch_vpc.id

  ingress {
    description     = "HTTPS from Jump Server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_server_sg.id]
  }

  # Self-reference ingress rule to allow Lambda functions using this same security group
  ingress {
    description = "HTTPS from Lambda functions"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true  # Allow traffic from resources using this same security group
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-opensearch-sg"
  }
}

resource "aws_security_group" "jump_server_sg" {
  name        = "dev-jump-server-sg"
  description = "Security group for Jump Server"
  vpc_id      = aws_vpc.opensearch_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dev-jump-server-sg"
  }
} 