#### Here we will setup a private fully managed AWS ECR repo to host and share our docker images

AWS Elastic Container Registry ($\mathbf{ECR}$) is a fully managed Docker container registry that makes it easy for developers to store, manage, and deploy container images.

Here are the steps to set up a private ECR repository and how to use it for different purposes.

We will also go through the Terraform templates to create the same via a Terraform code
-----

## 1\. Steps to Set Up Fully Managed AWS ECR

The setup process involves creating a repository in the AWS Management Console or via the AWS CLI, and then configuring your local environment to push and pull images.

### Prerequisites

1.  An **AWS Account** with appropriate IAM permissions (e.g., the `AmazonEC2ContainerRegistryPowerUser` managed policy or equivalent).
2.  **Docker** installed on your local machine.
3.  **AWS CLI** installed and configured with your AWS credentials.

### Step-by-Step Setup (Using AWS Console)

#### Step 1: Create an ECR Repository

1.  Navigate to the **AWS Management Console** and go to **Elastic Container Registry (ECR)**.
2.  Choose **Private repositories**, then click **Create repository**.
3.  For **Visibility settings**, choose **Private** (default and recommended).
4.  Enter a **Repository name** (e.g., `my-web-app-repo`).
5.  Under **Image scanning settings**, it's best practice to keep **Scan on push** enabled to automatically check for vulnerabilities.
6.  Under **KMS encryption**, you can generally leave the default settings (encryption at rest using AWS managed keys).
7.  Click **Create repository**.

#### Step 2: Authenticate Your Docker Client

You need to authenticate your local Docker client to your private ECR registry using a temporary token.

1.  In the ECR console, navigate to your new repository and click **View push commands**.
2.  AWS will provide the exact AWS CLI command to get the authentication token. It typically looks like this (replace with your region and account ID):
    ```bash
    aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.<your-region>.amazonaws.com
    ```
3.  Run this command in your terminal. You should see "Login Succeeded."

#### Step 3: Build, Tag, and Push Your Docker Image

1.  **Build the Docker Image:** Navigate to the directory containing your `Dockerfile` and build your image.
    ```bash
    docker build -t my-local-image:latest .
    ```
2.  **Tag the Image:** Tag the built image with the full ECR repository URI.
    ```bash
    docker tag my-local-image:latest <aws-account-id>.dkr.ecr.<your-region>.amazonaws.com/my-web-app-repo:latest
    ```
3.  **Push the Image:** Push the tagged image to your ECR repository.
    ```bash
    docker push <aws-account-id>.dkr.ecr.<your-region>.amazonaws.com/my-web-app-repo:latest
    ```
4.  Verify the image appears in your ECR repository in the AWS Console.

-----

## 2\. Using AWS ECR for Different Purposes

ECR is designed to be the central image repository in your container workflow, integrating with various AWS and non-AWS services.

| Purpose | Description | Key ECR Feature Integration |
| :--- | :--- | :--- |
| **Microservices Deployment** | Storing container images for deployment to container orchestration services like **Amazon ECS** or **Amazon EKS**. | **Seamless Integration:** ECS Task Definitions and EKS Pod specs directly reference the ECR image URI for deployment. |
| **CI/CD Pipelines** | Using ECR as the target for automated image builds, typically from tools like **AWS CodeBuild**, **GitHub Actions**, or **Jenkins**. | **Build Automation:** CI tools authenticate with ECR, build the image, tag it (often with a commit hash), and push it to the ECR repo. |
| **Security and Compliance** | Ensuring only secure, compliant images are deployed by checking for vulnerabilities before they are used. | **Image Scanning:** Integrated with **Amazon Inspector** to automatically scan images for known vulnerabilities upon push. |
| **Cross-Account/Cross-Region Sharing** | Allowing other AWS accounts (e.g., staging or production accounts) or other regions to access the container images. | **Repository and Registry Policies:** Use **IAM policies** and **Repository Policies** to grant read/pull permissions to other accounts. **Replication** can be configured for automatic cross-region or cross-account mirroring. |
| **Base Image Management** | Storing approved, hardened **base images** that all internal application images are built upon. | **Access Control & Scanning:** Enforce strict access and use scanning features on base images to maintain a secure foundation for all development. |
| **Automated Cleanup** | Managing storage costs and security posture by automatically removing old, unused, or untagged images. | **Lifecycle Policies:** Define rules (e.g., delete images older than 90 days, or keep only the last 10 images) to manage image retention. |
| **OCI Artifact Storage** | ECR can store more than just Docker images, supporting **OCI (Open Container Initiative) artifacts** like **Helm charts** or **Terraform modules**. | **OCI Support:** Use tools like the **ORAS CLI** (OCI Registry As Storage) to push and pull non-Docker artifacts to/from ECR. |

-----------------------------
**Steps to create the same setup using Terraform**
=================
To create a private AWS ECR repository using Terraform, you'll define an `aws_ecr_repository` resource. This template follows the best practices mentioned in the setup steps, enabling **image scanning on push** for vulnerability checks and setting **tag immutability** for better version control.

