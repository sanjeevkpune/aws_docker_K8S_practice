## 1. VPC and Subnet Setup

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-VPC"
  }
}

# Create Internet Gateway and attach to VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-IGW"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Enabled for Public subnets

  tags = {
    Name = "${var.project_name}-Public-${count.index == 0 ? "A" : "B"}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-Private-${count.index == 0 ? "A" : "B"}"
  }
}

# Public Route Table and Route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-Public-RT"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

## 2. NAT Gateway Setup

# Allocate Elastic IP (EIP) for NAT Gateway (in Public-A Subnet)
resource "aws_eip" "nat_gw_eip" {
  # The 'vpc = true' argument is deprecated and should be removed. 
  # EIPs are automatically scoped to VPCs in modern AWS regions.
  # vpc = true

  tags = {
    Name = "${var.project_name}-NAT-GW-EIP"
  }
}

# Create NAT Gateway in Public-A subnet (index 0)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = aws_subnet.public[0].id # Public-A Subnet

  tags = {
    Name = "${var.project_name}-NAT-GW"
  }

  depends_on = [aws_internet_gateway.main]
}

# Private Route Table and Route to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-Private-RT"
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}