terraform {
  backend "s3" {
    bucket       = "s3-native-lock-setup-important"
    key          = "staging-pr/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }

  required_version = ">= 0.15.0"
}

provider "aws" {
  region = "us-east-2"
}

variable "staging_pr_public_key" {
  description = "Staging environment public key value"
  type        = string
}

variable "base_ami_id" {
  description = "Base AMI ID"
  type        = string
}

resource "random_id" "server" {
  keepers = {
    # Generate a new id each time we switch to a new AMI id
    ami_id = "${var.base_ami_id}"
  }

  byte_length = 8
}

resource "aws_key_pair" "staging_pr_key" {
  key_name   = "staging-pr-key"
  public_key = var.staging_pr_public_key

  tags = {
    "Name" = "staging_pr_public_key"
  }
}

# This is the main staging environment. We will deploy to this the changes
# to the main branch before deploying to the production environment.
resource "aws_instance" "staging_pr_cicd_demo" {
  # Read the AMI id "through" the random_id resource to ensure that
  # both will change together.
  ami                    = random_id.server.keepers.ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = ["sg-00f48e397ba8b9abc"]
  key_name               = aws_key_pair.staging_pr_key.key_name

  tags = {
    "Name" = "staging_cicd_demo-${random_id.server.hex}"
  }
}

output "staging_pr_dns" {
  value = aws_instance.staging_pr_cicd_demo.public_dns
}
