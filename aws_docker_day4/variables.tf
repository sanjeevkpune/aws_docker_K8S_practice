variable "project_name" {
  description = "A concise name for the project to be used in resource tagging."
  type        = string
  default     = "GymAppDeployment"
}

variable "hosted_zone_name" {
  description = "The domain name of the Route 53 Hosted Zone."
  type        = string
  default     = "devops-practice.click"
}

# Dummy value for AMI - REPLACE with a valid Ubuntu 22.04 LTS AMI ID for ap-south-1
variable "ami_id" {
  description = "The AMI ID for the EC2 instances (Ubuntu 22.04 LTS recommended)."
  type        = string
  default     = "ami-02d26659fd82cf299" # Example ID, replace with current one
}

variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS listeners."
  type        = string
  # Construct the ARN using the provided ID and the Mumbai region (ap-south-1)
  default     = "arn:aws:acm:ap-south-1:691249426747:certificate/c01e79e1-8b86-4591-91ad-3708fb58c175" 
  # NOTE: Replace '123456789012' with your actual AWS Account ID.
}