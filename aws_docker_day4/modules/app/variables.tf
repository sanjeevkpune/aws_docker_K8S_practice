variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "instance_profile_name" { type = string }
variable "ami_id" { type = string }
variable "hosted_zone_name" { type = string }
variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS listeners."
  type        = string
}