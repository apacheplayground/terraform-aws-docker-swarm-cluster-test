
#####################################################################
# PROVIDERS
#####################################################################

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}

provider "aws" {
  alias  = "route53_provider"
  region = "us-east-1"
}

#####################################################################
# CLUSTER
#####################################################################

module "dswm_cluster" {
  source = "../../"

  # aws providers argument must be included
  providers = {
    aws                  = aws
    aws.acm_provider     = aws.acm_provider
    aws.route53_provider = aws.route53_provider
  }

  swarm_name       = "test-dswm"
  create_swarm_vpc = true
  swarm_vpc_region = "us-east-1" #"us-west-1"            #"us-east-2"     #     #      #"us-west-2"

  num_of_mn      = 1
  num_of_wn      = 3
  num_of_wn_grps = 0

  admin_dashboards_parent_domain_name = "apacheplayground.com"
  portainer_server_type               = "swarm-service"
  #enable_portainer_server_s3_cron_backup = true

  /*
  mn_instance_type   = "t2.large"
  wn_1_instance_type = "t2.medium"
  wn_2_instance_type = "t2.medium"
  wn_3_instance_type = "t2.medium"
*/

  mn_instance_type   = "t2.large"
  wn_1_instance_type = "t2.large"
  wn_2_instance_type = "t2.large"
  wn_3_instance_type = "t2.large"
}

######################################## APACHEPLAYGROUND™ ########################################
