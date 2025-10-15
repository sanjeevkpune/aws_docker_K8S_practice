### Here we will update terraform templates in day3 to serve https requests
--------------------
To update your AWS setup to serve HTTPS requests using the ACM certificate with ID `c01e79e1-8b86-4591-91ad-3708fb58c175`, you need to make changes in the **Application Module (`modules/app`)**.

cert ARN - arn:aws:acm:ap-south-1:691249426747:certificate/c01e79e1-8b86-4591-91ad-3708fb58c175

Specifically, you must:

1.  **Add the Certificate ARN** to the Application Module's variables.
2.  **Add a new HTTPS Listener (Port 443)** to the Application Load Balancer (ALB).
3.  **Update the ALB Security Group (ALB-SG)** to allow inbound traffic on Port 443.

Here are the necessary changes for your Terraform templates:

-----

## 1\. Root Variables Update (`variables.tf` - Root)

The certificate is specific to this setup, so it's best to define its ARN as a variable in the root to pass it down to the application module.

Add this variable to your root `variables.tf` file:

```terraform
variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS listeners."
  type        = string
  # Construct the ARN using the provided ID and the Mumbai region (ap-south-1)
  default     = "arn:aws:acm:ap-south-1:123456789012:certificate/c01e79e1-8b86-4591-91ad-3708fb58c175" 
  # NOTE: Replace '123456789012' with your actual AWS Account ID.
}
```

-----

## 2\. Application Module Variables Update (`modules/app/variables.tf`)

Receive the new variable in the application module.

Add this to `modules/app/variables.tf`:

```terraform
variable "acm_certificate_arn" {
  description = "The ARN of the ACM certificate for HTTPS listeners."
  type        = string
}
```

-----

## 3\. Application Module Main Update (`modules/app/main.tf`)

This is where the core changes happen to enable HTTPS.

### A. Update ALB Security Group (`aws_security_group.alb`)

Add an ingress rule to allow traffic on Port 443 (HTTPS).

```terraform
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-ALB-SG"
  description = "Allows HTTP/HTTPS traffic from the internet to the ALB."
  vpc_id      = var.vpc_id

  # Inbound rule: Allow HTTP (80) from 0.0.0.0/0 (Existing)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # NEW: Inbound rule: Allow HTTPS (443) from 0.0.0.0/0
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule: All Traffic (Existing)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### B. Add HTTPS Listener (`aws_lb_listener.https`)

Create a new listener on port 443, associating it with your ACM certificate and forwarding traffic to the existing target group.

```terraform
# Existing HTTP Listener (Port 80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# NEW: HTTPS Listener (Port 443)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn # Use the ACM ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}
```

**Note:** If you want to force all HTTP traffic to redirect to HTTPS, you would change the `default_action` of the **HTTP Listener** (`aws_lb_listener.http`) to a **redirect** action targeting Port 443. For now, the configuration above allows both HTTP and HTTPS access.

Update as below 
# Existing HTTP Listener (Port 80) - MODIFIED FOR REDIRECTION
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect" # CHANGE: Set action type to redirect
    
    # NEW: Define the redirect parameters
    redirect {
      port        = "443"    # Redirect to the HTTPS port
      protocol    = "HTTPS"  # Ensure the protocol is HTTPS
      status_code = "HTTP_301" # Permanent redirect status code
      # host and path are left blank to preserve the original host and path
    }
  }
}
