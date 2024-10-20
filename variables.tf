
#####################################################################
# GLOBAL VARIABLES
#####################################################################

variable "swarm_name" {
  description = "The name of the swarm cluster."
  type        = string
  default     = ""
}

variable "environment" {
  description = "The environment in which the swarm cluster will be created. Example (not mandatory) values include test, uat, prod etc."
  type        = string
  default     = ""
}

#####################################################################
# VPC VARIABLES
#####################################################################

variable "create_swarm_vpc" {
  description = "Whether or not to create a VPC for the swarm cluster or to use an existing one."
  type        = bool
  default     = true
}

variable "swarm_vpc_region" {
  description = "(Optional) The AWS region in which the swarm VPC will be created. Only valid when 'create_swarm_vpc' is true."
  type        = string
  default     = ""
}

variable "swarm_vpc_id" {
  description = "(Optional) The ID of the VPC in which the swarm cluster will be created. Only valid when 'create_swarm_vpc' is false."
  type        = string
  default     = ""
}

variable "swarm_vpc_azs" {
  description = "(Optional) The list of availability zone names or IDs to create in swarm VPC. Only valid when 'create_swarm_vpc' is false."
  type        = list(string)
  default     = []
}

variable "swarm_vpc_cidr" {
  description = "The IPv4 CIDR block of the VPC in which the swarm cluster will be created. Only valid when 'create_swarm_vpc' is true."
  type        = string
  default     = "10.0.0.0/16"
}

variable "swarm_vpc_public_subnets_cidrs" {
  description = "A list of IPv4 CIDR blocks for the public subnets in the swarm VPC. Only valid when 'create_swarm_vpc' is true."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24", ]
}

variable "swarm_vpc_private_subnets_cidrs" {
  description = "A list of IPv4 CIDR blocks for the private subnets in the swarm VPC. Only valid when 'create_swarm_vpc' is true."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24", ]
}

#####################################################################
# ADMIN DASHBOARDS VARIABLES
#####################################################################

variable "dashboards_parent_domain_name" {
  description = "The parent domain name (e.g. mycompany.com) to use for the swarm's dashboard URLS (i.e. portainer, prometheus, grafana and alertmanager)."
  type        = string
  default     = ""
}

