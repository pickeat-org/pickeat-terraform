output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_id" {
  value       = aws_subnet.public.id
  description = "Public subnet ID"
}

output "app_subnet_id" {
  value       = aws_subnet.private_app.id
  description = "App private subnet ID"
}

output "web_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP of the Web Server"
}

output "s3_static_bucket" {
  value       = aws_s3_bucket.static.bucket
  description = "Static asset bucket name"
}

output "app_private_ip" {
  value       = aws_instance.app.private_ip
  description = "Private IP of the App Server"
}

output "db_private_ip" {
  value       = aws_instance.db.private_ip
  description = "Private IP of the DB Server (MySQL)"
}

output "db_security_group_id" {
  value       = aws_security_group.sg_db.id
  description = "Security Group ID of the DB Server"
}
