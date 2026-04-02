terraform {

  backend "s3" {
    bucket       = "s3-native-lock-setup-important"
    key          = "ebs/terraform.tfstate"
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



# -------------------------------
# IAM ROLE FOR EC2
# -------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "snow-flake-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier",
    "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
  ])

  role       = aws_iam_role.ec2_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "snow-flake-ec2-profile"
  role = aws_iam_role.ec2_role.name
}


# -------------------------------
# BEANSTALK SERVICE ROLE
# -------------------------------
resource "aws_iam_role" "beanstalk_service" {
  name = "beanstalk-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "elasticbeanstalk.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "beanstalk_service_policy" {
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}


# -------------------------------
# ELASTIC BEANSTALK APPLICATION
# -------------------------------
resource "aws_elastic_beanstalk_application" "app" {
  name = "snow-flake"

  appversion_lifecycle {
    service_role          = aws_iam_role.beanstalk_service.arn
    max_count             = 128
    delete_source_from_s3 = true
  }
}


# ELASTIC BEANSTALK ENVIRONMENT
# -------------------------------
resource "aws_elastic_beanstalk_environment" "env" {
  name                = "snow-flake-env"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v6.10.0 running Node.js 20"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.ec2_profile.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

}


# -------------------------------
# OUTPUTS
# -------------------------------


output "environment_name" {
  value = aws_elastic_beanstalk_environment.env.name
}

output "application_name" {
  value = aws_elastic_beanstalk_application.app.name
}

output "endpoint_url" {
  value = aws_elastic_beanstalk_environment.env.endpoint_url
}


