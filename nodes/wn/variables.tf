
#####################################################################
# GLOBAL
#####################################################################

variable "swarm_name" {
  type    = string
  default = ""
}

variable "environment" {
  type    = string
  default = ""
}

variable "wn_index" {
  type    = string
  default = ""
}

#####################################################################
# VPC
#####################################################################

variable "swarm_vpc_id" {
  type    = string
  default = ""
}

variable "swarm_vpc_cidr" {
  type    = string
  default = ""
}

#####################################################################
# USER DATA
#####################################################################

variable "num_of_mn" {
  type    = number
  default = 1
}

variable "mn_1_private_eip_name" {
  type    = string
  default = ""
}

variable "mn_2_private_eip_name" {
  type    = string
  default = ""
}

variable "mn_3_private_eip_name" {
  type    = string
  default = ""
}

variable "mn_4_private_eip_name" {
  type    = string
  default = ""
}

variable "mn_5_private_eip_name" {
  type    = string
  default = ""
}

variable "mn_6_private_eip_name" {
  type    = string
  default = ""
}

variable "mn_7_private_eip_name" {
  type    = string
  default = ""
}

#####################################################################
# ASG
#####################################################################

variable "node_subnet_type" {
  type    = string
  default = ""
}

variable "node_subnets" {
  type    = list(string)
  default = []
}

variable "node_instance_type" {
  type    = string
  default = ""
}

variable "node_os_architecture" {
  type    = string
  default = ""
}

variable "node_linux_distribution" {
  type    = string
  default = ""
}

variable "node_rhel_version" {
  type    = string
  default = ""
}

variable "node_ubuntu_version" {
  type    = string
  default = ""
}

variable "node_ubuntu_server_type" {
  type    = string
  default = ""
}

#####################################################################
# SSH ACCESS
#####################################################################

variable "node_ssh_access_cidr_block" {
  type    = list(string)
  default = []
}

#####################################################################
# KEY PAIR
#####################################################################

variable "backup_node_ssh_private_key" {
  type    = bool
  default = false
}

#####################################################################
# USER DATA FUNCTIONS FILE
#####################################################################

variable "swarm_config_files_s3_bucket_name" {
  type    = string
  default = ""
}

variable "swarm_config_files_s3_bucket" {
  type    = string
  default = ""
}

#####################################################################
# IAM ACCESS
#####################################################################

variable "grant_swarm_services_iam_access" {
  type    = bool
  default = false
}

#####################################################################
# WORKLOADS PORTS
#####################################################################

variable "node_port_services_ingress_from_port" {
  type    = number
  default = 30000
}

variable "node_port_services_ingress_to_port" {
  type    = number
  default = 32767
}

#####################################################################
# NOTIFICATION
#####################################################################

variable "enable_node_status_notification" {
  type    = bool
  default = false
}

variable "slack_webhook_url_ssm_parameter" {
  type    = string
  default = ""
}

######################################## APACHEPLAYGROUND™ ########################################
