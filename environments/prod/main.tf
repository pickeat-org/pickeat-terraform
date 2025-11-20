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
  region  = var.region
  profile = "pickeat"
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
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-1a"
    Env  = var.environment
  }
}

resource "aws_subnet" "private_app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[0]
  availability_zone = "ap-northeast-2a"

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

  # 같은 sg_web에 속한 인스턴스끼리 모든 트래픽 허용
  ingress {
    description = "Web SG self traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-web"
    Env  = var.environment
  }
}

resource "aws_security_group" "sg_app" {
  name        = "${var.project_name}-sg-app"
  description = "Allow app traffic from web server"
  vpc_id      = aws_vpc.main.id

  # web SG → app SG (app_port)
  ingress {
    description     = "Allow Web to App"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_web.id]
  }

  # 같은 sg_app에 속한 인스턴스끼리 모든 트래픽 허용
  ingress {
    description = "App SG self traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-app"
    Env  = var.environment
  }
}

resource "aws_security_group" "sg_db" {
  name        = "${var.project_name}-sg-db"
  description = "Allow MySQL from app server"
  vpc_id      = aws_vpc.main.id

  # app SG → db SG (MySQL 포트)
  ingress {
    description     = "MySQL from app"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_app.id]
  }

  # 같은 sg_db에 속한 인스턴스끼리 모든 트래픽 허용
  ingress {
    description = "DB SG self traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-db"
    Env  = var.environment
  }
}

########################
# SSM IAM Role / Instance Profile
########################

resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-${var.environment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2-ssm-role"
    Env  = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "${var.project_name}-${var.environment}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

########################
# EC2 Instances (each 10GB root)
########################

resource "aws_instance" "web" {
  ami                    = var.web_ami_id
  instance_type          = var.web_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg_web.id]
  key_name               = var.ssh_key_name

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-web"
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

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app"
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

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-db"
    Role = "db"
    Env  = var.environment
  }
}

########################
# S3 Static Hosting
########################

resource "aws_s3_bucket" "static" {
  bucket = "${var.project_name}-${var.environment}-${var.unique_suffix}"

  tags = {
    Name = "${var.project_name}-static"
    Env  = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
