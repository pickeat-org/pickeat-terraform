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

variable "private_app_subnet_cidrs" {
  description = "Private app subnet CIDR list"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "ssh_key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}

variable "web_ami_id" {
  description = "Nginx용 EC2 AMI ID"
  type        = string
  default = "ami-09ed9bca6a01cd74a"
}

variable "app_ami_id" {
  description = "Spring Boot용 EC2 AMI ID"
  type        = string
  default = "ami-09ed9bca6a01cd74a"
}

variable "web_instance_type" {
  description = "Web EC2 instance type"
  type        = string
  default     = "t4g.nano"
}

variable "app_instance_type" {
  description = "App EC2 instance type"
  type        = string
  default     = "t4g.small"
}

variable "web_http_port" {
  description = "Web HTTP port"
  type        = number
  default     = 80
}

variable "web_https_port" {
  description = "Web HTTPS port"
  type        = number
  default     = 443
}

variable "app_port" {
  description = "Spring Boot Application Port"
  type        = number
  default     = 80
}

variable "unique_suffix" {
  description = "S3 bucket 이름에 붙일 유니크 문자열"
  type        = string
  default     = "pickeatcheeze"
}
