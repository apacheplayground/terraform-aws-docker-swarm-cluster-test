
# used child models and their required aws versions
#**************************************************
# terraform-aws-modules/key-pair/aws = >= 4.21


# Configure terraform provider
#*****************************
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.21"
    }
  }
}

######################################## APACHEPLAYGROUND™ ########################################
