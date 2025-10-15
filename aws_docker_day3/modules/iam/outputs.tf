output "instance_profile_name" {
  description = "The name of the IAM Instance Profile."
  value       = aws_iam_instance_profile.main.name
}