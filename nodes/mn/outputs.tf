
output "node_asg" {
  description = "The ID of the mn's ASG."
  value       = local.node_asg #aws_autoscaling_group.node.id
}

output "node_sg" {
  description = "The ID of the mn's security group."
  value       = aws_security_group.node_sg.id
}

output "node_public_eip" {
  description = "The public EIP address of the mn."
  value       = aws_eip.node_public_eip.public_ip
}

output "node_state" {
  description = "The state of the mn."
  value       = local.node_state #data.aws_instance.node.instance_state
}

######################################## APACHEPLAYGROUND™ ########################################
