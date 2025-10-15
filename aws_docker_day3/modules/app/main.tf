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
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main.arn]

  # Use the singular 'tag' block when defining tags for ASG with propagation
  tag {
    key                 = "Name"
    value               = "${var.project_name}-Instance"
    propagate_at_launch = true
  }
  
}

# Scheduled Scaling: Scale In (Nighttime Shutdown) - 8:00 PM IST
resource "aws_autoscaling_schedule" "scale_in_night" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  scheduled_action_name  = "Scale-In-Night"
  min_size               = 0
  max_size               = 2
  desired_capacity       = 0
  # Recurrence for 2:30 PM UTC (equivalent to 8:00 PM IST)
  recurrence             = "30 14 * * *" 
  # REMOVE: timezone               = "Asia/Kolkata" 
}

# Scheduled Scaling: Scale Out (Morning Start) - 6:00 AM IST
resource "aws_autoscaling_schedule" "scale_out_morning" {
  autoscaling_group_name = aws_autoscaling_group.main.name
  scheduled_action_name  = "Scale-Out-Morning"
  min_size               = 2
  max_size               = 2
  desired_capacity       = 2
  # Recurrence for 12:30 AM UTC (equivalent to 6:00 AM IST)
  recurrence             = "30 0 * * *"
}

## 8. Map ALB to Domain (Two Records: Root and WWW)

data "aws_route53_zone" "selected" {
  name         = var.hosted_zone_name
  private_zone = false
}

# 1. Record for the Naked Domain (devops-practice.click)
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "" # Empty name refers to the apex/naked domain
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.main.dns_name}"
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# 2. Record for the WWW Subdomain (www.devops-practice.click)
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www" # "www" is the subdomain name
  type    = "A"

  alias {
    name                   = "dualstack.${aws_lb.main.dns_name}"
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}