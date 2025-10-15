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