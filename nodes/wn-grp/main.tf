
#####################################################################
# GLOBAL LOCALS
#####################################################################

locals {
  name_prefix = "${var.swarm_name}-wn-grp-${var.node_grp_index}"
  name_suffix = var.environment == "" || var.environment == "default" ? "" : "-${var.environment}"
}

#####################################################################
# ASG
#####################################################################

resource "aws_autoscaling_group" "node_grp" {
  name                = "${local.name_prefix}-asg${local.name_suffix}"
  vpc_zone_identifier = var.node_grp_subnets

  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  max_size         = var.node_grp_max_capacity
  desired_capacity = var.node_grp_min_capacity
  min_size         = var.node_grp_min_capacity

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

  launch_template {
    id      = aws_launch_template.node_grp_lt.id
    version = aws_launch_template.node_grp_lt.latest_version
  }

  tag {
    key                 = "Terraform"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}${local.name_suffix}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Distro"
    value               = var.node_grp_linux_distribution
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = var.environment
    propagate_at_launch = true
  }
}

#####################################################################
# ASG SCALE UP POLICY
#####################################################################

resource "aws_autoscaling_policy" "node_grp_scale_up" {
  name                   = "${local.name_prefix}-asg${local.name_suffix}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.node_grp.name
  policy_type            = "TargetTrackingScaling"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

#####################################################################
# ASG SCALE DOWN POLICY
#####################################################################

resource "aws_autoscaling_policy" "node_grp_scale_down" {
  name                   = "${local.name_prefix}-asg${local.name_suffix}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.node_grp.name
  policy_type            = "TargetTrackingScaling"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 30.0
  }
}

#####################################################################
# ASG LAUNCH TEMPLATE
#####################################################################

locals {
  node_grp_user_data_file           = "${path.module}/user-data/${var.node_grp_linux_distribution}/user-data.tftpl"
  node_grp_user_data_functions_file = "${path.module}/user-data/${var.node_grp_linux_distribution}/user-data-functions.sh"
  node_grp_name                     = "${local.name_prefix}${local.name_suffix}"
}

