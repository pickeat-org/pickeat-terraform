# pickeat-terraform

pickeat 서비스의 AWS 인프라를 Terraform으로 관리하는 저장소입니다.
`dev`, `prod` 두 개의 환경을 각각 독립적으로 프로비저닝합니다.

---

## 1. 사전 준비물

인프라를 배포하기 전에 로컬에 아래 도구와 설정이 준비되어 있어야 합니다.

| 항목 | 설명 |
| --- | --- |
| Terraform | `>= 1.2` (권장: 최신 안정 버전) |
| AWS CLI | AWS 자격 증명 설정을 위해 필요 |
| AWS 프로파일 | 이름은 반드시 `pickeat` 이어야 함 (코드에 하드코딩됨) |
| SSH Key Pair | 배포 리전(`ap-northeast-2`)에 미리 생성된 EC2 키페어 이름 필요 |

### AWS 프로파일 설정

모든 provider 설정이 `profile = "pickeat"` 를 사용합니다.
아래 명령으로 동일한 이름의 프로파일을 만들어 두어야 합니다.

```bash
aws configure --profile pickeat
# Access Key / Secret Key / region(ap-northeast-2) 입력
```

프로파일이 정상인지 확인:

```bash
aws sts get-caller-identity --profile pickeat
```

---

## 2. 전체 디렉토리 구조

```
pickeat-terraform/
├── environments/            # 실제 배포 단위 (환경별로 독립 실행)
│   ├── dev/                 # 개발 환경
│   │   ├── main.tf          # VPC, Subnet, SG, IAM, EC2 등 리소스 정의
│   │   ├── variables.tf     # 입력 변수 및 기본값
│   │   └── outputs.tf       # 배포 후 출력값 (IP, ID 등)
│   └── prod/                # 운영 환경
│       ├── main.tf          # dev 대비 web 계층 / NAT / S3 추가
│       ├── variables.tf
│       └── outputs.tf
│
└── modules/                 # 재사용 가능한 모듈 (building block)
    ├── network/             # VPC, Subnet, Route Table
    ├── security_group/      # 범용 보안 그룹
    ├── iam_ssm/             # EC2용 SSM IAM Role / Instance Profile
    ├── ec2_instance/       # EC2 인스턴스
    └── s3_static/          # S3 정적 호스팅 버킷
```

### 구조 설명

- **`environments/`가 실제 진입점입니다.** `terraform` 명령은 항상 `environments/dev` 또는 `environments/prod` 디렉토리 안에서 실행합니다.
- 현재 각 환경의 `main.tf`는 리소스를 **직접(inline)** 정의하고 있습니다.
- `modules/`는 향후 공통화를 위해 준비된 재사용 모듈 모음입니다. (현재 environments에서 아직 참조하지 않음)
- 환경별로 **state가 완전히 분리**되어 있어, `dev`를 변경해도 `prod`에는 영향을 주지 않습니다.

---

## 3. 환경별 아키텍처

### dev 환경 (`environments/dev`)

비용을 최소화한 단순 구성입니다. (NAT 게이트웨이 없음)

- VPC (`10.0.0.0/16`)
- Public App Subnet (`10.0.1.0/24`) — App 서버가 인터넷에 직접 노출
- Private DB Subnet (`10.0.3.0/24`) — 인터넷 라우트 없음
- Security Group
  - `sg-app`: 외부에서 `app_port(80)` 허용
  - `sg-db`: `sg-app`에서 오는 MySQL(`3306`)만 허용
- EC2: App 인스턴스(public), DB 인스턴스(private)
- 모든 EC2에 SSM 접속용 IAM Role 부착

### prod 환경 (`environments/prod`)

3계층(web / app / db) 구성에 NAT와 정적 호스팅이 추가됩니다.

- VPC (`10.0.0.0/16`)
- Public Subnet (`10.0.1.0/24`) + Private App Subnet (`10.0.2.0/24`)
- NAT Gateway (+ EIP) — private 서브넷의 아웃바운드 인터넷 제공
- Security Group
  - `sg-web`: 외부에서 HTTP(80) / HTTPS(443) 허용
  - `sg-app`: `sg-web`에서 오는 `app_port`만 허용
  - `sg-db`: `sg-app`에서 오는 MySQL(`3306`)만 허용
- EC2: Web(public), App(private), DB(private)
- S3 정적 호스팅 버킷 (public access 전면 차단)
- 모든 EC2에 SSM 접속용 IAM Role 부착

---

## 4. Terraform 사용 방법

> 모든 명령은 배포하려는 **환경 디렉토리 안에서** 실행합니다.
> 아래 예시는 `dev` 기준이며, `prod`도 디렉토리만 바꿔 동일하게 진행합니다.

### 4-1. 초기화 (최초 1회 / provider 변경 시)

```bash
cd environments/dev
terraform init
```

