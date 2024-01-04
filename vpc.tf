# Main VPC
resource "aws_vpc" "eks_main" {
  cidr_block           = local.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-vpc"
  }
}

# Public Subnet
resource "aws_subnet" "eks_public_subnet" {
  # 10.14.0.0/16 -> [10.14.0.0/20, 10.14.16.0/20, 10.14.32.0/20]
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.eks_main.id
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(aws_vpc.eks_main.cidr_block, 4, count.index)

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-public-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Public Route Table
resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_main.id

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-public-route-table"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_main.id

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-internet-gateway"
  }
}

# Public Routes
resource "aws_route" "eks_public_internet_access" {
  route_table_id         = aws_route_table.eks_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks_igw.id
  depends_on             = [aws_route_table.eks_public_rt]
}

# Public Subnet Route Associations
resource "aws_route_table_association" "eks_public_rta" {
  count          = local.public_subnet_count
  subnet_id      = element(aws_subnet.eks_public_subnet.*.id, count.index)
  route_table_id = aws_route_table.eks_public_rt.id
}

# Private Subnet
resource "aws_subnet" "eks_private_subnet" {
  # 10.14.0.0/16 -> [10.14.48.0/20, 10.14.64.0/20, 10.14.80.0/20]
  count             = local.private_subnet_count
  vpc_id            = aws_vpc.eks_main.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.eks_main.cidr_block, 4, count.index + local.public_subnet_count)

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-private-${data.aws_availability_zones.available.names[count.index]}"
  }
}

# Private Route Table
resource "aws_route_table" "eks_private_rt" {
  vpc_id = aws_vpc.eks_main.id

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-private-route-table"
  }
}

# The NAT Elastic IP
resource "aws_eip" "eks_nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-nat-eip"
  }
}

# The NAT Gateway
resource "aws_nat_gateway" "eks_nat" {
  allocation_id = aws_eip.eks_nat_eip.id
  subnet_id     = aws_subnet.eks_public_subnet.0.id

  tags = {
    Name = "${var.default_tags.Project}-${var.default_tags.Environment}-nat"
  }

  depends_on = [aws_eip.eks_nat_eip, aws_internet_gateway.eks_igw]
}

# Private Routes
resource "aws_route" "eks_private_internet_access" {
  route_table_id         = aws_route_table.eks_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.eks_nat.id
  depends_on             = [aws_route_table.eks_private_rt]
}

# Private Subnet Route Associations
resource "aws_route_table_association" "eks_private_rta" {
  count          = local.private_subnet_count
  subnet_id      = element(aws_subnet.eks_private_subnet.*.id, count.index)
  route_table_id = aws_route_table.eks_private_rt.id
}
