### Here we will create terraform templates to generate the infra as setup on Day1
--------------------
This complete Terraform configuration is structured into **modules** following industry best practices. It includes a **root directory** and separate modules for **VPC**, **IAM**, and **Application (Load Balancer, EC2, ASG)**.

The setup assumes you have a **Route 53 Hosted Zone** named `devops-practice.click` already created.

### Directory Structure

```
.
├── modules
│   ├── app
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── iam
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   └── vpc
│       ├── main.tf
│       ├── outputs.tf
│       └── variables.tf
├── main.tf
├── providers.tf
└── variables.tf
```

-----
*** Command to create above directory structure
    `mkdir -p modules/{vpc,iam,app} && \
    touch main.tf providers.tf variables.tf && \
    touch modules/vpc/{main.tf,outputs.tf,variables.tf} && \
    touch modules/iam/{main.tf,outputs.tf,variables.tf} && \
    touch modules/app/{main.tf,outputs.tf,variables.tf,user_data.sh}`
### Global Files

These files configure the provider and link the modules.

#### `providers.tf`

```terraform
# Configure the AWS Provider for the Mumbai region
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Mumbai region
}
```

#### `variables.tf` (Root)

```terraform
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
  default     = "aami-02d26659fd82cf299" # Example ID, replace with current one
}
```

#### `main.tf` (Root)

```terraform
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
```

-----

### Modules

#### 1\. VPC Module (`modules/vpc`)

##### `modules/vpc/variables.tf`

```terraform
variable "project_name" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "availability_zones" { type = list(string) }
```

##### `modules/vpc/main.tf` (VPC, IGW, Subnets, NAT GW, Route Tables)

```terraform
## 1. VPC and Subnet Setup

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-VPC"
  }
}

# Create Internet Gateway and attach to VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-IGW"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Enabled for Public subnets

  tags = {
    Name = "${var.project_name}-Public-${count.index == 0 ? "A" : "B"}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-Private-${count.index == 0 ? "A" : "B"}"
  }
}

# Public Route Table and Route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-Public-RT"
  }
}

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

## 2. NAT Gateway Setup

# Allocate Elastic IP (EIP) for NAT Gateway (in Public-A Subnet)
resource "aws_eip" "nat_gw_eip" {
  vpc = true

  tags = {
    Name = "${var.project_name}-NAT-GW-EIP"
  }
}

# Create NAT Gateway in Public-A subnet (index 0)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = aws_subnet.public[0].id # Public-A Subnet

  tags = {
    Name = "${var.project_name}-NAT-GW"
  }

  depends_on = [aws_internet_gateway.main]
}

# Private Route Table and Route to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-Private-RT"
  }
}

# Associate Private Route Table with Private Subnets
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

##### `modules/vpc/outputs.tf`

```terraform
output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of Public Subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of Private Subnet IDs."
  value       = aws_subnet.private[*].id
}
```

-----

#### 2\. IAM Module (`modules/iam`)

##### `modules/iam/variables.tf`

```terraform
variable "project_name" { type = string }
```

##### `modules/iam/main.tf` (IAM Policy and Role)

```terraform
## 3. IAM Role for EC2 Instances

# IAM Policy Document for S3 Read Access
data "aws_iam_policy_document" "s3_read_policy_doc" {
  statement {
    sid    = "S3GetObject"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["arn:aws:s3:::my-bucket-docker-site/gym-app/*"]
  }

  statement {
    sid    = "S3ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::my-bucket-docker-site"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["gym-app/*"]
    }
  }
}

# Create Custom IAM Policy (EC2-SSM-S3-Policy)
resource "aws_iam_policy" "ec2_s3_ssm_policy" {
  name        = "${var.project_name}-EC2-SSM-S3-Policy"
  description = "Policy for EC2 with S3 read and SSM access."
  policy      = data.aws_iam_policy_document.s3_read_policy_doc.json
}

# IAM Role Assume Role Policy Document
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    effect = "Allow"
  }
}

# Create IAM Role (EC2-SSM-S3-Role)
resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-EC2-SSM-S3-Role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Attach AWS Managed Policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_managed_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach Custom S3/SSM Policy
resource "aws_iam_role_policy_attachment" "custom_policy_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_s3_ssm_policy.arn
}

