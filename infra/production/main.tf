terraform {

  backend "s3" {
    bucket       = "s3-native-lock-setup-important"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    profile      = "default"
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
  profile = "default"
  region  = "us-east-2"
}

variable "production_public_key" {
  description = "Production environment public key value"
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

resource "aws_key_pair" "production_key" {
  key_name   = "production-key"
  public_key = var.production_public_key

  tags = {
    "Name" = "production_public_key"
  }
}

# This is the main staging environment. We will deploy to this the changes
# to the main branch before deploying to the production environment.
resource "aws_instance" "production_cicd_demo" {
  # Read the AMI id "through" the random_id resource to ensure that
  # both will change together.
  ami                    = random_id.server.keepers.ami_id
  instance_type          = "t3.micro"
  vpc_security_group_ids = ["sg-00f48e397ba8b9abc"]
  key_name               = aws_key_pair.production_key.key_name

  tags = {
    "Name" = "production_cicd_demo-${random_id.server.hex}"
  }
}

output "production_dns" {
  value = aws_instance.production_cicd_demo.public_dns
}
