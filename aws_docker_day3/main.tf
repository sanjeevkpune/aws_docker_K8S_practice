# 1. VPC and Subnet Setup (including IGW, NAT GW, and Route Tables)
module "vpc" {
  source           = "./modules/vpc"
  project_name     = var.project_name
  vpc_cidr         = "10.10.0.0/16"
  public_subnets   = ["10.10.1.0/24", "10.10.3.0/24"]
  private_subnets  = ["10.10.2.0/24", "10.10.4.0/24"]
  availability_zones = ["ap-south-1a", "ap-south-1b"]
}

# 2. IAM Role for EC2 Instances
module "iam" {
  source       = "./modules/iam"
  project_name = var.project_name
}

# 3. Application Setup (Security Groups, Launch Template, ALB, ASG, Route 53)
module "app" {
  source                 = "./modules/app"
  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  private_subnet_ids     = module.vpc.private_subnet_ids
  instance_profile_name  = module.iam.instance_profile_name
  ami_id                 = var.ami_id
  hosted_zone_name       = var.hosted_zone_name
}