### 4-2. 포맷 & 검증 (선택이지만 권장)

```bash
terraform fmt      # 코드 스타일 정리
terraform validate # 문법 검증
```

### 4-3. 변경 사항 미리보기

```bash
terraform plan
```

`ssh_key_name`은 기본값이 없는 **필수 변수**이므로, plan/apply 시 값을 넘겨야 합니다.

```bash
terraform plan -var="ssh_key_name=<본인_키페어_이름>"
```

### 4-4. 배포

```bash
terraform apply -var="ssh_key_name=<본인_키페어_이름>"
# 출력된 계획 확인 후 'yes' 입력
```

배포가 끝나면 `outputs.tf`에 정의된 값(App/DB IP, VPC ID 등)이 출력됩니다.
다시 확인하려면:

```bash
terraform output
```

### 4-5. 리소스 삭제

```bash
terraform destroy -var="ssh_key_name=<본인_키페어_이름>"
```

---

## 5. 설정을 변경하고 싶을 때

설정 변경은 크게 세 가지 방식이 있으며, 상황에 맞게 선택합니다.

### 방법 A. 변수 값만 바꾸기 (가장 흔한 경우)

인스턴스 타입, 포트, 볼륨 크기, AMI 등 **값만** 바꾸고 싶다면 변수를 조정합니다.

1. 해당 환경의 `variables.tf`에서 `default` 값을 직접 수정하거나,
2. (권장) 코드를 건드리지 않고 실행 시 값을 넘깁니다.

```bash
# 명령줄에서 직접 지정
terraform apply \
  -var="ssh_key_name=my-key" \
  -var="app_instance_type=t4g.medium" \
  -var="root_volume_size=20"
```

반복적으로 같은 값을 쓴다면 `terraform.tfvars` 파일을 만들어 관리하는 것이 편합니다.

```hcl
# environments/dev/terraform.tfvars
ssh_key_name      = "my-key"
app_instance_type = "t4g.medium"
root_volume_size  = 20
```

이 파일은 `terraform`이 자동으로 읽으므로 `-var` 없이 `terraform apply`만 실행하면 됩니다.

주요 변경 가능한 변수 (환경에 따라 일부 상이):

| 변수 | 설명 | 예시 기본값 |
| --- | --- | --- |
| `ssh_key_name` | EC2 SSH 키페어 이름 (**필수**) | 없음 |
| `region` | 배포 리전 | `ap-northeast-2` |
| `vpc_cidr` | VPC 대역 | `10.0.0.0/16` |
| `app_instance_type` | App EC2 타입 | `t4g.small` |
| `db_instance_type` | DB EC2 타입 | `t4g.micro` |
| `app_port` / `db_port` | 서비스 / DB 포트 | `80` / `3306` |
| `root_volume_size` | 루트 EBS 크기(GB) | `10` |
| `app_ami_id` / `db_ami_id` | 사용할 AMI | `ami-09ed9bca6a01cd74a` |

### 방법 B. 리소스 구성 자체를 바꾸기

서브넷을 추가하거나, 보안 그룹 규칙을 바꾸거나, 새 리소스를 만드는 등
**구조를 변경**하려면 해당 환경의 `main.tf`를 직접 수정합니다.

예: dev 환경에 DB 포트 접근 규칙 추가 → `environments/dev/main.tf`의 `aws_security_group "sg_db"` 블록 수정.

### 방법 C. 출력값(outputs) 변경

배포 후 확인하고 싶은 값을 추가/삭제하려면 `outputs.tf`를 수정합니다.

### 변경 후 공통 절차

어떤 방법이든 변경 후에는 반드시 아래 순서를 따릅니다.

```bash
terraform fmt        # 1. 포맷 정리
terraform validate   # 2. 문법 검증
terraform plan       # 3. 변경 영향 확인 (무엇이 생성/수정/삭제되는지)
terraform apply      # 4. 실제 반영
```

**plan 결과를 반드시 먼저 확인**하세요. 특히 `destroy`/`replace`로 표시되는 리소스가 있으면
데이터 유실 위험이 있으므로 주의합니다.

---

## 6. 주의사항

- **state 파일은 현재 로컬에서 관리됩니다.** `terraform.tfstate`에는 민감 정보가 포함될 수 있으므로 Git에 커밋하지 않습니다. (`.gitignore`로 제외 처리됨)
- 여러 명이 협업하거나 안정적인 운영이 필요하면 **원격 백엔드(S3 + DynamoDB) 사용을 권장**합니다.
- AZ는 `ap-northeast-2a`로 하드코딩되어 있습니다. 다른 AZ가 필요하면 `main.tf`를 수정해야 합니다.
- provider 프로파일 이름(`pickeat`)이 코드에 고정되어 있으니, 로컬 AWS 프로파일 이름을 반드시 맞춰야 합니다.