# Create Instance Profile
resource "aws_iam_instance_profile" "main" {
  name = "${var.project_name}-EC2-SSM-S3-Profile"
  role = aws_iam_role.ec2_role.name
}
```

##### `modules/iam/outputs.tf`

```terraform
output "instance_profile_name" {
  description = "The name of the IAM Instance Profile."
  value       = aws_iam_instance_profile.main.name
}
```

-----

#### 3\. Application Module (`modules/app`)

##### `modules/app/variables.tf`

```terraform
variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "instance_profile_name" { type = string }
variable "ami_id" { type = string }
variable "hosted_zone_name" { type = string }
```

##### `modules/app/main.tf` (SG, LT, ALB, ASG, Route 53)

```terraform
# Base64 encode the User Data script
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh") # User Data script in a separate file
}

## 7. Security Group Finalization (Order of creation for dependency)

# ALB Security Group (ALB-SG)
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-ALB-SG"
  description = "Allows HTTP traffic from the internet to the ALB."
  vpc_id      = var.vpc_id

  # Inbound rule: Allow HTTP (80) from 0.0.0.0/0
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: All Traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance Security Group (ALB-TG-SG)
resource "aws_security_group" "instance" {
  name        = "${var.project_name}-Instance-SG"
  description = "Allows HTTP traffic from the ALB only, and all outbound."
  vpc_id      = var.vpc_id

  # Inbound rule: Allow HTTP (80) from the ALB's Security Group ID
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound rule: All Traffic (for NAT Gateway access)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## 5. Application Load Balancer (ALB) Setup

# Target Group (ALB-TG)
resource "aws_lb_target_group" "main" {
  name     = "${var.project_name}-ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path = "/"
    protocol = "HTTP"
    port = 80
    matcher = "200"
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "${var.project_name}-ALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids # Public-A and Public-B

  tags = {
    Name = "${var.project_name}-ALB"
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

## 4. EC2 Launch Template and User Data

resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-LT-"
  image_id      = var.ami_id
  instance_type = "t2.micro"

  network_interfaces {
    security_groups             = [aws_security_group.instance.id]
    associate_public_ip_address = false # Instances are in private subnets
  }

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(data.template_file.user_data.rendered)
}


## 6. Auto Scaling Group (ASG) and Scheduled Scaling

resource "aws_autoscaling_group" "main" {
  name                = "${var.project_name}-ASG"
  max_size            = 2
  min_size            = 0 # Will be scaled up by scheduled action
  desired_capacity    = 2 # Initial size for setup
  vpc_zone_identifier = var.private_subnet_ids # Private-A and Private-B

  launch_template {
    id      = aws_launch_template.main.id
    version = "$$Latest$$"
  }

  target_group_arns = [aws_lb_target_group.main.arn]

  tags = [
    {
      key                 = "Name"
      value               = "${var.project_name}-Instance"
      propagate_at_launch = true
    },
  ]
}

# Scheduled Scaling: Scale In (Nighttime Shutdown) - 8:00 PM IST
resource "aws_autoscaling_schedule" "scale_in_night" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  scheduled_action_name  = "Scale-In-Night"
  min_size               = 0
  max_size               = 2
  desired_capacity       = 0
  # Recurrence: 8:00 PM IST is 20:00 UTC+5:30. In cron: 30 14 * * * UTC
  # To use region time (IST), we use the ASG's built-in time zone handling:
  # Using the suggested 00 20 * * * IST
  recurrence             = "0 20 * * *"
  timezone               = "Asia/Kolkata" # Mumbai's Timezone
}

# Scheduled Scaling: Scale Out (Morning Start) - 6:00 AM IST
resource "aws_autoscaling_schedule" "scale_out_morning" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  scheduled_action_name  = "Scale-Out-Morning"
  min_size               = 2
  max_size               = 2
  desired_capacity       = 2
  # Recurrence: 6:00 AM IST. In cron: 0 6 * * * IST
  recurrence             = "0 6 * * *"
  timezone               = "Asia/Kolkata" # Mumbai's Timezone
}

## 8. Map ALB to Domain

