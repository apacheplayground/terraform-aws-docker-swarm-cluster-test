
# child models and required aws versions
#***************************************
# terraform-aws-modules/key-pair/aws = >= 4.21
# terraform-aws-modules/vpc/aws      = >= 5.0

# Configure terraform provider
#*****************************
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.0"
      configuration_aliases = [aws.acm_provider, aws.route53_provider]
    }

    null = {
      source  = "hashicorp/null"
      version = "3.2.1"
    }
  }
}

######################################## APACHEPLAYGROUND™ ########################################
