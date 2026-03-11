terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

import {
  to = aws_instance.pickeat-sse
  id = "i-0facf3715fb773f02"
}
