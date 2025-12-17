variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "admin_cidr" {
  type        = string
  description = "Your public IP CIDR for SSH, e.g. 203.0.113.10/32"
}

variable "key_name" {
  type        = string
  description = "Optional EC2 key pair name for SSH access"
  default     = null
}

variable "repo_url" {
  type        = string
  description = "Git clone URL for this repository (must be reachable from EC2)"
}

variable "git_branch" {
  type        = string
  description = "Git branch to clone"
  default     = "main"
}

