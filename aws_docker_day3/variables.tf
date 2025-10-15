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