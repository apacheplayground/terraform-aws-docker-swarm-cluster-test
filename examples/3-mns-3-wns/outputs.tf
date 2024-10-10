
#####################################################################
# NODES
#####################################################################

output "num_of_mn" {
  description = "The number of manager nodes in the swarm cluster."
  value       = module.dswm_cluster.num_of_mn
}

output "num_of_wn" {
  description = "The number of static single worker nodes in the swarm cluster."
  value       = module.dswm_cluster.num_of_wn
}

output "num_of_wn_grps" {
  description = "The number of elastic worker node groups in the swarm cluster."
  value       = module.dswm_cluster.num_of_wn_grps
}

#####################################################################
# DASHBOARDS
#####################################################################

output "swarm_portainer_url" {
  description = "The URL to the swarm cluster's Portainer dashboard."
  value       = module.dswm_cluster.swarm_portainer_url
}

output "swarm_prom_url" {
  description = "The URL to the swarm cluster's Prometheus dashboard."
  value       = module.dswm_cluster.swarm_prom_url
}

output "swarm_grafana_url" {
  description = "The URL to the swarm cluster's Grafana dashboard."
  value       = module.dswm_cluster.swarm_grafana_url
}

output "swarm_alertmanager_url" {
  description = "The URL to the swarm cluster's Alertmanager dashboard."
  value       = module.dswm_cluster.swarm_alertmanager_url
}

#####################################################################
# MN_1
#####################################################################

output "mn_1_state" {
  description = "The state of mn_1."
  value       = module.dswm_cluster.mn_1_state
}

output "mn_1_public_eip" {
  description = "The public EIP address of mn_1."
  value       = module.dswm_cluster.mn_1_public_eip
}

#####################################################################
# MN_2
#####################################################################

output "mn_2_state" {
  description = "The state of mn_2."
  value       = module.dswm_cluster.mn_2_state
}

output "mn_2_public_eip" {
  description = "The public EIP address of mn_2."
  value       = module.dswm_cluster.mn_2_public_eip
}

#####################################################################
# MN_3
#####################################################################

output "mn_3_state" {
  description = "The state of mn_3."
  value       = module.dswm_cluster.mn_3_state
}

output "mn_3_public_eip" {
  description = "The public EIP address of mn_3."
  value       = module.dswm_cluster.mn_3_public_eip
}

#####################################################################
# MN_4
#####################################################################

output "mn_4_state" {
  description = "The state of mn_4."
  value       = module.dswm_cluster.mn_4_state
}

output "mn_4_public_eip" {
  description = "The public EIP address of mn_4."
  value       = module.dswm_cluster.mn_4_public_eip
}

#####################################################################
# MN_5
#####################################################################

output "mn_5_state" {
  description = "The state of mn_5."
  value       = module.dswm_cluster.mn_5_state
}

output "mn_5_public_eip" {
  description = "The public EIP address of mn_5."
  value       = module.dswm_cluster.mn_5_public_eip
}

######################################## APACHEPLAYGROUND™ ########################################