resource "aws_launch_template" "node_grp_lt" {
  name          = "${local.name_prefix}-lt${local.name_suffix}"
  image_id      = local.node_grp_ami
  instance_type = var.node_grp_instance_type
  key_name      = module.node_grp_key_pair.key_pair_name

  network_interfaces {
    security_groups             = [aws_security_group.node_grp_sg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile(local.node_grp_user_data_file, {
    swarm_name    = var.swarm_name
    node_grp_name = local.node_grp_name

    swarm_config_files_s3_bucket_name      = var.swarm_config_files_s3_bucket_name
    node_grp_user_data_functions_s3_object = aws_s3_object.node_grp_user_data_functions_file.key

    num_of_mn = var.num_of_mn

    mn_1_private_eip_name = var.mn_1_private_eip_name
    mn_2_private_eip_name = var.mn_2_private_eip_name
    mn_3_private_eip_name = var.mn_3_private_eip_name
    mn_4_private_eip_name = var.mn_4_private_eip_name
    mn_5_private_eip_name = var.mn_5_private_eip_name
    mn_6_private_eip_name = var.mn_6_private_eip_name
    mn_7_private_eip_name = var.mn_7_private_eip_name

    grant_swarm_services_iam_access = var.grant_swarm_services_iam_access

    enable_node_grp_status_notification = var.enable_node_grp_status_notification
    slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.node_grp_instance_profile.arn
  }

  lifecycle {
    create_before_destroy = true
  }
}

#####################################################################
# NODE USER DATA FUNCTIONS FILE
#####################################################################

resource "aws_s3_object" "node_grp_user_data_functions_file" {
  bucket = var.swarm_config_files_s3_bucket
  key    = "${local.node_grp_name}-user-data-functions.sh"
  source = local.node_grp_user_data_functions_file
}

#####################################################################
# NODE GROUP SECURITY GROUP
#####################################################################

locals {
  swarm_ingress = {
    "docker daemon swarm mode ingress"           = { port = 2376, protocol = "tcp" }
    "overlay network node discovery tcp ingress" = { port = 7946, protocol = "tcp" }
    "overlay network node discovery udp ingress" = { port = 7946, protocol = "udp" }
    "overlay network ingress"                    = { port = 4789, protocol = "udp" }
  }
}

resource "aws_security_group" "node_grp_sg" {
  name   = "${local.name_prefix}-sg${local.name_suffix}"
  vpc_id = var.swarm_vpc_id

  dynamic "ingress" {
    iterator = ingress
    for_each = local.swarm_ingress

    content {
      description = ingress.key
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [var.swarm_vpc_cidr]
    }
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform = "true"
    Name      = "${local.name_prefix}-sg${local.name_suffix}"
    Env       = var.environment
  }
}

#####################################################################
# INGRESS RULES FOR SSH ACCESS
#####################################################################

resource "aws_security_group_rule" "ssh_ingress" {
  type              = "ingress"
  description       = "Ssh ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.node_grp_sg.id
  cidr_blocks       = var.node_grp_ssh_access_cidr_block
}

#####################################################################
# INGRESS RULE FOR PORTAINER AGENT OVERLAY NETWORK
#####################################################################

locals {
  portainer_agent_ingress_port = 9001
}

resource "aws_security_group_rule" "portainer_agent_network_ingress" {
  type              = "ingress"
  description       = "Portainer-agent network ingress"
  from_port         = local.portainer_agent_ingress_port
  to_port           = local.portainer_agent_ingress_port
  protocol          = "tcp"
  security_group_id = aws_security_group.node_grp_sg.id
  cidr_blocks       = [var.swarm_vpc_cidr]
}

#####################################################################
# INGRESS RULE FOR NODE PORT SERVICES
#####################################################################

resource "aws_security_group_rule" "node_port_services_ingress" {
  type              = "ingress"
  description       = "Node port services ingress"
  from_port         = var.node_port_services_ingress_from_port
  to_port           = var.node_port_services_ingress_to_port
  protocol          = "tcp"
  security_group_id = aws_security_group.node_grp_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

#####################################################################
# AMI LOCALS
#####################################################################

locals {
  node_grp_ami               = var.node_grp_linux_distribution == "ubuntu" ? data.aws_ami.ubuntu[0].id : (var.node_grp_linux_distribution == "rhel" ? data.aws_ami.rhel[0].id : data.aws_ami.amazon_linux[0].id)
  ubuntu_os_architecture     = var.node_grp_os_architecture == "x86_64" || var.node_grp_os_architecture == "amd64" ? "amd64" : var.node_grp_os_architecture
  rhel_os_architecture       = var.node_grp_os_architecture == "x86_64" || var.node_grp_os_architecture == "amd64" ? "x86_64" : var.node_grp_os_architecture
  amzn_linux_os_architecture = var.node_grp_os_architecture == "x86_64" || var.node_grp_os_architecture == "amd64" ? "x86_64" : var.node_grp_os_architecture
  amzn_linux_version         = "2.0"
  rhel_version               = var.node_grp_rhel_version
  ubuntu_version             = var.node_grp_ubuntu_version
  ubuntu_server_type         = var.node_grp_ubuntu_server_type
  ubuntu_release_name        = local.ubuntu_version == "23.04" ? "lunar" : (local.ubuntu_version == "22.10" ? "kinetic" : (local.ubuntu_version == "22.04" ? "jammy" : (local.ubuntu_version == "20.04" ? "focal" : "bionic")))
  ubuntu_ami_owners          = local.ubuntu_version == "23.04" || local.ubuntu_version == "22.10" || local.ubuntu_version == "22.04" || local.ubuntu_version == "20.04" ? "099720109477" : "679593333241"
}

#####################################################################
# AMI UBUNTU
#####################################################################

data "aws_ami" "ubuntu" {
  count = var.node_grp_linux_distribution == "ubuntu" ? 1 : 0

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-${local.ubuntu_release_name}-${local.ubuntu_version}-${local.ubuntu_os_architecture}-${local.ubuntu_server_type}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [local.ubuntu_ami_owners] # cannonical
}

#####################################################################
# AMI RHEL
#####################################################################

data "aws_ami" "rhel" {
  count = var.node_grp_linux_distribution == "rhel" ? 1 : 0

  most_recent = true

  filter {
    name   = "name"
    values = ["RHEL-${local.rhel_version}_*-${local.rhel_os_architecture}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["309956199498"] # red hat inc
}

#####################################################################
# AMI AMAZON-LINUX
#####################################################################

data "aws_ami" "amazon_linux" {
  count = var.node_grp_linux_distribution == "amazon-linux" ? 1 : 0

  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-${local.amzn_linux_version}.*-${local.amzn_linux_os_architecture}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # aws
}

#####################################################################
# INSTANCE ROLE
#####################################################################

resource "aws_iam_instance_profile" "node_grp_instance_profile" {
  name = "${local.name_prefix}-ins-prof${local.name_suffix}"
  role = aws_iam_role.node_grp_role.id
}

resource "aws_iam_role" "node_grp_role" {
  name               = "${local.name_prefix}-role${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.node_grp_assume_role.json

  tags = {
    Name = "${local.name_prefix}-role${local.name_suffix}"
  }
}

data "aws_iam_policy_document" "node_grp_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    effect = "Allow"
  }
}

#####################################################################
# ROLE PERMISSIONS
#####################################################################

resource "aws_iam_role_policy" "node_grp_role_policy" {
  name   = "${local.name_prefix}-rp${local.name_suffix}"
  role   = aws_iam_role.node_grp_role.id
  policy = data.aws_iam_policy_document.node_grp_permissions.json
}

data "aws_iam_policy_document" "node_grp_permissions" {
  statement {
    sid       = "s3"
    actions   = ["s3:ListBucket", "s3:GetObject", ]
    effect    = "Allow"
    resources = ["*", ]
  }

  statement {
    sid       = "ssmparamterstore"
    actions   = ["ssm:GetParameter", ]
    effect    = "Allow"
    resources = ["*", ]
  }

  statement {
    sid       = "ec2autoscaling"
    actions   = ["autoscaling:DescribeAutoScalingGroups", ]
    effect    = "Allow"
    resources = ["*", ]
  }
}

#####################################################################
# INSTANCE STATES
#####################################################################

data "aws_instances" "node_grp" {
  depends_on = [aws_autoscaling_group.node_grp]

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}${local.name_suffix}"]
  }

  filter {
    name   = "instance.group-id"
    values = [aws_security_group.node_grp_sg.id]
  }

  filter {
    name   = "key-name"
    values = [module.node_grp_key_pair.key_pair_name]
  }
}

#####################################################################
# KEY PAIR
#####################################################################

module "node_grp_key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "${local.name_prefix}-key${local.name_suffix}"
  create_private_key = true
}

resource "local_sensitive_file" "node_grp_private_key" {
  content         = module.node_grp_key_pair.private_key_pem
  filename        = "${local.name_prefix}${local.name_suffix}.pem"
  file_permission = "400"
}

#####################################################################
# PRIVATE KEY BACKUP
#####################################################################

resource "aws_ssm_parameter" "node_grp_private_key" {
  count = var.backup_node_grp_ssh_private_key == true ? 1 : 0

  name  = "${local.name_prefix}-priv-key${local.name_suffix}"
  type  = "SecureString"
  value = local_sensitive_file.node_grp_private_key.content
}

#####################################################################
# WAIT FOR NODE GRP TO JOIN CLUSTER
#####################################################################

resource "time_sleep" "nodes_joining_cluster" {
  depends_on = [aws_autoscaling_group.node_grp]

  create_duration = "120s"
}

######################################## APACHEPLAYGROUND™ ########################################
