# VPC / Subnet 정보
output "vpc_id" {
  description = "Dev VPC ID"
  value       = aws_vpc.main.id
}

output "public_app_subnet_id" {
  description = "Public App Subnet ID (dev)"
  value       = aws_subnet.public_app.id
}

output "private_db_subnet_id" {
  description = "Private DB Subnet ID (dev)"
  value       = aws_subnet.private_db.id
}

# Security Group 정보
output "app_security_group_id" {
  description = "App Security Group ID (dev)"
  value       = aws_security_group.sg_app.id
}

output "db_security_group_id" {
  description = "DB Security Group ID (dev)"
  value       = aws_security_group.sg_db.id
}

# EC2 인스턴스 IP
output "app_public_ip" {
  description = "Public IP of the App instance (dev)"
  value       = aws_instance.app.public_ip
}

output "app_private_ip" {
  description = "Private IP of the App instance (dev)"
  value       = aws_instance.app.private_ip
}

output "db_private_ip" {
  description = "Private IP of the DB instance (dev)"
  value       = aws_instance.db.private_ip
}
