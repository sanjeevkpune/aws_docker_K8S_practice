# ECR Repository Resource
resource "aws_ecr_repository" "private_repo" {
  # The name of the repository, taken from a variable
  name = var.repository_name

  # Configuration for image scanning (highly recommended for security)
  image_scanning_configuration {
    scan_on_push = true
  }

  # Configuration for tag immutability (optional, but good practice)
  # Set to IMMUTABLE to prevent image tags from being overwritten
  #image_tag_mutability = "IMMUTABLE"

  # Add tags for organization and cost tracking
  tags = {
    Name        = var.repository_name
    Environment = "Development"
  }
}

 
# Define the ECR Lifecycle Policy as a separate resource
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  # Link the policy to the repository created in main.tf
  repository = aws_ecr_repository.private_repo.name 

  policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Keep last 10 'prod' images",
        "selection" : {
          "tagStatus" : "tagged",
          "tagPrefixList" : ["prod"],
          "countType" : "imageCountMoreThan",
          "countNumber" : 10
        },
        "action" : {
          "type" : "expire"
        }
      },
      {
        "rulePriority" : 2,
        "description" : "Delete untagged images older than 7 days",
        "selection" : {
          "tagStatus" : "untagged",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : 7
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}