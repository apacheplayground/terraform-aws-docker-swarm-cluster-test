
#####################################################################
# GLOBAL LOCALS
#####################################################################

locals {
  name_prefix = "${var.swarm_name}-wn-${var.wn_index}"
  name_suffix = var.environment == "" || var.environment == "default" ? "" : "-${var.environment}"
}

#####################################################################
# NODE ASG
#####################################################################

resource "aws_autoscaling_group" "node" {
  name                = "${local.name_prefix}-asg${local.name_suffix}"
  vpc_zone_identifier = var.node_subnets

  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true

  max_size         = 1
  desired_capacity = 1
  min_size         = 1

  lifecycle {
    ignore_changes = [load_balancers, target_group_arns]
  }

  launch_template {
    id      = aws_launch_template.node_lt.id
    version = aws_launch_template.node_lt.latest_version
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
    value               = var.node_linux_distribution
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = var.environment
    propagate_at_launch = true
  }
}

#####################################################################
# ASG LAUNCH TEMPLATE
#####################################################################

locals {
  node_user_data_file           = "${path.module}/user-data/${var.node_linux_distribution}/user-data.tftpl"
  node_user_data_functions_file = "${path.module}/user-data/${var.node_linux_distribution}/user-data-functions.sh"
  node_name                     = "${local.name_prefix}${local.name_suffix}"
}

resource "aws_launch_template" "node_lt" {
  name          = "${local.name_prefix}-lt${local.name_suffix}"
  image_id      = local.node_ami
  instance_type = var.node_instance_type
  key_name      = module.node_key_pair.key_pair_name

  network_interfaces {
    security_groups             = [aws_security_group.node_sg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(templatefile(local.node_user_data_file, {
    swarm_name = var.swarm_name
    node_name  = local.node_name

    swarm_config_files_s3_bucket_name  = var.swarm_config_files_s3_bucket_name
    node_user_data_functions_s3_object = aws_s3_object.node_user_data_functions_file.key

    num_of_mn = var.num_of_mn

    mn_1_private_eip_name = var.mn_1_private_eip_name
    mn_2_private_eip_name = var.mn_2_private_eip_name
    mn_3_private_eip_name = var.mn_3_private_eip_name
    mn_4_private_eip_name = var.mn_4_private_eip_name
    mn_5_private_eip_name = var.mn_5_private_eip_name
    mn_6_private_eip_name = var.mn_6_private_eip_name
    mn_7_private_eip_name = var.mn_7_private_eip_name

    grant_swarm_services_iam_access = var.grant_swarm_services_iam_access

    enable_node_status_notification = var.enable_node_status_notification
    slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.node_instance_profile.arn
  }

  lifecycle {
    create_before_destroy = true
  }
}

#####################################################################
# NODE USER DATA FUNCTIONS FILE
#####################################################################

resource "aws_s3_object" "node_user_data_functions_file" {
  bucket = var.swarm_config_files_s3_bucket
  key    = "${local.node_name}-user-data-functions.sh"
  source = local.node_user_data_functions_file
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

resource "aws_security_group" "node_sg" {
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
  security_group_id = aws_security_group.node_sg.id
  cidr_blocks       = var.node_ssh_access_cidr_block
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
  security_group_id = aws_security_group.node_sg.id
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
  security_group_id = aws_security_group.node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

#####################################################################
# AMI LOCALS
#####################################################################

locals {
  node_ami                   = var.node_linux_distribution == "ubuntu" ? data.aws_ami.ubuntu[0].id : (var.node_linux_distribution == "rhel" ? data.aws_ami.rhel[0].id : data.aws_ami.amazon_linux[0].id)
  ubuntu_os_architecture     = var.node_os_architecture == "x86_64" || var.node_os_architecture == "amd64" ? "amd64" : var.node_os_architecture
  rhel_os_architecture       = var.node_os_architecture == "x86_64" || var.node_os_architecture == "amd64" ? "x86_64" : var.node_os_architecture
  amzn_linux_os_architecture = var.node_os_architecture == "x86_64" || var.node_os_architecture == "amd64" ? "x86_64" : var.node_os_architecture
  amzn_linux_version         = "2.0"
  rhel_version               = var.node_rhel_version
  ubuntu_version             = var.node_ubuntu_version
  ubuntu_server_type         = var.node_ubuntu_server_type
  ubuntu_release_name        = local.ubuntu_version == "23.04" ? "lunar" : (local.ubuntu_version == "22.10" ? "kinetic" : (local.ubuntu_version == "22.04" ? "jammy" : (local.ubuntu_version == "20.04" ? "focal" : "bionic")))
  ubuntu_ami_owners          = local.ubuntu_version == "23.04" || local.ubuntu_version == "22.10" || local.ubuntu_version == "22.04" || local.ubuntu_version == "20.04" ? "099720109477" : "679593333241"
}

#####################################################################
# AMI UBUNTU
#####################################################################

data "aws_ami" "ubuntu" {
  count = var.node_linux_distribution == "ubuntu" ? 1 : 0

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
  count = var.node_linux_distribution == "rhel" ? 1 : 0

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
  count = var.node_linux_distribution == "amazon-linux" ? 1 : 0

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

resource "aws_iam_instance_profile" "node_instance_profile" {
  name = "${local.name_prefix}-ins-prof${local.name_suffix}"
  role = aws_iam_role.node_role.id
}

resource "aws_iam_role" "node_role" {
  name               = "${local.name_prefix}-role${local.name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = {
    Name = "${local.name_prefix}-role${local.name_suffix}"
  }
}

data "aws_iam_policy_document" "node_assume_role" {
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

resource "aws_iam_role_policy" "node_policy" {
  name   = "${local.name_prefix}-rp${local.name_suffix}"
  role   = aws_iam_role.node_role.id
  policy = data.aws_iam_policy_document.node_permissions.json
}

data "aws_iam_policy_document" "node_permissions" {
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
}

#####################################################################
# NODE STATE
#####################################################################

data "aws_instance" "node" {
  depends_on = [aws_autoscaling_group.node]

  filter {
    name   = "tag:Name"
    values = ["${local.name_prefix}${local.name_suffix}"]
  }

  filter {
    name   = "instance.group-id"
    values = [aws_security_group.node_sg.id]
  }

  filter {
    name   = "key-name"
    values = [module.node_key_pair.key_pair_name]
  }
}

#####################################################################
# NODE KEY PAIR
#####################################################################

module "node_key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name           = "${local.name_prefix}-key${local.name_suffix}"
  create_private_key = true
}

resource "local_sensitive_file" "node_private_key" {
  content         = module.node_key_pair.private_key_pem
  filename        = "${local.name_prefix}${local.name_suffix}.pem"
  file_permission = "400"
}

#####################################################################
# NODE PRIVATE KEY BACKUP
#####################################################################

resource "aws_ssm_parameter" "node_private_key" {
  count = var.backup_node_ssh_private_key == true ? 1 : 0

  name  = "${local.name_prefix}-priv-key${local.name_suffix}"
  type  = "SecureString"
  value = local_sensitive_file.node_private_key.content
}

#####################################################################
# WAIT FOR NODE TO JOIN CLUSTER
#####################################################################

resource "time_sleep" "node_joining_cluster" {
  depends_on = [aws_autoscaling_group.node]

  create_duration = "120s"
}

######################################## APACHEPLAYGROUND™ ########################################