variable "dashboards_access_cidr_block" {
  description = "The IPv4 CIDR block to enable http access to the swarm's admin dashboards (i.e. portainer, prometheus, grafana and alertmanager)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

#####################################################################
# ALL NODES VARIABLES
#####################################################################

variable "nodes_ssh_access_type" {
  description = "The type of ssh access to enable on the swarm nodes. Valid values are direct and via-bastion-host."
  type        = string
  default     = "direct"
}

variable "nodes_ssh_access_cidr_block" {
  description = "The IPv4 CIDR block to enable ssh access into the swarm nodes. It is recommended that you change this value from the default 'anywhere' value to a private cidr block or private ip address for secured access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "backup_nodes_ssh_private_keys" {
  description = "Whether or not to back up the ssh private keys of the swarm nodes in AWS SSM Paramater Store."
  type        = bool
  default     = false
}

variable "enable_nodes_status_notification" {
  description = "Whether or not to send the deployment status of the swarm nodes to the infrastructure team's Slack channel."
  type        = bool
  default     = false
}

variable "slack_webhook_url_ssm_parameter" {
  description = "The name of the SecureString AWS SSM parameter that contains the Slack webhook url of the infrastructure team's Slack channel. Only valid when 'enable_nodes_status_notification' is true. This ssm parameter should already exist in AWS SSM Parameter Store as a prerequisite."
  type        = string
  default     = ""
}

#####################################################################
# MN VARIABLES
#####################################################################

variable "num_of_mn" {
  description = "The number of swarm manager nodes. Valid values are 1, 3, 5 and 7."
  type        = number
  default     = 1
}

variable "mn_instance_type" {
  description = "The ec2 instance type that will be used to provision the manager node(s)."
  type        = string
  default     = "t2.medium"
}

variable "mn_os_architecture" {
  description = "The operating system architecture that will be used for the manager node(s). Valid values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "mn_linux_distribution" {
  description = "The linux distribution that will be installed on the manager node(s). Valid values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "mn_rhel_version" {
  description = "The version of RHEL that will be installed on the manager node(s). Only valid when the 'mn_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "mn_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on the manager node(s). Only valid when 'mn_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "mn_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on the manager node(s). Only valid when 'mn_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "attach_additional_iam_permissions_to_mn" {
  description = "Whether or not to attach additional iam permissions to manager nodes (mn)."
  type        = bool
  default     = false
}

variable "mn_additional_iam_permissions_document" {
  description = "The ID of the iam policy document that will be used to assign additional iam permissions to manager nodes (mn). Only valid when 'attach_additional_iam_permissions_to_mn' is true."
  type        = string
  default     = ""
}

#####################################################################
# ALL WN VARIABLES
#####################################################################

variable "num_of_wn" {
  description = "The number of single, static worker nodes that will be provisioned in the Swarm cluster. Valid values are from 1 to 10."
  type        = number
  default     = 1
}

variable "num_of_wn_grps" {
  description = "The number of elastic worker node groups that will be provisioned in the Swarm cluster. Valid values are from 0 to 10."
  type        = number
  default     = 0
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
# WN_1 VARIABLES
#####################################################################

variable "wn_1_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_1."
  type        = string
  default     = "t2.medium"
}

variable "wn_1_os_architecture" {
  description = "The operating system architecture that will be used for wn_1. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_1_linux_distribution" {
  description = "The linux distribution that will be installed on wn_1. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_1_rhel_version" {
  description = "The version of RHEL that will be installed on wn_1. Only valid when 'wn_1_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_1_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_1. Only valid when 'wn_1_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_1_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_1. Only valid when 'wn_1_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_2 VARIABLES
#####################################################################

variable "wn_2_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_2."
  type        = string
  default     = "t2.medium"
}

variable "wn_2_os_architecture" {
  description = "The operating system architecture that will be used for wn_2. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_2_linux_distribution" {
  description = "The linux distribution that will be installed on wn_2. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_2_rhel_version" {
  description = "The version of RHEL that will be installed on wn_2. Only valid when 'wn_2_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_2_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_2. Only valid when 'wn_2_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_2_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_2. Only valid when 'wn_2_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_3 VARIABLES
#####################################################################

variable "wn_3_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_3."
  type        = string
  default     = "t2.medium"
}

variable "wn_3_os_architecture" {
  description = "The operating system architecture that will be used for wn_3. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_3_linux_distribution" {
  description = "The linux distribution that will be installed on wn_3. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_3_rhel_version" {
  description = "The version of RHEL that will be installed on wn_3. Only valid when 'wn_3_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_3_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_3. Only valid when 'wn_3_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_3_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_3. Only valid when 'wn_3_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_4 VARIABLES
#####################################################################

variable "wn_4_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_4."
  type        = string
  default     = "t2.medium"
}

variable "wn_4_os_architecture" {
  description = "The operating system architecture that will be used for wn_4. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_4_linux_distribution" {
  description = "The linux distribution that will be installed on wn_4. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_4_rhel_version" {
  description = "The version of RHEL that will be installed on wn_4. Only valid when 'wn_4_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_4_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_4. Only valid when 'wn_4_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_4_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_4. Only valid when 'wn_4_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_5 VARIABLES
#####################################################################

variable "wn_5_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_5."
  type        = string
  default     = "t2.medium"
}

variable "wn_5_os_architecture" {
  description = "The operating system architecture that will be used for wn_5. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_5_linux_distribution" {
  description = "The linux distribution that will be installed on wn_5. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_5_rhel_version" {
  description = "The version of RHEL that will be installed on wn_5. Only valid when 'wn_5_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_5_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_5. Only valid when 'wn_5_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_5_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_5. Only valid when 'wn_5_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_6 VARIABLES
#####################################################################

variable "wn_6_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_6."
  type        = string
  default     = "t2.medium"
}

variable "wn_6_os_architecture" {
  description = "The operating system architecture that will be used for wn_6. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_6_linux_distribution" {
  description = "The linux distribution that will be installed on wn_6. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_6_rhel_version" {
  description = "The version of RHEL that will be installed on wn_6. Only valid when 'wn_6_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_6_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_6. Only valid when 'wn_6_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_6_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_6. Only valid when 'wn_6_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_7 VARIABLES
#####################################################################

variable "wn_7_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_7."
  type        = string
  default     = "t2.medium"
}

variable "wn_7_os_architecture" {
  description = "The operating system architecture that will be used for wn_7. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_7_linux_distribution" {
  description = "The linux distribution that will be installed on wn_7. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_7_rhel_version" {
  description = "The version of RHEL that will be installed on wn_7. Only valid when 'wn_7_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_7_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_7. Only valid when 'wn_7_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_7_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_7. Only valid when 'wn_7_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_8 VARIABLES
#####################################################################

variable "wn_8_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_8."
  type        = string
  default     = "t2.medium"
}

variable "wn_8_os_architecture" {
  description = "The operating system architecture that will be used for wn_8. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_8_linux_distribution" {
  description = "The linux distribution that will be installed on wn_8. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_8_rhel_version" {
  description = "The version of RHEL that will be installed on wn_8. Only valid when 'wn_8_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_8_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_8. Only valid when 'wn_8_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_8_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_8. Only valid when 'wn_8_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_9 VARIABLES
#####################################################################

variable "wn_9_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_9."
  type        = string
  default     = "t2.medium"
}

variable "wn_9_os_architecture" {
  description = "The operating system architecture that will be used for wn_9. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_9_linux_distribution" {
  description = "The linux distribution that will be installed on wn_9. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_9_rhel_version" {
  description = "The version of RHEL that will be installed on wn_9. Only valid when 'wn_9_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_9_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_9. Only valid when 'wn_9_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_9_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_9. Only valid when 'wn_9_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_10 VARIABLES
#####################################################################

variable "wn_10_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_10."
  type        = string
  default     = "t2.medium"
}

variable "wn_10_os_architecture" {
  description = "The operating system architecture that will be used for wn_10. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_10_linux_distribution" {
  description = "The linux distribution that will be installed on wn_10. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_10_rhel_version" {
  description = "The version of RHEL that will be installed on wn_10. Only valid when 'wn_10_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_10_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_10. Only valid when 'wn_10_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_10_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_10. Only valid when 'wn_10_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_11 VARIABLES
#####################################################################

variable "wn_11_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_11."
  type        = string
  default     = "t2.medium"
}

variable "wn_11_os_architecture" {
  description = "The operating system architecture that will be used for wn_11. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_11_linux_distribution" {
  description = "The linux distribution that will be installed on wn_11. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_11_rhel_version" {
  description = "The version of RHEL that will be installed on wn_11. Only valid when 'wn_1_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_11_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_11. Only valid when 'wn_11_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_11_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_1. Only valid when 'wn_11_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

/*
variable "mount_swarm_data_store_to_wn_1" {
  description = "Whether or not to mount the Swarm datastore efs volume to wn_1 for persistent docker volume storage."
  type        = bool
  default     = false
}
*/

#####################################################################
# WN_12 VARIABLES
#####################################################################

variable "wn_12_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_12."
  type        = string
  default     = "t2.medium"
}

variable "wn_12_os_architecture" {
  description = "The operating system architecture that will be used for wn_12. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_12_linux_distribution" {
  description = "The linux distribution that will be installed on wn_12. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_12_rhel_version" {
  description = "The version of RHEL that will be installed on wn_12. Only valid when 'wn_12_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_12_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_12. Only valid when 'wn_12_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_12_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_12. Only valid when 'wn_12_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

/*
variable "mount_swarm_data_store_to_wn_12" {
  description = "Whether or not to mount the Swarm datastore efs volume to wn_2 for persistent docker volume storage."
  type        = bool
  default     = false
}
*/

#####################################################################
# WN_13 VARIABLES
#####################################################################

variable "wn_13_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_13."
  type        = string
  default     = "t2.medium"
}

variable "wn_13_os_architecture" {
  description = "The operating system architecture that will be used for wn_13. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_13_linux_distribution" {
  description = "The linux distribution that will be installed on wn_13. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_13_rhel_version" {
  description = "The version of RHEL that will be installed on wn_13. Only valid when 'wn_13_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_13_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_13. Only valid when 'wn_13_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_13_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_13. Only valid when 'wn_13_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_14 VARIABLES
#####################################################################

variable "wn_14_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_14."
  type        = string
  default     = "t2.medium"
}

variable "wn_14_os_architecture" {
  description = "The operating system architecture that will be used for wn_14. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_14_linux_distribution" {
  description = "The linux distribution that will be installed on wn_14. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_14_rhel_version" {
  description = "The version of RHEL that will be installed on wn_14. Only valid when 'wn_14_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_14_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_14. Only valid when 'wn_14_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_14_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_14. Only valid when 'wn_14_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_15 VARIABLES
#####################################################################

variable "wn_15_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_15."
  type        = string
  default     = "t2.medium"
}

variable "wn_15_os_architecture" {
  description = "The operating system architecture that will be used for wn_15. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_15_linux_distribution" {
  description = "The linux distribution that will be installed on wn_15. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_15_rhel_version" {
  description = "The version of RHEL that will be installed on wn_15. Only valid when 'wn_15_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_15_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_15. Only valid when 'wn_15_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_15_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_15. Only valid when 'wn_15_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_16 VARIABLES
#####################################################################

variable "wn_16_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_16."
  type        = string
  default     = "t2.medium"
}

variable "wn_16_os_architecture" {
  description = "The operating system architecture that will be used for wn_16. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_16_linux_distribution" {
  description = "The linux distribution that will be installed on wn_16. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_16_rhel_version" {
  description = "The version of RHEL that will be installed on wn_16. Only valid when 'wn_16_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_16_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_16. Only valid when 'wn_16_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_16_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_16. Only valid when 'wn_16_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_17 VARIABLES
#####################################################################

variable "wn_17_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_17."
  type        = string
  default     = "t2.medium"
}

variable "wn_17_os_architecture" {
  description = "The operating system architecture that will be used for wn_17. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_17_linux_distribution" {
  description = "The linux distribution that will be installed on wn_17. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_17_rhel_version" {
  description = "The version of RHEL that will be installed on wn_17. Only valid when 'wn_17_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_17_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_17. Only valid when 'wn_17_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_17_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_17. Only valid when 'wn_17_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_18 VARIABLES
#####################################################################

variable "wn_18_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_18."
  type        = string
  default     = "t2.medium"
}

variable "wn_18_os_architecture" {
  description = "The operating system architecture that will be used for wn_18. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_18_linux_distribution" {
  description = "The linux distribution that will be installed on wn_18. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_18_rhel_version" {
  description = "The version of RHEL that will be installed on wn_18. Only valid when 'wn_18_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_18_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_18. Only valid when 'wn_18_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_18_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_18. Only valid when 'wn_18_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_19 VARIABLES
#####################################################################

variable "wn_19_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_19."
  type        = string
  default     = "t2.medium"
}

variable "wn_19_os_architecture" {
  description = "The operating system architecture that will be used for wn_19. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_19_linux_distribution" {
  description = "The linux distribution that will be installed on wn_19. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_19_rhel_version" {
  description = "The version of RHEL that will be installed on wn_19. Only valid when 'wn_19_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_19_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_19. Only valid when 'wn_19_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_19_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_19. Only valid when 'wn_19_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_20 VARIABLES
#####################################################################

variable "wn_20_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_20."
  type        = string
  default     = "t2.medium"
}

variable "wn_20_os_architecture" {
  description = "The operating system architecture that will be used for wn_20. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_20_linux_distribution" {
  description = "The linux distribution that will be installed on wn_20. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_20_rhel_version" {
  description = "The version of RHEL that will be installed on wn_20. Only valid when 'wn_20_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_20_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_20. Only valid when 'wn_20_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_20_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_20. Only valid when 'wn_20_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_21 VARIABLES
#####################################################################

variable "wn_21_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_21."
  type        = string
  default     = "t2.medium"
}

variable "wn_21_os_architecture" {
  description = "The operating system architecture that will be used for wn_21. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_21_linux_distribution" {
  description = "The linux distribution that will be installed on wn_21. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_21_rhel_version" {
  description = "The version of RHEL that will be installed on wn_21. Only valid when 'wn_21_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_21_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_21. Only valid when 'wn_21_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_21_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_21. Only valid when 'wn_21_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_22 VARIABLES
#####################################################################

variable "wn_22_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_22."
  type        = string
  default     = "t2.medium"
}

variable "wn_22_os_architecture" {
  description = "The operating system architecture that will be used for wn_22. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_22_linux_distribution" {
  description = "The linux distribution that will be installed on wn_22. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_22_rhel_version" {
  description = "The version of RHEL that will be installed on wn_22. Only valid when 'wn_22_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_22_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_22. Only valid when 'wn_22_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_22_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_22. Only valid when 'wn_22_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_23 VARIABLES
#####################################################################

variable "wn_23_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_23."
  type        = string
  default     = "t2.medium"
}

variable "wn_23_os_architecture" {
  description = "The operating system architecture that will be used for wn_23. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_23_linux_distribution" {
  description = "The linux distribution that will be installed on wn_23. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_23_rhel_version" {
  description = "The version of RHEL that will be installed on wn_23. Only valid when 'wn_23_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_23_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_3. Only valid when 'wn_23_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_23_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_23. Only valid when 'wn_23_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_24 VARIABLES
#####################################################################

variable "wn_24_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_24."
  type        = string
  default     = "t2.medium"
}

variable "wn_24_os_architecture" {
  description = "The operating system architecture that will be used for wn_24. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_24_linux_distribution" {
  description = "The linux distribution that will be installed on wn_24. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_24_rhel_version" {
  description = "The version of RHEL that will be installed on wn_24. Only valid when 'wn_24_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_24_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_4. Only valid when 'wn_24_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_24_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_4. Only valid when 'wn_24_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_25 VARIABLES
#####################################################################

variable "wn_25_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_25."
  type        = string
  default     = "t2.medium"
}

variable "wn_25_os_architecture" {
  description = "The operating system architecture that will be used for wn_25. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_25_linux_distribution" {
  description = "The linux distribution that will be installed on wn_25. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_25_rhel_version" {
  description = "The version of RHEL that will be installed on wn_25. Only valid when 'w'n_25_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_25_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_25. Only valid when 'wn_25_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_25_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_25. Only valid when 'wn_25_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_26 VARIABLES
#####################################################################

variable "wn_26_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_26."
  type        = string
  default     = "t2.medium"
}

variable "wn_26_os_architecture" {
  description = "The operating system architecture that will be used for wn_26. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_26_linux_distribution" {
  description = "The linux distribution that will be installed on wn_26. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_26_rhel_version" {
  description = "The version of RHEL that will be installed on wn_26. Only valid when 'wn_26_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_26_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_26. Only valid when 'wn_26_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_26_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_26. Only valid when 'wn_26_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_27 VARIABLES
#####################################################################

variable "wn_27_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_27."
  type        = string
  default     = "t2.medium"
}

variable "wn_27_os_architecture" {
  description = "The operating system architecture that will be used for wn_27. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_27_linux_distribution" {
  description = "The linux distribution that will be installed on wn_27. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_27_rhel_version" {
  description = "The version of RHEL that will be installed on wn_27. Only valid when 'wn_27_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_27_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_27. Only valid when 'wn_27_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_27_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_27. Only valid when 'wn_27_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_28 VARIABLES
#####################################################################

variable "wn_28_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_28."
  type        = string
  default     = "t2.medium"
}

variable "wn_28_os_architecture" {
  description = "The operating system architecture that will be used for wn_28. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_28_linux_distribution" {
  description = "The linux distribution that will be installed on wn_28. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_28_rhel_version" {
  description = "The version of RHEL that will be installed on wn_28. Only valid when 'wn_28_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_28_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_28. Only valid when 'wn_28_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_28_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_28. Only valid when 'wn_28_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_29 VARIABLES
#####################################################################

variable "wn_29_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_29."
  type        = string
  default     = "t2.medium"
}

variable "wn_29_os_architecture" {
  description = "The operating system architecture that will be used for wn_29. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_29_linux_distribution" {
  description = "The linux distribution that will be installed on wn_29. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_29_rhel_version" {
  description = "The version of RHEL that will be installed on wn_29. Only valid when 'wn_29_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_29_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_29. Only valid when 'wn_29_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_29_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_29. Only valid when 'wn_29_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_30 VARIABLES
#####################################################################

variable "wn_30_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_30."
  type        = string
  default     = "t2.medium"
}

variable "wn_30_os_architecture" {
  description = "The operating system architecture that will be used for wn_30. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_30_linux_distribution" {
  description = "The linux distribution that will be installed on wn_30. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_30_rhel_version" {
  description = "The version of RHEL that will be installed on wn_30. Only valid when 'wn_30_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_30_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_30. Only valid when 'wn_30_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_30_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_30. Only valid when 'wn_30_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_31 VARIABLES
#####################################################################

variable "wn_31_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_31."
  type        = string
  default     = "t2.medium"
}

variable "wn_31_os_architecture" {
  description = "The operating system architecture that will be used for wn_31. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_31_linux_distribution" {
  description = "The linux distribution that will be installed on wn_31. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_31_rhel_version" {
  description = "The version of RHEL that will be installed on wn_31. Only valid when 'wn_31_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_31_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_31. Only valid when 'wn_31_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_31_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_31. Only valid when 'wn_31_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

/*
variable "mount_swarm_data_store_to_wn_1" {
  description = "Whether or not to mount the Swarm datastore efs volume to wn_1 for persistent docker volume storage."
  type        = bool
  default     = false
}
*/

#####################################################################
# WN_32 VARIABLES
#####################################################################

variable "wn_32_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_32."
  type        = string
  default     = "t2.medium"
}

variable "wn_32_os_architecture" {
  description = "The operating system architecture that will be used for wn_32. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_32_linux_distribution" {
  description = "The linux distribution that will be installed on wn_32. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_32_rhel_version" {
  description = "The version of RHEL that will be installed on wn_32. Only valid when 'wn_32_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_32_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_32. Only valid when 'wn_32_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_32_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_32. Only valid when 'wn_32_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

/*
variable "mount_swarm_data_store_to_wn_12" {
  description = "Whether or not to mount the Swarm datastore efs volume to wn_2 for persistent docker volume storage."
  type        = bool
  default     = false
}
*/

#####################################################################
# WN_33 VARIABLES
#####################################################################

variable "wn_33_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_33."
  type        = string
  default     = "t2.medium"
}

variable "wn_33_os_architecture" {
  description = "The operating system architecture that will be used for wn_33. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_33_linux_distribution" {
  description = "The linux distribution that will be installed on wn_33. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_33_rhel_version" {
  description = "The version of RHEL that will be installed on wn_33. Only valid when 'wn_33_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_33_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_33. Only valid when 'wn_33_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_33_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_33. Only valid when 'wn_33_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_34 VARIABLES
#####################################################################

variable "wn_34_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_34."
  type        = string
  default     = "t2.medium"
}

variable "wn_34_os_architecture" {
  description = "The operating system architecture that will be used for wn_34. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_34_linux_distribution" {
  description = "The linux distribution that will be installed on wn_34. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_34_rhel_version" {
  description = "The version of RHEL that will be installed on wn_34. Only valid when 'wn_34_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_34_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_34. Only valid when 'wn_34_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_34_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_34. Only valid when 'wn_34_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_35 VARIABLES
#####################################################################

variable "wn_35_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_35."
  type        = string
  default     = "t2.medium"
}

variable "wn_35_os_architecture" {
  description = "The operating system architecture that will be used for wn_35. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_35_linux_distribution" {
  description = "The linux distribution that will be installed on wn_35. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_35_rhel_version" {
  description = "The version of RHEL that will be installed on wn_35. Only valid when 'wn_35_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_35_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_35. Only valid when 'wn_35_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_35_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_35. Only valid when 'wn_35_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_36 VARIABLES
#####################################################################

variable "wn_36_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_36."
  type        = string
  default     = "t2.medium"
}

variable "wn_36_os_architecture" {
  description = "The operating system architecture that will be used for wn_36. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_36_linux_distribution" {
  description = "The linux distribution that will be installed on wn_36. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_36_rhel_version" {
  description = "The version of RHEL that will be installed on wn_36. Only valid when 'wn_36_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_36_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_36. Only valid when 'wn_36_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_36_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_36. Only valid when 'wn_36_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_37 VARIABLES
#####################################################################

variable "wn_37_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_37."
  type        = string
  default     = "t2.medium"
}

variable "wn_37_os_architecture" {
  description = "The operating system architecture that will be used for wn_37. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_37_linux_distribution" {
  description = "The linux distribution that will be installed on wn_37. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_37_rhel_version" {
  description = "The version of RHEL that will be installed on wn_37. Only valid when 'wn_37_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_37_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_37. Only valid when 'wn_37_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_37_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_37. Only valid when 'wn_37_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_38 VARIABLES
#####################################################################

variable "wn_38_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_38."
  type        = string
  default     = "t2.medium"
}

variable "wn_38_os_architecture" {
  description = "The operating system architecture that will be used for wn_38. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_38_linux_distribution" {
  description = "The linux distribution that will be installed on wn_38. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_38_rhel_version" {
  description = "The version of RHEL that will be installed on wn_38. Only valid when 'wn_38_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_38_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_38. Only valid when 'wn_38_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_38_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_38. Only valid when 'wn_38_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_39 VARIABLES
#####################################################################

variable "wn_39_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_39."
  type        = string
  default     = "t2.medium"
}

variable "wn_39_os_architecture" {
  description = "The operating system architecture that will be used for wn_39. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_39_linux_distribution" {
  description = "The linux distribution that will be installed on wn_39. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_39_rhel_version" {
  description = "The version of RHEL that will be installed on wn_39. Only valid when 'wn_39_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_39_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_39. Only valid when 'wn_39_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_39_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_39. Only valid when 'wn_39_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_40 VARIABLES
#####################################################################

variable "wn_40_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_40."
  type        = string
  default     = "t2.medium"
}

variable "wn_40_os_architecture" {
  description = "The operating system architecture that will be used for wn_40. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_40_linux_distribution" {
  description = "The linux distribution that will be installed on wn_40. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_40_rhel_version" {
  description = "The version of RHEL that will be installed on wn_40. Only valid when 'wn_40_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_40_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_40. Only valid when 'wn_40_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_40_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_40. Only valid when 'wn_40_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_41 VARIABLES
#####################################################################

variable "wn_41_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_41."
  type        = string
  default     = "t2.medium"
}

variable "wn_41_os_architecture" {
  description = "The operating system architecture that will be used for wn_41. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_41_linux_distribution" {
  description = "The linux distribution that will be installed on wn_41. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_41_rhel_version" {
  description = "The version of RHEL that will be installed on wn_41. Only valid when 'wn_41_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_41_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_41. Only valid when 'wn_41_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_41_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_41. Only valid when 'wn_41_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_42 VARIABLES
#####################################################################

variable "wn_42_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_42."
  type        = string
  default     = "t2.medium"
}

variable "wn_42_os_architecture" {
  description = "The operating system architecture that will be used for wn_42. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_42_linux_distribution" {
  description = "The linux distribution that will be installed on wn_42. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_42_rhel_version" {
  description = "The version of RHEL that will be installed on wn_42. Only valid when 'wn_42_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_42_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_42. Only valid when 'wn_42_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_42_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_42. Only valid when 'wn_42_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_43 VARIABLES
#####################################################################

variable "wn_43_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_43."
  type        = string
  default     = "t2.medium"
}

variable "wn_43_os_architecture" {
  description = "The operating system architecture that will be used for wn_43. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_43_linux_distribution" {
  description = "The linux distribution that will be installed on wn_43. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_43_rhel_version" {
  description = "The version of RHEL that will be installed on wn_43. Only valid when 'wn_43_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_43_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_43. Only valid when 'wn_43_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_43_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_43. Only valid when 'wn_43_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_44 VARIABLES
#####################################################################

variable "wn_44_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_44."
  type        = string
  default     = "t2.medium"
}

variable "wn_44_os_architecture" {
  description = "The operating system architecture that will be used for wn_44. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_44_linux_distribution" {
  description = "The linux distribution that will be installed on wn_44. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_44_rhel_version" {
  description = "The version of RHEL that will be installed on wn_44. Only valid when 'wn_44_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_44_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_44. Only valid when 'wn_44_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_44_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_44. Only valid when 'wn_44_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_45 VARIABLES
#####################################################################

variable "wn_45_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_45."
  type        = string
  default     = "t2.medium"
}

variable "wn_45_os_architecture" {
  description = "The operating system architecture that will be used for wn_45. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_45_linux_distribution" {
  description = "The linux distribution that will be installed on wn_45. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_45_rhel_version" {
  description = "The version of RHEL that will be installed on wn_5. Only valid when 'wn_45_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_45_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_45. Only valid when 'wn_45_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_45_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_45. Only valid when 'wn_45_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_46 VARIABLES
#####################################################################

variable "wn_46_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_46."
  type        = string
  default     = "t2.medium"
}

variable "wn_46_os_architecture" {
  description = "The operating system architecture that will be used for wn_46. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_46_linux_distribution" {
  description = "The linux distribution that will be installed on wn_46. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_46_rhel_version" {
  description = "The version of RHEL that will be installed on wn_46. Only valid when 'wn_46_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_46_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_46. Only valid when 'wn_46_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_46_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_46. Only valid when 'wn_46_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_47 VARIABLES
#####################################################################

variable "wn_47_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_47."
  type        = string
  default     = "t2.medium"
}

variable "wn_47_os_architecture" {
  description = "The operating system architecture that will be used for wn_47. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_47_linux_distribution" {
  description = "The linux distribution that will be installed on wn_47. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_47_rhel_version" {
  description = "The version of RHEL that will be installed on wn_47. Only valid when 'wn_47_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_47_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_47. Only valid when 'wn_47_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_47_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_47. Only valid when 'wn_47_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_48 VARIABLES
#####################################################################

variable "wn_48_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_48."
  type        = string
  default     = "t2.medium"
}

variable "wn_48_os_architecture" {
  description = "The operating system architecture that will be used for wn_48. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_48_linux_distribution" {
  description = "The linux distribution that will be installed on wn_48. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_48_rhel_version" {
  description = "The version of RHEL that will be installed on wn_48. Only valid when 'wn_48_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_48_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_48. Only valid when 'wn_48_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_48_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_48. Only valid when 'wn_48_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_49 VARIABLES
#####################################################################

variable "wn_49_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_49."
  type        = string
  default     = "t2.medium"
}

variable "wn_49_os_architecture" {
  description = "The operating system architecture that will be used for wn_49. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_49_linux_distribution" {
  description = "The linux distribution that will be installed on wn_49. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_49_rhel_version" {
  description = "The version of RHEL that will be installed on wn_49. Only valid when 'wn_49_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_49_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_49. Only valid when 'wn_49_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_49_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_49. Only valid when 'wn_49_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_50 VARIABLES
#####################################################################

variable "wn_50_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_50."
  type        = string
  default     = "t2.medium"
}

variable "wn_50_os_architecture" {
  description = "The operating system architecture that will be used for wn_50. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_50_linux_distribution" {
  description = "The linux distribution that will be installed on wn_50. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_50_rhel_version" {
  description = "The version of RHEL that will be installed on wn_50. Only valid when 'wn_50_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_50_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_50. Only valid when 'wn_50_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_50_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_50. Only valid when 'wn_50_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

#####################################################################
# WN_GRP_1 VARIABLES
#####################################################################

variable "wn_grp_1_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_1 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_1_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_1 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_1_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_1 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_1_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_1 nodes. Only valid when wn_grp_1_linux_distribution is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_1_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_1 nodes. Only valid when wn_grp_1_linux_distribution is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_1_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_1 nodes. Only valid when wn_grp_1_linux_distribution is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_1_max_capacity" {
  description = "The maximum number of nodes in wn_grp_1."
  type        = number
  default     = 1
}

variable "wn_grp_1_min_capacity" {
  description = "The minimum number of nodes in wn_grp_1."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_2 VARIABLES
#####################################################################

variable "wn_grp_2_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_2 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_2_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_2 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_2_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_2 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_2_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_2 nodes. Only valid when wn_grp_2_linux_distribution is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_2_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_2 nodes. Only valid when wn_grp_2_linux_distribution is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_2_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_2 nodes. Only valid when wn_grp_2_linux_distribution is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_2_max_capacity" {
  description = "The maximum number of nodes in wn_grp_2."
  type        = number
  default     = 1
}

variable "wn_grp_2_min_capacity" {
  description = "The minimum number of nodes in wn_grp_2."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_3 VARIABLES
#####################################################################

variable "wn_grp_3_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_3 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_3_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_3 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_3_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_3 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_3_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_3 nodes. Only valid when wn_grp_3_linux_distribution is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_3_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_3 nodes. Only valid when wn_grp_3_linux_distribution is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_3_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_3 nodes. Only valid when wn_grp_3_linux_distribution is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_3_max_capacity" {
  description = "The maximum number of nodes in wn_grp_3."
  type        = number
  default     = 1
}

variable "wn_grp_3_min_capacity" {
  description = "The minimum number of nodes in wn_grp_3."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_4 VARIABLES
#####################################################################

variable "wn_grp_4_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_4 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_4_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_4 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_4_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_4 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_4_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_4 nodes. Only valid when wn_grp_4_linux_distribution is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_4_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_4 nodes. Only valid when wn_grp_4_linux_distribution is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_4_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_4 nodes. Only valid when wn_grp_4_linux_distribution is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_4_max_capacity" {
  description = "The maximum number of nodes in wn_grp_4."
  type        = number
  default     = 1
}

variable "wn_grp_4_min_capacity" {
  description = "The minimum number of nodes in wn_grp_4."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_5 VARIABLES
#####################################################################

variable "wn_grp_5_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_5 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_5_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_5 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_5_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_5 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_5_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_5 nodes. Only valid when 'wn_grp_5_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_5_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_5 nodes. Only valid when wn_grp_5_linux_distribution is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_5_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_5 nodes. Only valid when wn_grp_5_linux_distribution is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_5_max_capacity" {
  description = "The maximum number of nodes in wn_grp_5."
  type        = number
  default     = 1
}

variable "wn_grp_5_min_capacity" {
  description = "The minimum number of nodes in wn_grp_5."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_6 VARIABLES
#####################################################################

variable "wn_grp_6_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_6 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_6_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_6 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_6_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_6 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_6_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_6 nodes. Only valid when wn_grp_6_linux_distribution is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_6_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_6 nodes. Only valid when 'wn_grp_6_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_6_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_6 nodes. Only valid when 'wn_grp_6_linux_distribution' is ubuntu. Valid values are 'server' and 'minimal-server'."
  type        = string
  default     = "server"
}

variable "wn_grp_6_max_capacity" {
  description = "The maximum number of nodes in wn_grp_6."
  type        = number
  default     = 1
}

variable "wn_grp_6_min_capacity" {
  description = "The minimum number of nodes in wn_grp_6."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_7 VARIABLES
#####################################################################

variable "wn_grp_7_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_7 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_7_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_7 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_7_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_7 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_7_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_7 nodes. Only valid when 'wn_grp_7_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_7_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_7 nodes. Only valid when 'wn_grp_7_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_7_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_7 nodes. Only valid when 'wn_grp_7_linux_distribution' is ubuntu. Valid values are 'server' and 'minimal-server'."
  type        = string
  default     = "server"
}

variable "wn_grp_7_max_capacity" {
  description = "The maximum number of nodes in wn_grp_7."
  type        = number
  default     = 1
}

variable "wn_grp_7_min_capacity" {
  description = "The minimum number of nodes in wn_grp_7."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_8 VARIABLES
#####################################################################

variable "wn_grp_8_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_8 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_8_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_8 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_8_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_8 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_8_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_8 nodes. Only valid when 'wn_grp_8_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_8_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_8 nodes. Only valid when 'wn_grp_8_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_8_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_8 nodes. Only valid when 'wn_grp_8_linux_distribution' is ubuntu. Valid values are 'server' and 'minimal-server'."
  type        = string
  default     = "server"
}

variable "wn_grp_8_max_capacity" {
  description = "The maximum number of nodes in wn_grp_8."
  type        = number
  default     = 1
}

variable "wn_grp_8_min_capacity" {
  description = "The minimum number of nodes in wn_grp_8."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_9 VARIABLES
#####################################################################

variable "wn_grp_9_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_9 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_9_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_9 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_9_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_9 nodes. Accepted values are 'ubuntu', 'rhel' and 'amazon-linux' (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_9_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_9 nodes. Only valid when 'wn_grp_9_linux_distribution' is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_9_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_9 nodes. Only valid when 'wn_grp_9_linux_distribution' is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_9_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_9 nodes. Only valid when 'wn_grp_9_linux_distribution' is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_9_max_capacity" {
  description = "The maximum number of nodes in wn_grp_9."
  type        = number
  default     = 1
}

variable "wn_grp_9_min_capacity" {
  description = "The minimum number of nodes in wn_grp_9."
  type        = number
  default     = 1
}

#####################################################################
# WN_GRP_10 VARIABLES
#####################################################################

variable "wn_grp_10_instance_type" {
  description = "The ec2 instance type that will be used to provision wn_grp_10 nodes."
  type        = string
  default     = "t2.medium"
}

variable "wn_grp_10_os_architecture" {
  description = "The operating system architecture that will be used for wn_grp_10 nodes. Accepted values are x86_64 (or amd64) and arm64."
  type        = string
  default     = "amd64"
}

variable "wn_grp_10_linux_distribution" {
  description = "The linux distribution that will be installed on wn_grp_10 nodes. Accepted values are ubuntu, rhel and amazon-linux (2.0)."
  type        = string
  default     = "ubuntu"
}

variable "wn_grp_10_rhel_version" {
  description = "The version of RHEL that will be installed on wn_grp_10 nodes. Only valid when wn_grp_10_linux_distribution is rhel. Valid values are 9.2.0, 8.8.0 (in x86_64 only), 8.4.0 (in arm64 only), 7.7, 7.2, 7.1 and 7.0 (all in x86_64 only) and 7.6 (in arm64 only)."
  type        = string
  default     = "8.8.0"
}

variable "wn_grp_10_ubuntu_version" {
  description = "The version of Ubuntu that will be installed on wn_grp_10 nodes. Only valid when wn_grp_10_linux_distribution is ubuntu. Valid values are 23.04, 22.10, 22.04, 20.04 and 18.04."
  type        = string
  default     = "20.04"
}

variable "wn_grp_10_ubuntu_server_type" {
  description = "The type of Ubuntu server that will be installed on wn_grp_10 nodes. Only valid when wn_grp_10_linux_distribution is ubuntu. Valid values are server and minimal-server."
  type        = string
  default     = "server"
}

variable "wn_grp_10_max_capacity" {
  description = "The maximum number of nodes in wn_grp_10."
  type        = number
  default     = 1
}

variable "wn_grp_10_min_capacity" {
  description = "The minimum number of nodes in wn_grp_10."
  type        = number
  default     = 1
}

######################################## APACHEPLAYGROUND™ ########################################
