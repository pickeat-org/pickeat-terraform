variable "project_name" {
  description = "프로젝트 공통 prefix"
  type        = string
  default     = "pickeat"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "환경 구분 (예: dev, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR list"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Private DB subnet CIDR list (dev 전용)"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}

variable "ssh_key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "app_ami_id" {
  description = "Spring Boot용 EC2 AMI ID"
  type        = string
  default     = "ami-09ed9bca6a01cd74a"
}

variable "app_instance_type" {
  description = "App EC2 instance type"
  type        = string
  default     = "t4g.small"
}

variable "app_port" {
  description = "Spring Boot Application Port"
  type        = number
  default     = 80
}

variable "db_ami_id" {
  description = "MySQL용 EC2 AMI ID"
  type        = string
  default     = "ami-09ed9bca6a01cd74a"
}

variable "db_instance_type" {
  description = "DB EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "db_port" {
  description = "MySQL Port"
  type        = number
  default     = 3306
}

variable "root_volume_size" {
  description = "Root EBS Volume size for EC2 instances (in GB)"
  type        = number
  default     = 10
}
