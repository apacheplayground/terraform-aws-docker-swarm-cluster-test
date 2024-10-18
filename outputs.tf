
#####################################################################
# NODES
#####################################################################

output "num_of_mn" {
  description = "The number of manager nodes in the swarm cluster."
  value       = var.num_of_mn
}

output "num_of_wn" {
  description = "The number of static single worker nodes in the swarm cluster."
  value       = var.num_of_wn
}

output "num_of_wn_grps" {
  description = "The number of elastic worker node groups in the swarm cluster."
  value       = var.num_of_wn_grps
}

#####################################################################
# DASHBOARDS
#####################################################################

output "swarm_admin_dashboard_url" {
  description = "The URL to the swarm cluster's Portainer dashboard."
  value       = local.portainer_url
}

output "portainer_default_admin_password" {
  description = "The default password of the portainer (default) admin user."
  value       = local.portainer_dap
}

#####################################################################
# MN_1
#####################################################################

output "mn_1_state" {
  description = "The state of mn_1."
  value       = local.mn_1_state
}

output "mn_1_public_eip" {
  description = "The public EIP address of mn_1."
  value       = local.mn_1_public_eip
}

#####################################################################
# MN_2
#####################################################################

output "mn_2_state" {
  description = "The state of mn_2."
  value       = local.mn_2_state
}

output "mn_2_public_eip" {
  description = "The public EIP address of mn_2."
  value       = local.mn_2_public_eip
}

#####################################################################
# MN_3
#####################################################################

output "mn_3_state" {
  description = "The state of mn_3."
  value       = local.mn_3_state
}

output "mn_3_public_eip" {
  description = "The public EIP address of mn_3."
  value       = local.mn_3_public_eip
}

#####################################################################
# MN_4
#####################################################################

output "mn_4_state" {
  description = "The state of mn_4."
  value       = local.mn_4_state
}

output "mn_4_public_eip" {
  description = "The public EIP address of mn_4."
  value       = local.mn_4_public_eip
}

#####################################################################
# MN_5
#####################################################################

output "mn_5_state" {
  description = "The state of mn_5."
  value       = local.mn_5_state
}

output "mn_5_public_eip" {
  description = "The public EIP address of mn_5."
  value       = local.mn_5_public_eip
}

#####################################################################
# MN_6
#####################################################################

output "mn_6_state" {
  description = "The state of mn_6."
  value       = local.mn_6_state
}

output "mn_6_public_eip" {
  description = "The public EIP address of mn_6."
  value       = local.mn_6_public_eip
}

#####################################################################
# MN_7
#####################################################################

output "mn_7_state" {
  description = "The state of mn_7."
  value       = local.mn_7_state
}

output "mn_7_public_eip" {
  description = "The public EIP address of mn_7."
  value       = local.mn_7_public_eip
}

######################################## APACHEPLAYGROUND™ ########################################
