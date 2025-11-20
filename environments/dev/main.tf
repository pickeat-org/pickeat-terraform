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
# VPC & Subnets (dev 전용)
########################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
    Env  = var.environment
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
    Env  = var.environment
  }
}

# public app subnet (app 서버가 직접 인터넷에 노출되는 서브넷)
resource "aws_subnet" "public_app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-app-1a"
    Env  = var.environment
  }
}

# private db subnet (DB 전용, 인터넷 라우트 없음)
resource "aws_subnet" "private_db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[0]
  availability_zone = "ap-northeast-2a"

  tags = {
    Name = "${var.project_name}-${var.environment}-private-db-1a"
    Env  = var.environment
  }
}

########################
# Route Tables (NAT 없음)
########################

# public 서브넷: IGW 통해 0.0.0.0/0
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
    Env  = var.environment
  }
}

resource "aws_route_table_association" "public_app_assoc" {
  subnet_id      = aws_subnet.public_app.id
  route_table_id = aws_route_table.public.id
}

# private db 서브넷은 VPC 기본 route table만 사용 (local 트래픽만 허용, 인터넷 없음)

########################
# Security Groups (dev 전용)
########################

# app: 외부에서 app_port 허용
resource "aws_security_group" "sg_app" {
  name        = "${var.project_name}-${var.environment}-sg-app"
  description = "Allow app port from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "App Port"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 필요시 SSH 오픈 (dev 환경에서만, 특정 IP로 제한 권장)
  # ingress {
  #   description = "SSH"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["당신IP/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-app"
    Env  = var.environment
  }
}

# db: app SG에서만 MySQL 허용
resource "aws_security_group" "sg_db" {
  name        = "${var.project_name}-${var.environment}-sg-db"
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

  tags = {
    Name = "${var.project_name}-${var.environment}-sg-db"
    Env  = var.environment
  }
}

########################
# SSM용 IAM Role / Instance Profile
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
# EC2 Instances (10GB root)
########################

# public app 인스턴스
resource "aws_instance" "app" {
  ami                    = var.app_ami_id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public_app.id
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

# private db 인스턴스
resource "aws_instance" "db" {
  ami                    = var.db_ami_id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.private_db.id
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
