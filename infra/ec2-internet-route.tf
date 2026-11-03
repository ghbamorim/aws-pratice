
# Use the existing default VPC
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Dedicated public subnet for the application EC2
resource "aws_subnet" "ec2_public" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.240.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name      = "aws-pratice-ec2-public"
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Public route table
resource "aws_route_table" "ec2_public" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default.id
  }

  tags = {
    Name      = "aws-pratice-ec2-public"
    Project   = "aws-pratice"
    ManagedBy = "Terraform"
  }
}

# Associate only the dedicated EC2 subnet
resource "aws_route_table_association" "ec2_public" {
  subnet_id      = aws_subnet.ec2_public.id
  route_table_id = aws_route_table.ec2_public.id
}
