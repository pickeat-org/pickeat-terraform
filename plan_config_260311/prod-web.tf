# __generated__ by Terraform
# Please review these resources and move them into your main configuration files.

# __generated__ by Terraform
resource "aws_instance" "pickeat_prod_web" {
  ami                                  = "ami-09ed9bca6a01cd74a"
  associate_public_ip_address          = true
  availability_zone                    = "ap-northeast-2a"
  disable_api_stop                     = false
  disable_api_termination              = false
  ebs_optimized                        = true
  get_password_data                    = false
  hibernation                          = false
  iam_instance_profile                 = "pickeat-prod-ec2-ssm-profile"
  instance_initiated_shutdown_behavior = "stop"
  instance_type                        = "t4g.nano"
  ipv6_addresses                       = []
  key_name                             = "pickeat-prod-v2"
  monitoring                           = false
  placement_partition_number           = 0
  private_ip                           = "10.0.1.72"
  secondary_private_ips                = []
  security_groups                      = []
  source_dest_check                    = true
  subnet_id                            = "subnet-077294aaaaca026d2"
  tags = {
    Env  = "prod"
    Name = "pickeat-prod-web"
    Role = "web"
  }
  tags_all = {
    Env  = "prod"
    Name = "pickeat-prod-web"
    Role = "web"
  }
  tenancy                     = "default"
  user_data_replace_on_change = null
  volume_tags                 = null
  vpc_security_group_ids      = ["sg-00c8e308a6e6ae0cc"]
  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }
  cpu_options {
    core_count       = 2
    threads_per_core = 1
  }
  credit_specification {
    cpu_credits = "unlimited"
  }
  enclave_options {
    enabled = false
  }
  maintenance_options {
    auto_recovery = "default"
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "disabled"
  }
  private_dns_name_options {
    enable_resource_name_dns_a_record    = false
    enable_resource_name_dns_aaaa_record = false
    hostname_type                        = "ip-name"
  }
  root_block_device {
    delete_on_termination = true
    encrypted             = false
    iops                  = 3000
    tags                  = {}
    tags_all              = {}
    throughput            = 125
    volume_size           = 10
    volume_type           = "gp3"
  }
}
