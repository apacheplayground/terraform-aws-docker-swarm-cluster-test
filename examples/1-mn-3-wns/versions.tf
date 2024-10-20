
# used child models and their required aws versions
#**************************************************
# terraform-aws-modules/vpc/aws      = >= 5.0
# terraform-aws-modules/acm/aws      = >= 4.40
# terraform-aws-modules/key-pair/aws = >= 4.21

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
      #configuration_aliases = [ aws.acm_provider,aws.route53_provider ]
    }
  }
}

######################################## APACHEPLAYGROUND™ ########################################
