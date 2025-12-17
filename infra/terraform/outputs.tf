output "gateway_public_url" {
  value       = "http://${aws_instance.gateway.public_ip}:8080"
  description = "Public entrypoint URL (Cloud Gateway)"
}

output "certs_bucket" {
  value       = aws_s3_bucket.certs.bucket
  description = "S3 bucket used to distribute mTLS cert artifacts"
}

