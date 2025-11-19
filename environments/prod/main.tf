terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12"
    }
  }
  required_version = ">=1.2"
}

provider "aws" {
  region = var.region
  profile = "pickeat-prod"
}

########################
# VPC & Subnet
########################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
    Env  = var.environment
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
    Env  = var.environment
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1a"
    Env  = var.environment
  }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[0]
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "${var.project_name}-private-app-1a"
    Env  = var.environment
  }
}

########################
# Route Tables & NAT
########################

resource "aws_eip" "nat_eip" {
  tags = {
    Name = "${var.project_name}-nat-eip"
    Env  = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_name}-nat"
    Env  = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
    Env  = var.environment
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
    Env  = var.environment
  }
}

resource "aws_route_table_association" "private_app_assoc" {
  subnet_id      = aws_subnet.private_app.id
  route_table_id = aws_route_table.private.id
}

########################
# Security Groups
########################

resource "aws_security_group" "sg_web" {
  name        = "${var.project_name}-sg-web"
  description = "Allow HTTP/HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = var.web_http_port
    to_port     = var.web_http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = var.web_https_port
    to_port     = var.web_https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_app" {
  name        = "${var.project_name}-sg-app"
  description = "Allow app traffic from web server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow Web → App"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_db" {
  name        = "${var.project_name}-sg-db"
  description = "Allow MySQL from app server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from app"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################
# EC2 Instances (each 10GB root)
########################

locals {
  root_volume = [{
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }]
}

resource "aws_instance" "web" {
  ami                    = var.web_ami_id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg_web.id]
  key_name               = var.ssh_key_name

  root_block_device = local.root_volume

  tags = {
    Name = "${var.project_name}-web"
    Role = "web"
    Env  = var.environment
  }
}

resource "aws_instance" "app" {
  ami                    = var.app_ami_id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.private_app.id
  vpc_security_group_ids = [aws_security_group.sg_app.id]
  key_name               = var.ssh_key_name

  root_block_device = local.root_volume

  tags = {
    Name = "${var.project_name}-app"
    Role = "app"
    Env  = var.environment
  }
}

resource "aws_instance" "db" {
  ami                    = var.db_ami_id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private_app.id
  vpc_security_group_ids = [aws_security_group.sg_db.id]
  key_name               = var.ssh_key_name

  root_block_device = local.root_volume

  tags = {
    Name = "${var.project_name}-db"
    Role = "db"
    Env  = var.environment
  }
}

########################
# S3 Static Hosting
########################

resource "aws_s3_bucket" "static" {
  bucket = "${var.project_name}-${var.environment}-${var.unique_suffix}"
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
