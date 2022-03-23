variable "region" {
  default     = "ap-southeast-2"
  description = "AWS region"
}

variable "db_password" {
  description = "RDS root user password"
  sensitive   = true
}