data "aws_route53_zone" "selected" {
  name         = var.hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.hosted_zone_name # Creates a record for the naked domain or 'www' if specified
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

##### `modules/app/user_data.sh` (Bash Script)

Create this file inside `modules/app`.

```bash
#!/bin/bash
set -e

# Step 1: Create user "my-user" and add to sudoers
useradd -m my-user
echo "my-user ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/my-user
usermod -aG sudo my-user

# Step 2 & 3: Install and Enable Docker
# Using the recommended setup for Ubuntu
apt-get update -y
apt install -y unzip
apt-get install -y ca-certificates curl gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

systemctl enable docker
usermod -aG docker my-user

# Step 4: Install and enable SSM Agent
# On most modern Ubuntu AMIs, SSM is pre-installed. The snap command is a robust fallback.
if ! systemctl status amazon-ssm-agent > /dev/null; then
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Step 5: Install AWS CLI (needed for s3 copy)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
aws --version

# Step 6: Copy from S3, unzip, and move contents
mkdir -p /home/my-user/apps/gym/
chown -R my-user:my-user /home/my-user/

# Use the my-user context to ensure file ownership is correct
# The IAM role provides access for the EC2 instance profile
sudo -H -u my-user bash -c '
  aws s3 cp s3://my-bucket-docker-site/gym-app/Gym.zip /tmp/Gym.zip
  unzip /tmp/Gym.zip -d /home/my-user/apps/gym/
  rm /tmp/Gym.zip
'

# Step 7: Install and run Nginx container
docker container run -d \
-v /home/my-user/apps/gym/Gym:/usr/share/nginx/html:ro \
--name=nginx-container1 \
--hostname=nginx-server \
-p80:80 nginx
```

-----------------------------------------------
Running and applying the provided Terraform templates from a Windows machine involves four main steps: **Installation**, **Configuration**, **Initialization**, and **Execution**.

Here is the complete process:

-----

## 1\. Prerequisites and Installation

### A. Install Terraform

1.  **Download Terraform:** Go to the official HashiCorp Terraform downloads page.
2.  **Install:** Download the appropriate **Windows 64-bit** zip file.
3.  **Extract:** Unzip the file (it contains a single `terraform.exe` executable).
4.  **Add to Path:** Move `terraform.exe` to a permanent directory (e.g., `C:\terraform`). Then, add this directory to your Windows System **Environment Variables PATH**. This allows you to run the `terraform` command from any terminal location.
5.  **Verify:** Open PowerShell or Command Prompt and run:
    ```bash
    terraform -v
    ```

### B. Install AWS CLI

1.  **Download AWS CLI:** Download and run the AWS CLI MSI installer for Windows.
2.  **Verify:** Open a new terminal and run:
    ```bash
    aws --version
    ```

-----

## 2\. Configure AWS Credentials

Terraform needs your AWS security credentials to create resources. The best practice is to configure the AWS CLI, and Terraform will automatically use those credentials.

1.  **Run Configuration:** Open your terminal and run the AWS configuration command:
    ```bash
    aws configure
    ```
2.  **Enter Credentials:** You will be prompted to enter your credentials. Use the **Access Key ID** and **Secret Access Key** of an IAM user with administrative or sufficient permissions.
      * **AWS Access Key ID:** `AKIA...`
      * **AWS Secret Access Key:** `wJalr...`
      * **Default region name:** `ap-south-1` (Mumbai)
      * **Default output format:** `json`

-----

## 3\. Prepare the Template Files

Ensure your local project directory structure and files are correctly set up on your Windows machine, as outlined in the previous steps.

1.  **Create the Structure:** Execute the directory creation command in your preferred directory (e.g., `C:\terraform\gym-app`):

    ```bash
    mkdir -p modules/{vpc,iam,app} && touch main.tf providers.tf variables.tf && touch modules/vpc/{main.tf,outputs.tf,variables.tf} && touch modules/iam/{main.tf,outputs.tf,variables.tf} && touch modules/app/{main.tf,outputs.tf,variables.tf,user_data.sh}
    ```

2.  **Populate Files:** Copy the content provided in the previous answers into the respective `.tf` files, making sure you have applied all the corrections (e.g., removing `vpc = true`, using singular `tag {}`, and fixing the `recurrence` for the ASG schedules).

      * **Crucial Step:** Ensure the `modules/app/user_data.sh` file contains the full Bash script.

-----

## 4\. Terraform Execution

Navigate to the root directory of your Terraform project (where `main.tf` is located) in your terminal.

### A. Initialize the Project

This step downloads the necessary AWS provider plugin and initializes the backend.

```bash
terraform init
```

### B. Validate the Configuration

This step checks the syntax and structure of your Terraform code against the provider's schema.

```bash
terraform validate
```

### C. Review the Plan

This step generates an execution plan, showing exactly what Terraform will create, update, or destroy in your AWS account. **Always review this output carefully.**

```bash
terraform plan
```

### D. Apply the Configuration

This step executes the plan, creating the resources in your AWS account. You must type **`yes`** to confirm the operation.

```bash
terraform apply
```

The process will take several minutes as it creates the VPC, NAT Gateway, Load Balancer, and launches the EC2 instances via the Auto Scaling Group.

### E. Destroy Resources (Cleanup)

Once you are done, you can clean up all the provisioned resources to avoid unwanted AWS charges.

```bash
terraform destroy
```

You must type **`yes`** to confirm the destruction.