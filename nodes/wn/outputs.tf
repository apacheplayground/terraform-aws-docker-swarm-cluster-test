
output "node_asg" {
  description = "The ID of the worker node group's ASG."
  value       = aws_autoscaling_group.node.id
}

output "node_sg" {
  description = "The ID of the worker node group's security group."
  value       = aws_security_group.node_sg.id
}

output "node_state" {
  description = "The states of the nodes in the worker node group."
  value       = data.aws_instance.node.instance_state
}

######################################## APACHEPLAYGROUND™ ########################################
