# Defines the AWS region where the ECR will be created
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1" 
}

# Defines the name for the new ECR repository
variable "repository_name" {
  description = "The name for the ECR repository"
  type        = string
  default     = "my-private-app-repo"
}