Here is the Terraform configuration:

## Terraform Template for Private ECR Repository

This template is split into three files: `main.tf` for the resource definition, `variables.tf` for input variables, and `outputs.tf` to display the resulting repository URI.

### 1\. `main.tf`

```terraform

# ECR Repository Resource

resource "aws_ecr_repository" "private_repo" {
  name                   = var.repository_name
  image_tag_mutability   = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true # Enable automatic vulnerability scanning
  }

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
```



### 2\. `variables.tf`

```terraform
# Defines the AWS region where the ECR will be created
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1" 
}

# Defines the name for the new ECR repository
variable "repository_name" {
  description = "The name for the ECR repository"
  type        = string
  default     = "my-private-app-repo"
}
```

-----

### 3\. `outputs.tf`

```terraform
# Outputs the full URI needed for Docker push/pull commands and deployments
output "ecr_repository_uri" {
  description = "The full URI of the newly created ECR repository."
  value       = aws_ecr_repository.private_repo.repository_url
}

# Outputs the AWS Account ID and Region (useful for authentication command)
output "ecr_login_info" {
  description = "Information for Docker login command."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# Data source to fetch the current AWS Account ID
data "aws_caller_identity" "current" {}
```

-----

## Deployment Steps

1.  **Save the Files:** Save the three code blocks above into their respective files (`main.tf`, `variables.tf`, `outputs.tf`) in an empty directory.
2.  **Initialize:** Open your terminal in the directory and run:
    ```bash
    terraform init
    ```
3.  **Plan:** Review the actions Terraform will take:
    ```bash
    terraform plan
    ```
4.  **Apply:** Execute the configuration to create the repository:
    ```bash
    terraform apply
    ```
    Type `yes` to confirm.

Once complete, the **`ecr_repository_uri`** output will give you the exact address you need for your Docker commands and deployments.

-----------------------------------
### Here is the $\mathrm{Terraform}$ code to create an $\mathrm{IAM}$ role and attach the $\mathbf{AmazonEC2ContainerRegistryPowerUser}$ managed policy to it. This role can then be assumed by $\mathrm{EC}2$ instances, $\mathrm{ECS}$ tasks, or $\mathrm{CI}/\mathrm{CD}$ services that need to push and pull images from your $\mathrm{ECR}$ repository.

## Terraform Template for ECR Power User IAM Role 🔒

This template involves three main components:

1.  **$\mathbf{aws\_iam\_role}$**: Defines the $\mathrm{IAM}$ role and its **Trust $\mathrm{Policy}$** (which entities are allowed to assume the role, such as $\mathrm{EC}2$).
2.  **$\mathbf{aws\_iam\_policy\_attachment}$**: Attaches the $\mathrm{AWS}$ managed policy to the created role.
3.  **$\mathbf{data}$ $\mathrm{sources}$**: Retrieves the $\mathrm{ARN}$ of the managed policy and the current account ID.

### `iam_role.tf`

```terraform
# 1. Data Source to get the ARN of the AWS Managed Policy
data "aws_iam_policy" "ecr_power_user" {
  name = "AmazonEC2ContainerRegistryPowerUser"
}

# 2. IAM Role Definition
resource "aws_iam_role" "ecr_pusher_role" {
  name               = "ECR-Pusher-Puller-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        # Trust policy for EC2 Instances
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
  policy_arn = data.aws_iam_policy.ecr_power_user.arn
}

# 4. Optional: Create an Instance Profile if this role is for EC2
resource "aws_iam_instance_profile" "ecr_pusher_profile" {
  # This conditional logic correctly determines if the resource should be created.
  count = length(regexall("ec2.amazonaws.com", aws_iam_role.ecr_pusher_role.assume_role_policy)) > 0 ? 1 : 0
  name  = aws_iam_role.ecr_pusher_role.name
  role  = aws_iam_role.ecr_pusher_role.name
}

# 5. Output the Role ARN
output "ecr_power_user_role_arn" {
  description = "The ARN of the IAM role with ECR Power User permissions."
  value       = aws_iam_role.ecr_pusher_role.arn
}

# 6. Output the Instance Profile ARN (FIXED)
output "ecr_instance_profile_arn" {
  description = "The ARN of the IAM instance profile for EC2 (if created)."
  # Use the 'one' function on the splat expression to safely get the ARN 
  # of the first (and only) element, or null if the list is empty (count was 0).
  value = one(aws_iam_instance_profile.ecr_pusher_profile[*].arn)
}
```

### Key Considerations for the Trust Policy

  * **For EC2 Instances:** Use `"Service": "ec2.amazonaws.com"` (as shown above). You then associate the `aws_iam_instance_profile` with your $\mathrm{EC}2$ instance.
  * **For ECS Tasks (Task Execution Role):** Use `"Service": "ecs-tasks.amazonaws.com"`. This is the most common use case for $\mathrm{ECR}$.
  * **For AWS CodeBuild (CI/CD):** Use `"Service": "codebuild.amazonaws.com"`.