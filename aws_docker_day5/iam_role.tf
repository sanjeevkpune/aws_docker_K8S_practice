# 1. Data Source to get the ARN of the AWS Managed Policy
data "aws_iam_policy" "ecr_power_user" {
  name = "AmazonEC2ContainerRegistryPowerUser"
}

# 2. IAM Role Definition
# This role is typically assumed by an EC2 Instance or an ECS Task (Fargate or EC2 launch type)
resource "aws_iam_role" "ecr_pusher_role" {
  name               = "ECR-Pusher-Puller-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        # This trust policy allows EC2 Instances (via the Instance Profile) 
        # or ECS Tasks (via its Task Execution Role) to assume this role.
        # For CI/CD (e.g., CodeBuild), you'd change this to "codebuild.amazonaws.com"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  description = "IAM role with ECR Power User permissions for pushing and pulling images."
}

# 3. Attach the AmazonEC2ContainerRegistryPowerUser Policy to the Role
resource "aws_iam_role_policy_attachment" "ecr_power_user_attach" {
  role       = aws_iam_role.ecr_pusher_role.name
  # Uses the ARN retrieved by the data source
  policy_arn = data.aws_iam_policy.ecr_power_user.arn
}

# 4. Optional: Create an Instance Profile if this role is for EC2
resource "aws_iam_instance_profile" "ecr_pusher_profile" {
  count = length(regexall("ec2.amazonaws.com", aws_iam_role.ecr_pusher_role.assume_role_policy)) > 0 ? 1 : 0
  name  = aws_iam_role.ecr_pusher_role.name
  role  = aws_iam_role.ecr_pusher_role.name
}

# 5. Output the Role ARN
output "ecr_power_user_role_arn" {
  description = "The ARN of the IAM role with ECR Power User permissions."
  value       = aws_iam_role.ecr_pusher_role.arn
}

# 6. Output the Instance Profile ARN (if created)
output "ecr_instance_profile_arn" {
  description = "The ARN of the IAM instance profile for EC2."
  value       = count.index == 0 ? aws_iam_instance_profile.ecr_pusher_profile[0].arn : null
}