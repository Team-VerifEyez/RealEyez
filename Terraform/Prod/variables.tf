variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "dockerhub_username" {
  description = "Docker hub username"
  type        = string
}

variable "dockerhub_password" {
  description = "Docker hub password"
  type        = string
  sensitive = true
}