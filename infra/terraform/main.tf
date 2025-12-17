provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu_2204" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "certs" {
  bucket        = "demo-netflixoss-certs-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "certs" {
  bucket                  = aws_s3_bucket.certs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "ec2_role" {
  name = "demo-netflixoss-ec2-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_policy" {
  name = "demo-netflixoss-s3-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.certs.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.certs.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "demo-netflixoss-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "internal" {
  name        = "demo-netflixoss-internal-${random_id.suffix.hex}"
  description = "Internal microservices traffic + SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Config Server"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Eureka Server"
    from_port   = 8761
    to_port     = 8761
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Gateway"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "User BFF"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "Core Backend"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "mTLS Middleware"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "gateway_public" {
  name        = "demo-netflixoss-gateway-public-${random_id.suffix.hex}"
  description = "Public entrypoint (only 8080)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Gateway public"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  subnet_id = tolist(data.aws_subnets.default.ids)[0]
}

resource "aws_instance" "config" {
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  tags = { Name = "config-ec2" }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url              = var.repo_url
    git_branch            = var.git_branch
    service_name          = "config-server"
    service_module        = "services/config-server"
    service_port          = 8888
    config_server_url     = "http://127.0.0.1:8888"
    eureka_url            = "http://127.0.0.1:8761/eureka"
    certs_s3_bucket       = aws_s3_bucket.certs.bucket
    eureka_discovery_name = "eureka-ec2"
    middleware_host       = ""
    backend_host          = ""
    wait_for_urls         = ""
    wait_for_mtls_urls    = ""
  })
}

resource "aws_instance" "eureka" {
  depends_on             = [aws_instance.config]
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  tags = { Name = "eureka-ec2" }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url              = var.repo_url
    git_branch            = var.git_branch
    service_name          = "eureka-server"
    service_module        = "services/eureka-server"
    service_port          = 8761
    config_server_url     = "http://${aws_instance.config.private_ip}:8888"
    eureka_url            = "http://127.0.0.1:8761/eureka"
    certs_s3_bucket       = aws_s3_bucket.certs.bucket
    eureka_discovery_name = ""
    middleware_host       = ""
    backend_host          = ""
    wait_for_urls         = "http://${aws_instance.config.private_ip}:8888/actuator/health"
    wait_for_mtls_urls    = ""
  })
}

resource "aws_instance" "backend" {
  depends_on             = [aws_instance.eureka]
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  tags = { Name = "backend-ec2" }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url              = var.repo_url
    git_branch            = var.git_branch
    service_name          = "core-backend"
    service_module        = "services/core-backend"
    service_port          = 8082
    config_server_url     = "http://${aws_instance.config.private_ip}:8888"
    eureka_url            = "http://${aws_instance.eureka.private_ip}:8761/eureka"
    certs_s3_bucket       = aws_s3_bucket.certs.bucket
    eureka_discovery_name = ""
    middleware_host       = ""
    backend_host          = ""
    wait_for_urls         = "http://${aws_instance.config.private_ip}:8888/actuator/health http://${aws_instance.eureka.private_ip}:8761/actuator/health"
    wait_for_mtls_urls    = ""
  })
}

resource "aws_instance" "middleware" {
  depends_on             = [aws_instance.backend]
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  tags = { Name = "middleware-ec2" }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url              = var.repo_url
    git_branch            = var.git_branch
    service_name          = "mtls-middleware"
    service_module        = "services/mtls-middleware"
    service_port          = 8443
    config_server_url     = "http://${aws_instance.config.private_ip}:8888"
    eureka_url            = "http://${aws_instance.eureka.private_ip}:8761/eureka"
    certs_s3_bucket       = aws_s3_bucket.certs.bucket
    eureka_discovery_name = ""
    middleware_host       = ""
    backend_host          = aws_instance.backend.private_ip
    wait_for_urls         = "http://${aws_instance.config.private_ip}:8888/actuator/health http://${aws_instance.eureka.private_ip}:8761/actuator/health http://${aws_instance.backend.private_ip}:8082/actuator/health"
    wait_for_mtls_urls    = ""
  })
}

resource "aws_instance" "userbff" {
  depends_on             = [aws_instance.middleware]
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  tags = { Name = "userbff-ec2" }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url              = var.repo_url
    git_branch            = var.git_branch
    service_name          = "user-bff"
    service_module        = "services/user-bff"
    service_port          = 8081
    config_server_url     = "http://${aws_instance.config.private_ip}:8888"
    eureka_url            = "http://${aws_instance.eureka.private_ip}:8761/eureka"
    certs_s3_bucket       = aws_s3_bucket.certs.bucket
    eureka_discovery_name = ""
    middleware_host       = aws_instance.middleware.private_ip
    backend_host          = ""
    wait_for_urls         = "http://${aws_instance.config.private_ip}:8888/actuator/health http://${aws_instance.eureka.private_ip}:8761/actuator/health"
    wait_for_mtls_urls    = "https://${aws_instance.middleware.private_ip}:8443/actuator/health"
  })
}

resource "aws_instance" "gateway" {
  depends_on             = [aws_instance.userbff]
  ami                    = data.aws_ami.ubuntu_2204.id
  instance_type          = "t3.medium"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.internal.id, aws_security_group.gateway_public.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name

  tags = { Name = "gateway-ec2" }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    repo_url              = var.repo_url
    git_branch            = var.git_branch
    service_name          = "cloud-gateway"
    service_module        = "services/cloud-gateway"
    service_port          = 8080
    config_server_url     = "http://${aws_instance.config.private_ip}:8888"
    eureka_url            = "http://${aws_instance.eureka.private_ip}:8761/eureka"
    certs_s3_bucket       = aws_s3_bucket.certs.bucket
    eureka_discovery_name = ""
    middleware_host       = ""
    backend_host          = ""
    wait_for_urls         = "http://${aws_instance.config.private_ip}:8888/actuator/health http://${aws_instance.eureka.private_ip}:8761/actuator/health http://${aws_instance.userbff.private_ip}:8081/actuator/health"
    wait_for_mtls_urls    = ""
  })
}

resource "null_resource" "sanity" {
  depends_on = [aws_instance.gateway]

  triggers = {
    gateway_ip = aws_instance.gateway.public_ip
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-lc"]
    command     = "bash ../../scripts/sanity/run_sanity.sh --gateway-url http://${aws_instance.gateway.public_ip}:8080"
  }
}
