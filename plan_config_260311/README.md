# 2026-03-11 서버 이전 대비 서버 구성 기록

비용 문제로 서버 이전(축소) 대비 이전 운영 서버 등 전체 aws ec2 인프라 구성 정보 저장 목적

작성 환경
Terraform v1.14.6
on windows_amd64


terraform init
terraform plan -generate-config-out=generated.tf
