
output "node_grp_asg" {
  description = "The ID of the worker node group's ASG."
  value       = aws_autoscaling_group.node_grp.id
}

output "node_grp_sg" {
  description = "The ID of the worker node group's security group."
  value       = aws_security_group.node_grp_sg.id
}

output "node_grp_states" {
  description = "The states of the nodes in the worker node group."
  value       = data.aws_instances.node_grp.instance_state_names
}

######################################## APACHEPLAYGROUND™ ########################################
