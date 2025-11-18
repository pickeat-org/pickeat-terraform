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

