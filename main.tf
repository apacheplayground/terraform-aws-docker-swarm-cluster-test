
#####################################################################
# LOCALS  #####
#####################################################################

locals {
  name_prefix = var.swarm_name
  name_suffix = var.environment == "" || var.environment == "default" ? "" : "-${var.environment}"

  swarm_type = "public"

  enable_swarm_services_autoscaling = true
  grant_swarm_services_iam_access   = true
}

#####################################################################
# SWARM VPC (EXISTING)
#####################################################################

data "aws_vpc" "swarm_vpc" {
  count = var.create_swarm_vpc == false ? 1 : 0

  id = var.swarm_vpc_id
}

data "aws_subnets" "swarm_vpc_public_subnets" {
  count = var.create_swarm_vpc == false ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.swarm_vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

data "aws_subnets" "swarm_vpc_private_subnets" {
  count = var.create_swarm_vpc == false ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.swarm_vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

#####################################################################
# SWARM VPC (NEW)
#####################################################################

locals {
  swarm_vpc_id   = var.create_swarm_vpc == true ? module.swarm_vpc[0].vpc_id : var.swarm_vpc_id
  swarm_vpc_cidr = var.create_swarm_vpc == true ? var.swarm_vpc_cidr : data.aws_vpc.swarm_vpc[0].cidr_block
}

module "swarm_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  #version = "3.14.2"

  count = var.create_swarm_vpc == true ? 1 : 0

  name = "${local.name_prefix}-vpc${local.name_suffix}"
  cidr = var.swarm_vpc_cidr

  azs             = ["${var.swarm_vpc_region}a", "${var.swarm_vpc_region}b", "${var.swarm_vpc_region}c", ]
  public_subnets  = var.swarm_vpc_public_subnets_cidrs
  private_subnets = var.swarm_vpc_private_subnets_cidrs

  create_igw           = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    Name = "${local.name_prefix}-vpc-pub-sn${local.name_suffix}"
  }

  private_subnet_tags = {
    Name = "${local.name_prefix}-vpc-priv-sn${local.name_suffix}"
  }

  tags = {
    Terraform = "true"
    Name      = "${local.name_prefix}-vpc${local.name_suffix}"
  }
}

#####################################################################
# SWARM DATA STORE
#####################################################################

locals {
  swarm_data_store_subnets = var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets : (var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets : (var.create_swarm_vpc == false && local.swarm_type == "public" ? data.aws_subnets.swarm_vpc_public_subnets[0].ids : (var.create_swarm_vpc == false && local.swarm_type == "private" ? data.aws_subnets.swarm_vpc_private_subnets[0].ids : [])))
  swarm_data_store_dns     = aws_efs_file_system.swarm_data_store.dns_name
  swarm_data_store_sg      = aws_security_group.swarm_data_store_sg.id
}

resource "aws_efs_file_system" "swarm_data_store" {
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = "true"

  tags = {
    Name = "${local.name_prefix}-data-store${local.name_suffix}"
  }
}

resource "aws_efs_access_point" "swarm_data_store_ap" {
  file_system_id = aws_efs_file_system.swarm_data_store.id
}

resource "aws_efs_mount_target" "swarm_data_store_mt" {
  count = var.create_swarm_vpc == true ? length(module.swarm_vpc[0].azs) : length(var.swarm_vpc_azs)

  file_system_id  = aws_efs_file_system.swarm_data_store.id
  subnet_id       = local.swarm_data_store_subnets[count.index]
  security_groups = [aws_security_group.swarm_data_store_sg.id]
}

resource "aws_security_group" "swarm_data_store_sg" {
  name   = "${local.name_prefix}-data-store-sg${local.name_suffix}"
  vpc_id = local.swarm_vpc_id

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Terraform = "true"
    Name      = "${local.name_prefix}-data-store-sg${local.name_suffix}"
  }
}

resource "time_sleep" "generating_swarm_data_store_mt_dns_names" {
  depends_on = [
    aws_efs_mount_target.swarm_data_store_mt[0],
    aws_efs_mount_target.swarm_data_store_mt[1],
    aws_efs_mount_target.swarm_data_store_mt[2],
  ]

  create_duration = "120s"
}

#####################################################################
# SWARM LB
#####################################################################

locals {
  swarm_lb                   = aws_lb.swarm_lb.id
  swarm_lb_sg                = aws_security_group.swarm_lb_sg.id
  swarm_lb_access_cidr_block = ["0.0.0.0/0"]

  alb_ingress_ports = {
    "http_port"  = 80
    "https_port" = 443
  }
}

resource "aws_lb" "swarm_lb" {
  name               = "${local.name_prefix}-lb${local.name_suffix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.swarm_lb_sg[0].id]
  subnets            = var.create_swarm_vpc == true ? module.swarm_vpc[0].public_subnets : data.aws_subnets.swarm_vpc_public_subnets[0].ids

  tags = {
    Terraform = "true"
    Name      = "${local.name_prefix}-lb${local.name_suffix}"
    Env       = var.environment
  }
}

resource "aws_security_group" "swarm_lb_sg" {
  name   = "${local.name_prefix}-lb-sg${local.name_suffix}"
  vpc_id = local.swarm_vpc_id

  dynamic "ingress" {
    iterator = port
    for_each = local.alb_ingress_ports

    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = local.swarm_lb_access_cidr_block
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
    Name      = "${local.name_prefix}-lb-sg${local.name_suffix}"
    Env       = var.environment
  }
}

resource "aws_lb_listener" "swarm_lb_http" {
  load_balancer_arn = aws_lb.swarm_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "swarm_lb_https" {
  load_balancer_arn = aws_lb.swarm_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = module.tls_port.acm_certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.portainer_tg.arn
      }
    }
  }
}

#####################################################################
# DASHBOARDS
#####################################################################

locals {
  dashboards_url_suffix         = var.environment == "" || var.environment == "default" || var.environment == "prod*" ? "" : "-${var.environment}"
  dashboards_parent_domain_name = "${local.name_prefix}${local.dashboards_url_suffix}.${var.dashboards_parent_domain_name}"
}

data "aws_route53_zone" "dashboards_parent_domain_name" {
  name = var.dashboards_parent_domain_name
}

#####################################################################
# PORTAINER STACK - PORTAINER SERVICE
#####################################################################

locals {
  portainer_url                    = "${local.name_prefix}${local.dashboards_url_suffix}-admin.${var.dashboards_parent_domain_name}"
  portainer_tg                     = aws_lb_target_group.portainer_tg.arn
  portainer_http_health_check_path = "/#!/init/admin"
  portainer_http_ingress_port      = 9000
}

resource "aws_route53_record" "portainer_root_domain" {

  zone_id = data.aws_route53_zone.dashboards_parent_domain_name.zone_id
  name    = local.portainer_url
  type    = "A"

  alias {
    name                   = aws_lb.swarm_lb.dns_name
    zone_id                = aws_lb.swarm_lb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "portainer_sub_domain" {
  zone_id = data.aws_route53_zone.dashboards_parent_domain_name.zone_id
  name    = "www.${local.portainer_url}"
  type    = "A"

  alias {
    name                   = aws_lb.swarm_lb.dns_name
    zone_id                = aws_lb.swarm_lb.zone_id
    evaluate_target_health = false
  }
}

module "tls_port" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.acm_provider
  }

  domain_name               = local.portainer_url
  subject_alternative_names = ["www.${local.portainer_url}"]

  wait_for_validation     = false
  create_route53_records  = false
  validation_method       = "DNS"
  validation_record_fqdns = module.cnvr_port.validation_route53_record_fqdns

  tags = {
    Terraform = "true"
    Name      = "${local.name_prefix}-portainer-tls${local.name_suffix}"
    Env       = var.environment
  }
}

module "cnvr_port" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  providers = {
    aws = aws.route53_provider
  }

  create_certificate          = false
  create_route53_records_only = true

  distinct_domain_names                     = module.tls_port.distinct_domain_names
  zone_id                                   = data.aws_route53_zone.dashboards_parent_domain_name.zone_id
  acm_certificate_domain_validation_options = module.tls_port.acm_certificate_domain_validation_options
}

resource "aws_lb_listener_rule" "portainer_forward" {
  listener_arn = aws_lb_listener.swarm_lb_https.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.portainer_tg.arn
  }

  condition {
    host_header {
      values = [local.portainer_url]
    }
  }

  condition {
    source_ip {
      values = var.dashboards_access_cidr_block
    }
  }
}

resource "aws_lb_target_group" "portainer_tg" {
  name     = "${local.name_prefix}-portainer-tg${local.name_suffix}"
  port     = local.portainer_http_ingress_port
  protocol = "HTTP"
  vpc_id   = local.swarm_vpc_id

  health_check {
    protocol            = "HTTP"
    path                = local.portainer_http_health_check_path
    interval            = 30
    healthy_threshold   = 5
    unhealthy_threshold = 5
  }
}

#####################################################################
# PORTAINER CONFIG FILES
#####################################################################

locals {
  portainer_dap = data.local_file.portainer_dap.content
}

data "local_file" "portainer_dap" {
  filename = "${path.module}/dashboards/admin/portainer/default-admin-password.txt"
}

resource "aws_s3_object" "portainer_dap" {
  bucket = local.swarm_config_files_s3_bucket
  key    = "portainer-dap.txt"
  source = "${path.module}/dashboards/admin/portainer/default-admin-password.txt"
}

#####################################################################
# SWARM CONFIG FILES S3 BUCKET
#####################################################################

locals {
  swarm_config_files_s3_bucket      = aws_s3_bucket.swarm_config_files.id
  swarm_config_files_s3_bucket_name = "dswm-${random_string.name_prefix.result}-config-files"
}

resource "random_string" "name_prefix" {
  length  = 10
  lower   = true
  upper   = false
  numeric = false
  special = false
}

resource "aws_s3_bucket" "swarm_config_files" {
  bucket        = local.swarm_config_files_s3_bucket_name
  force_destroy = true
}

#####################################################################
# MN_JOIN_TOKEN PLACEHOLDER
#####################################################################

locals {
  join_token_placeholder_value = "12345"
}

resource "aws_ssm_parameter" "mn_join_token_placeholder" {
  name  = "${upper(var.swarm_name)}-MN-JOIN-TOKEN"
  type  = "SecureString"
  value = local.join_token_placeholder_value

  tags = {
    Env = var.environment
  }
}

#####################################################################
# WN_JOIN_TOKEN PLACEHOLDER
#####################################################################

resource "aws_ssm_parameter" "wn_join_token_placeholder" {
  name  = "${upper(var.swarm_name)}-WN-JOIN-TOKEN"
  type  = "SecureString"
  value = local.join_token_placeholder_value

  tags = {
    Env = var.environment
  }
}

#####################################################################
# MN LOCALS
#####################################################################

locals {
  num_of_mn = var.num_of_mn == 1 || var.num_of_mn == 3 || var.num_of_mn == 5 || var.num_of_mn == 7 ? var.num_of_mn : 1

  mn_1_subnet = (var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[0] : (var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[0] : (var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 0) : (var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 0) : ""))))
  mn_2_subnet = ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[1] : ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[1] : ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 1) : ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 1) : ""))))
  mn_3_subnet = ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[2] : ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[2] : ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 2) : ((local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 2) : ""))))
  mn_4_subnet = ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[0] : ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[0] : ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 0) : ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 0) : ""))))
  mn_5_subnet = ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[1] : ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[1] : ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 1) : ((local.num_of_mn == 5 || local.num_of_mn == 7) && var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 1) : ""))))
  mn_6_subnet = (local.num_of_mn == 7 && var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[2] : (local.num_of_mn == 7 && var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[2] : (local.num_of_mn == 7 && var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 2) : (local.num_of_mn == 7 && var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 2) : ""))))
  mn_7_subnet = (local.num_of_mn == 7 && var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets[0] : (local.num_of_mn == 7 && var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets[0] : (local.num_of_mn == 7 && var.create_swarm_vpc == false && local.swarm_type == "public" ? element(data.aws_subnets.swarm_vpc_public_subnets[0].ids, 0) : (local.num_of_mn == 7 && var.create_swarm_vpc == false && local.swarm_type == "private" ? element(data.aws_subnets.swarm_vpc_private_subnets[0].ids, 0) : ""))))

  mn_1_public_eip = module.mn_1.node_public_eip
  mn_2_public_eip = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_2[0].node_public_eip : "none"
  mn_3_public_eip = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_3[0].node_public_eip : "none"
  mn_4_public_eip = local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_4[0].node_public_eip : "none"
  mn_5_public_eip = local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_5[0].node_public_eip : "none"
  mn_6_public_eip = local.num_of_mn == 7 ? module.mn_6[0].node_public_eip : "none"
  mn_7_public_eip = local.num_of_mn == 7 ? module.mn_7[0].node_public_eip : "none"

  mn_1_private_eip_name = "${local.name_prefix}-mn-1-priv-eip${local.name_suffix}"
  mn_2_private_eip_name = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? "${local.name_prefix}-mn-2-priv-eip${local.name_suffix}" : "none"
  mn_3_private_eip_name = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? "${local.name_prefix}-mn-3-priv-eip${local.name_suffix}" : "none"
  mn_4_private_eip_name = local.num_of_mn == 5 || local.num_of_mn == 7 ? "${local.name_prefix}-mn-4-priv-eip${local.name_suffix}" : "none"
  mn_5_private_eip_name = local.num_of_mn == 5 || local.num_of_mn == 7 ? "${local.name_prefix}-mn-5-priv-eip${local.name_suffix}" : "none"
  mn_6_private_eip_name = local.num_of_mn == 7 ? "${local.name_prefix}-mn-6-priv-eip${local.name_suffix}" : "none"
  mn_7_private_eip_name = local.num_of_mn == 7 ? "${local.name_prefix}-mn-7-priv-eip${local.name_suffix}" : "none"

  mn_1_state = module.mn_1.node_state
  mn_2_state = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_2[0].node_state : "none"
  mn_3_state = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_3[0].node_state : "none"
  mn_4_state = local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_4[0].node_state : "none"
  mn_5_state = local.num_of_mn == 5 || local.num_of_mn == 7 ? module.mn_5[0].node_state : "none"
  mn_6_state = local.num_of_mn == 7 ? module.mn_6[0].node_state : "none"
  mn_7_state = local.num_of_mn == 7 ? module.mn_7[0].node_state : "none"
}

#####################################################################
# MN_1
#####################################################################

module "mn_1" {
  source = "./nodes/mn"

  depends_on = [time_sleep.generating_swarm_data_store_mt_dns_names, aws_ssm_parameter.mn_join_token_placeholder, aws_ssm_parameter.wn_join_token_placeholder]

  mn_index    = "1"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_1_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# MN_2
#####################################################################

module "mn_2" {
  source = "./nodes/mn"

  count      = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? 1 : 0
  depends_on = [module.mn_1]

  mn_index    = "2"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_2_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# MN_3
#####################################################################

module "mn_3" {
  source = "./nodes/mn"

  count      = local.num_of_mn == 3 || local.num_of_mn == 5 || local.num_of_mn == 7 ? 1 : 0
  depends_on = [module.mn_1]

  mn_index    = "3"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_3_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}


#####################################################################
# MN_4
#####################################################################

module "mn_4" {
  source = "./nodes/mn"

  count      = local.num_of_mn == 5 || local.num_of_mn == 7 ? 1 : 0
  depends_on = [module.mn_1]

  mn_index    = "4"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_4_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# MN_5
#####################################################################

module "mn_5" {
  source = "./nodes/mn"

  count      = local.num_of_mn == 5 || local.num_of_mn == 7 ? 1 : 0
  depends_on = [module.mn_1]

  mn_index    = "5"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_5_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# MN_6
#####################################################################

module "mn_6" {
  source = "./nodes/mn"

  count      = local.num_of_mn == 7 ? 1 : 0
  depends_on = [module.mn_1]

  mn_index    = "6"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_6_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# MN_7
#####################################################################

module "mn_7" {
  source = "./nodes/mn"

  count      = local.num_of_mn == 7 ? 1 : 0
  depends_on = [module.mn_1]

  mn_index    = "7"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnet      = local.mn_7_subnet

  node_instance_type      = var.mn_instance_type
  node_os_architecture    = var.mn_os_architecture
  node_linux_distribution = var.mn_linux_distribution
  node_rhel_version       = var.mn_rhel_version
  node_ubuntu_version     = var.mn_ubuntu_version
  node_ubuntu_server_type = var.mn_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_data_store_dns = local.swarm_data_store_dns
  swarm_data_store_sg  = local.swarm_data_store_sg

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  swarm_lb_sg = local.swarm_lb_sg

  portainer_tg = local.portainer_tg

  grant_swarm_services_iam_access   = local.grant_swarm_services_iam_access
  enable_swarm_services_autoscaling = local.enable_swarm_services_autoscaling

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN LOCALS
#####################################################################

locals {
  num_of_wn = var.num_of_wn < 1 || var.num_of_wn > 50 ? 1 : var.num_of_wn

  wn_subnets = (var.create_swarm_vpc == true && local.swarm_type == "public" ? module.swarm_vpc[0].public_subnets : (var.create_swarm_vpc == true && local.swarm_type == "private" ? module.swarm_vpc[0].private_subnets : (var.create_swarm_vpc == false && local.swarm_type == "public" ? data.aws_subnets.swarm_vpc_public_subnets[0].ids : (var.create_swarm_vpc == false && local.swarm_type == "private" ? data.aws_subnets.swarm_vpc_private_subnets[0].ids : "")))) #var.swarm_vpc_public_subnets   #var.swarm_vpc_private_subnets

  wn_1_state  = local.num_of_wn >= 1 && local.num_of_wn <= 50 ? module.wn_1[0].node_state : "none"
  wn_2_state  = local.num_of_wn >= 2 && local.num_of_wn <= 50 ? module.wn_2[0].node_state : "none"
  wn_3_state  = local.num_of_wn >= 3 && local.num_of_wn <= 50 ? module.wn_3[0].node_state : "none"
  wn_4_state  = local.num_of_wn >= 4 && local.num_of_wn <= 50 ? module.wn_4[0].node_state : "none"
  wn_5_state  = local.num_of_wn >= 5 && local.num_of_wn <= 50 ? module.wn_5[0].node_state : "none"
  wn_6_state  = local.num_of_wn >= 6 && local.num_of_wn <= 50 ? module.wn_6[0].node_state : "none"
  wn_7_state  = local.num_of_wn >= 7 && local.num_of_wn <= 50 ? module.wn_7[0].node_state : "none"
  wn_8_state  = local.num_of_wn >= 8 && local.num_of_wn <= 50 ? module.wn_8[0].node_state : "none"
  wn_9_state  = local.num_of_wn >= 9 && local.num_of_wn <= 50 ? module.wn_9[0].node_state : "none"
  wn_10_state = local.num_of_wn >= 10 && local.num_of_wn <= 50 ? module.wn_10[0].node_state : "none"

  wn_11_state = local.num_of_wn >= 11 && local.num_of_wn <= 50 ? module.wn_11[0].node_state : "none"
  wn_12_state = local.num_of_wn >= 12 && local.num_of_wn <= 50 ? module.wn_12[0].node_state : "none"
  wn_13_state = local.num_of_wn >= 13 && local.num_of_wn <= 50 ? module.wn_13[0].node_state : "none"
  wn_14_state = local.num_of_wn >= 14 && local.num_of_wn <= 50 ? module.wn_14[0].node_state : "none"
  wn_15_state = local.num_of_wn >= 15 && local.num_of_wn <= 50 ? module.wn_15[0].node_state : "none"
  wn_16_state = local.num_of_wn >= 16 && local.num_of_wn <= 50 ? module.wn_16[0].node_state : "none"
  wn_17_state = local.num_of_wn >= 17 && local.num_of_wn <= 50 ? module.wn_17[0].node_state : "none"
  wn_18_state = local.num_of_wn >= 18 && local.num_of_wn <= 50 ? module.wn_18[0].node_state : "none"
  wn_19_state = local.num_of_wn >= 19 && local.num_of_wn <= 50 ? module.wn_19[0].node_state : "none"
  wn_20_state = local.num_of_wn >= 20 && local.num_of_wn <= 50 ? module.wn_20[0].node_state : "none"

  wn_21_state = local.num_of_wn >= 21 && local.num_of_wn <= 50 ? module.wn_21[0].node_state : "none"
  wn_22_state = local.num_of_wn >= 22 && local.num_of_wn <= 50 ? module.wn_22[0].node_state : "none"
  wn_23_state = local.num_of_wn >= 23 && local.num_of_wn <= 50 ? module.wn_23[0].node_state : "none"
  wn_24_state = local.num_of_wn >= 24 && local.num_of_wn <= 50 ? module.wn_24[0].node_state : "none"
  wn_25_state = local.num_of_wn >= 25 && local.num_of_wn <= 50 ? module.wn_25[0].node_state : "none"
  wn_26_state = local.num_of_wn >= 26 && local.num_of_wn <= 50 ? module.wn_26[0].node_state : "none"
  wn_27_state = local.num_of_wn >= 27 && local.num_of_wn <= 50 ? module.wn_27[0].node_state : "none"
  wn_28_state = local.num_of_wn >= 28 && local.num_of_wn <= 50 ? module.wn_28[0].node_state : "none"
  wn_29_state = local.num_of_wn >= 29 && local.num_of_wn <= 50 ? module.wn_29[0].node_state : "none"
  wn_30_state = local.num_of_wn >= 30 && local.num_of_wn <= 50 ? module.wn_30[0].node_state : "none"

  wn_31_state = local.num_of_wn >= 31 && local.num_of_wn <= 50 ? module.wn_31[0].node_state : "none"
  wn_32_state = local.num_of_wn >= 32 && local.num_of_wn <= 50 ? module.wn_32[0].node_state : "none"
  wn_33_state = local.num_of_wn >= 33 && local.num_of_wn <= 50 ? module.wn_33[0].node_state : "none"
  wn_34_state = local.num_of_wn >= 34 && local.num_of_wn <= 50 ? module.wn_34[0].node_state : "none"
  wn_35_state = local.num_of_wn >= 35 && local.num_of_wn <= 50 ? module.wn_35[0].node_state : "none"
  wn_36_state = local.num_of_wn >= 36 && local.num_of_wn <= 50 ? module.wn_36[0].node_state : "none"
  wn_37_state = local.num_of_wn >= 37 && local.num_of_wn <= 50 ? module.wn_37[0].node_state : "none"
  wn_38_state = local.num_of_wn >= 38 && local.num_of_wn <= 50 ? module.wn_38[0].node_state : "none"
  wn_39_state = local.num_of_wn >= 39 && local.num_of_wn <= 50 ? module.wn_39[0].node_state : "none"
  wn_40_state = local.num_of_wn >= 40 && local.num_of_wn <= 50 ? module.wn_40[0].node_state : "none"

  wn_41_state = local.num_of_wn >= 41 && local.num_of_wn <= 50 ? module.wn_41[0].node_state : "none"
  wn_42_state = local.num_of_wn >= 42 && local.num_of_wn <= 50 ? module.wn_42[0].node_state : "none"
  wn_43_state = local.num_of_wn >= 43 && local.num_of_wn <= 50 ? module.wn_43[0].node_state : "none"
  wn_44_state = local.num_of_wn >= 44 && local.num_of_wn <= 50 ? module.wn_44[0].node_state : "none"
  wn_45_state = local.num_of_wn >= 45 && local.num_of_wn <= 50 ? module.wn_45[0].node_state : "none"
  wn_46_state = local.num_of_wn >= 46 && local.num_of_wn <= 50 ? module.wn_46[0].node_state : "none"
  wn_47_state = local.num_of_wn >= 47 && local.num_of_wn <= 50 ? module.wn_47[0].node_state : "none"
  wn_48_state = local.num_of_wn >= 48 && local.num_of_wn <= 50 ? module.wn_48[0].node_state : "none"
  wn_49_state = local.num_of_wn >= 49 && local.num_of_wn <= 50 ? module.wn_49[0].node_state : "none"
  wn_50_state = local.num_of_wn == 50 ? module.wn_50[0].node_state : "none"
}

#####################################################################
# WN_1
#####################################################################

module "wn_1" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 1 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "1"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_1_instance_type
  node_os_architecture    = var.wn_1_os_architecture
  node_linux_distribution = var.wn_1_linux_distribution
  node_rhel_version       = var.wn_1_rhel_version
  node_ubuntu_version     = var.wn_1_ubuntu_version
  node_ubuntu_server_type = var.wn_1_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_2
#####################################################################

module "wn_2" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 2 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "2"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_2_instance_type
  node_os_architecture    = var.wn_2_os_architecture
  node_linux_distribution = var.wn_2_linux_distribution
  node_rhel_version       = var.wn_2_rhel_version
  node_ubuntu_version     = var.wn_2_ubuntu_version
  node_ubuntu_server_type = var.wn_2_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_3
#####################################################################

module "wn_3" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 3 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "3"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_3_instance_type
  node_os_architecture    = var.wn_3_os_architecture
  node_linux_distribution = var.wn_3_linux_distribution
  node_rhel_version       = var.wn_3_rhel_version
  node_ubuntu_version     = var.wn_3_ubuntu_version
  node_ubuntu_server_type = var.wn_3_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_4
#####################################################################

module "wn_4" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 4 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "4"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_4_instance_type
  node_os_architecture    = var.wn_4_os_architecture
  node_linux_distribution = var.wn_4_linux_distribution
  node_rhel_version       = var.wn_4_rhel_version
  node_ubuntu_version     = var.wn_4_ubuntu_version
  node_ubuntu_server_type = var.wn_4_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_5
#####################################################################

module "wn_5" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 5 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "5"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_5_instance_type
  node_os_architecture    = var.wn_5_os_architecture
  node_linux_distribution = var.wn_5_linux_distribution
  node_rhel_version       = var.wn_5_rhel_version
  node_ubuntu_version     = var.wn_5_ubuntu_version
  node_ubuntu_server_type = var.wn_5_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_6
#####################################################################

module "wn_6" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 6 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "6"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_6_instance_type
  node_os_architecture    = var.wn_6_os_architecture
  node_linux_distribution = var.wn_6_linux_distribution
  node_rhel_version       = var.wn_6_rhel_version
  node_ubuntu_version     = var.wn_6_ubuntu_version
  node_ubuntu_server_type = var.wn_6_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_7
#####################################################################

module "wn_7" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 7 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "7"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_7_instance_type
  node_os_architecture    = var.wn_7_os_architecture
  node_linux_distribution = var.wn_7_linux_distribution
  node_rhel_version       = var.wn_7_rhel_version
  node_ubuntu_version     = var.wn_7_ubuntu_version
  node_ubuntu_server_type = var.wn_7_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_8
#####################################################################

module "wn_8" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 8 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "8"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_8_instance_type
  node_os_architecture    = var.wn_8_os_architecture
  node_linux_distribution = var.wn_8_linux_distribution
  node_rhel_version       = var.wn_8_rhel_version
  node_ubuntu_version     = var.wn_8_ubuntu_version
  node_ubuntu_server_type = var.wn_8_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_9
#####################################################################

module "wn_9" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 9 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "9"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_9_instance_type
  node_os_architecture    = var.wn_9_os_architecture
  node_linux_distribution = var.wn_9_linux_distribution
  node_rhel_version       = var.wn_9_rhel_version
  node_ubuntu_version     = var.wn_9_ubuntu_version
  node_ubuntu_server_type = var.wn_9_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_10
#####################################################################

module "wn_10" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 10 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "10"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_10_instance_type
  node_os_architecture    = var.wn_10_os_architecture
  node_linux_distribution = var.wn_10_linux_distribution
  node_rhel_version       = var.wn_10_rhel_version
  node_ubuntu_version     = var.wn_10_ubuntu_version
  node_ubuntu_server_type = var.wn_10_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_11
#####################################################################

module "wn_11" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 11 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "11"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_11_instance_type
  node_os_architecture    = var.wn_11_os_architecture
  node_linux_distribution = var.wn_11_linux_distribution
  node_rhel_version       = var.wn_11_rhel_version
  node_ubuntu_version     = var.wn_11_ubuntu_version
  node_ubuntu_server_type = var.wn_11_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_12
#####################################################################

module "wn_12" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 12 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "12"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_12_instance_type
  node_os_architecture    = var.wn_12_os_architecture
  node_linux_distribution = var.wn_12_linux_distribution
  node_rhel_version       = var.wn_12_rhel_version
  node_ubuntu_version     = var.wn_12_ubuntu_version
  node_ubuntu_server_type = var.wn_12_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_13
#####################################################################

module "wn_13" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 13 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "13"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_13_instance_type
  node_os_architecture    = var.wn_13_os_architecture
  node_linux_distribution = var.wn_13_linux_distribution
  node_rhel_version       = var.wn_13_rhel_version
  node_ubuntu_version     = var.wn_13_ubuntu_version
  node_ubuntu_server_type = var.wn_13_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_14
#####################################################################

module "wn_14" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 14 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "14"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_14_instance_type
  node_os_architecture    = var.wn_14_os_architecture
  node_linux_distribution = var.wn_14_linux_distribution
  node_rhel_version       = var.wn_14_rhel_version
  node_ubuntu_version     = var.wn_14_ubuntu_version
  node_ubuntu_server_type = var.wn_14_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_15
#####################################################################

module "wn_15" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 15 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "15"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_15_instance_type
  node_os_architecture    = var.wn_15_os_architecture
  node_linux_distribution = var.wn_15_linux_distribution
  node_rhel_version       = var.wn_15_rhel_version
  node_ubuntu_version     = var.wn_15_ubuntu_version
  node_ubuntu_server_type = var.wn_15_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_16
#####################################################################

module "wn_16" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 16 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "16"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_16_instance_type
  node_os_architecture    = var.wn_16_os_architecture
  node_linux_distribution = var.wn_16_linux_distribution
  node_rhel_version       = var.wn_16_rhel_version
  node_ubuntu_version     = var.wn_16_ubuntu_version
  node_ubuntu_server_type = var.wn_16_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_17
#####################################################################

module "wn_17" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 17 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "17"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_17_instance_type
  node_os_architecture    = var.wn_17_os_architecture
  node_linux_distribution = var.wn_17_linux_distribution
  node_rhel_version       = var.wn_17_rhel_version
  node_ubuntu_version     = var.wn_17_ubuntu_version
  node_ubuntu_server_type = var.wn_17_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_18
#####################################################################

module "wn_18" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 18 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "18"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_18_instance_type
  node_os_architecture    = var.wn_18_os_architecture
  node_linux_distribution = var.wn_18_linux_distribution
  node_rhel_version       = var.wn_18_rhel_version
  node_ubuntu_version     = var.wn_18_ubuntu_version
  node_ubuntu_server_type = var.wn_18_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_19
#####################################################################

module "wn_19" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 19 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "19"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_19_instance_type
  node_os_architecture    = var.wn_19_os_architecture
  node_linux_distribution = var.wn_19_linux_distribution
  node_rhel_version       = var.wn_19_rhel_version
  node_ubuntu_version     = var.wn_19_ubuntu_version
  node_ubuntu_server_type = var.wn_19_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_20
#####################################################################

module "wn_20" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 20 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "20"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_20_instance_type
  node_os_architecture    = var.wn_20_os_architecture
  node_linux_distribution = var.wn_20_linux_distribution
  node_rhel_version       = var.wn_20_rhel_version
  node_ubuntu_version     = var.wn_20_ubuntu_version
  node_ubuntu_server_type = var.wn_20_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_21
#####################################################################

module "wn_21" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 21 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "21"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_21_instance_type
  node_os_architecture    = var.wn_21_os_architecture
  node_linux_distribution = var.wn_21_linux_distribution
  node_rhel_version       = var.wn_21_rhel_version
  node_ubuntu_version     = var.wn_21_ubuntu_version
  node_ubuntu_server_type = var.wn_21_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_22
#####################################################################

module "wn_22" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 22 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "22"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_22_instance_type
  node_os_architecture    = var.wn_22_os_architecture
  node_linux_distribution = var.wn_22_linux_distribution
  node_rhel_version       = var.wn_22_rhel_version
  node_ubuntu_version     = var.wn_22_ubuntu_version
  node_ubuntu_server_type = var.wn_22_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_23
#####################################################################

module "wn_23" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 23 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "23"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_23_instance_type
  node_os_architecture    = var.wn_23_os_architecture
  node_linux_distribution = var.wn_23_linux_distribution
  node_rhel_version       = var.wn_23_rhel_version
  node_ubuntu_version     = var.wn_23_ubuntu_version
  node_ubuntu_server_type = var.wn_23_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_24
#####################################################################

module "wn_24" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 24 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "24"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_24_instance_type
  node_os_architecture    = var.wn_24_os_architecture
  node_linux_distribution = var.wn_24_linux_distribution
  node_rhel_version       = var.wn_24_rhel_version
  node_ubuntu_version     = var.wn_24_ubuntu_version
  node_ubuntu_server_type = var.wn_24_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_25
#####################################################################

module "wn_25" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 25 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "25"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_25_instance_type
  node_os_architecture    = var.wn_25_os_architecture
  node_linux_distribution = var.wn_25_linux_distribution
  node_rhel_version       = var.wn_25_rhel_version
  node_ubuntu_version     = var.wn_25_ubuntu_version
  node_ubuntu_server_type = var.wn_25_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_26
#####################################################################

module "wn_26" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 26 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "26"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_26_instance_type
  node_os_architecture    = var.wn_26_os_architecture
  node_linux_distribution = var.wn_26_linux_distribution
  node_rhel_version       = var.wn_26_rhel_version
  node_ubuntu_version     = var.wn_26_ubuntu_version
  node_ubuntu_server_type = var.wn_26_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_27
#####################################################################

module "wn_27" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 27 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "27"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_27_instance_type
  node_os_architecture    = var.wn_27_os_architecture
  node_linux_distribution = var.wn_27_linux_distribution
  node_rhel_version       = var.wn_27_rhel_version
  node_ubuntu_version     = var.wn_27_ubuntu_version
  node_ubuntu_server_type = var.wn_27_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_28
#####################################################################

module "wn_28" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 28 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "28"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_28_instance_type
  node_os_architecture    = var.wn_28_os_architecture
  node_linux_distribution = var.wn_28_linux_distribution
  node_rhel_version       = var.wn_28_rhel_version
  node_ubuntu_version     = var.wn_28_ubuntu_version
  node_ubuntu_server_type = var.wn_28_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_29
#####################################################################

module "wn_29" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 29 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "29"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_29_instance_type
  node_os_architecture    = var.wn_29_os_architecture
  node_linux_distribution = var.wn_29_linux_distribution
  node_rhel_version       = var.wn_29_rhel_version
  node_ubuntu_version     = var.wn_29_ubuntu_version
  node_ubuntu_server_type = var.wn_29_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_30
#####################################################################

module "wn_30" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 30 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "30"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_30_instance_type
  node_os_architecture    = var.wn_30_os_architecture
  node_linux_distribution = var.wn_30_linux_distribution
  node_rhel_version       = var.wn_30_rhel_version
  node_ubuntu_version     = var.wn_30_ubuntu_version
  node_ubuntu_server_type = var.wn_30_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_31
#####################################################################

module "wn_31" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 31 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "31"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_31_instance_type
  node_os_architecture    = var.wn_31_os_architecture
  node_linux_distribution = var.wn_31_linux_distribution
  node_rhel_version       = var.wn_31_rhel_version
  node_ubuntu_version     = var.wn_31_ubuntu_version
  node_ubuntu_server_type = var.wn_31_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_32
#####################################################################

module "wn_32" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 32 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "32"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_32_instance_type
  node_os_architecture    = var.wn_32_os_architecture
  node_linux_distribution = var.wn_32_linux_distribution
  node_rhel_version       = var.wn_32_rhel_version
  node_ubuntu_version     = var.wn_32_ubuntu_version
  node_ubuntu_server_type = var.wn_32_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_33
#####################################################################

module "wn_33" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 33 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "33"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_33_instance_type
  node_os_architecture    = var.wn_33_os_architecture
  node_linux_distribution = var.wn_33_linux_distribution
  node_rhel_version       = var.wn_33_rhel_version
  node_ubuntu_version     = var.wn_33_ubuntu_version
  node_ubuntu_server_type = var.wn_33_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_34
#####################################################################

module "wn_34" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 34 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "34"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_34_instance_type
  node_os_architecture    = var.wn_34_os_architecture
  node_linux_distribution = var.wn_34_linux_distribution
  node_rhel_version       = var.wn_34_rhel_version
  node_ubuntu_version     = var.wn_34_ubuntu_version
  node_ubuntu_server_type = var.wn_34_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_35
#####################################################################

module "wn_35" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 35 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "35"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_35_instance_type
  node_os_architecture    = var.wn_35_os_architecture
  node_linux_distribution = var.wn_35_linux_distribution
  node_rhel_version       = var.wn_35_rhel_version
  node_ubuntu_version     = var.wn_35_ubuntu_version
  node_ubuntu_server_type = var.wn_35_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_36
#####################################################################

module "wn_36" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 36 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "36"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_36_instance_type
  node_os_architecture    = var.wn_36_os_architecture
  node_linux_distribution = var.wn_36_linux_distribution
  node_rhel_version       = var.wn_36_rhel_version
  node_ubuntu_version     = var.wn_36_ubuntu_version
  node_ubuntu_server_type = var.wn_36_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_37
#####################################################################

module "wn_37" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 37 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "37"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_37_instance_type
  node_os_architecture    = var.wn_37_os_architecture
  node_linux_distribution = var.wn_37_linux_distribution
  node_rhel_version       = var.wn_37_rhel_version
  node_ubuntu_version     = var.wn_37_ubuntu_version
  node_ubuntu_server_type = var.wn_37_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_38
#####################################################################

module "wn_38" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 38 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "38"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_38_instance_type
  node_os_architecture    = var.wn_38_os_architecture
  node_linux_distribution = var.wn_38_linux_distribution
  node_rhel_version       = var.wn_38_rhel_version
  node_ubuntu_version     = var.wn_38_ubuntu_version
  node_ubuntu_server_type = var.wn_38_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_39
#####################################################################

module "wn_39" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 39 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "39"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_39_instance_type
  node_os_architecture    = var.wn_39_os_architecture
  node_linux_distribution = var.wn_39_linux_distribution
  node_rhel_version       = var.wn_39_rhel_version
  node_ubuntu_version     = var.wn_39_ubuntu_version
  node_ubuntu_server_type = var.wn_39_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_40
#####################################################################

module "wn_40" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 40 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "40"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_40_instance_type
  node_os_architecture    = var.wn_40_os_architecture
  node_linux_distribution = var.wn_40_linux_distribution
  node_rhel_version       = var.wn_40_rhel_version
  node_ubuntu_version     = var.wn_40_ubuntu_version
  node_ubuntu_server_type = var.wn_40_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_41
#####################################################################

module "wn_41" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 41 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "41"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_41_instance_type
  node_os_architecture    = var.wn_41_os_architecture
  node_linux_distribution = var.wn_41_linux_distribution
  node_rhel_version       = var.wn_41_rhel_version
  node_ubuntu_version     = var.wn_41_ubuntu_version
  node_ubuntu_server_type = var.wn_41_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_42
#####################################################################

module "wn_42" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 42 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "42"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_42_instance_type
  node_os_architecture    = var.wn_42_os_architecture
  node_linux_distribution = var.wn_42_linux_distribution
  node_rhel_version       = var.wn_42_rhel_version
  node_ubuntu_version     = var.wn_42_ubuntu_version
  node_ubuntu_server_type = var.wn_42_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_43
#####################################################################

module "wn_43" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 43 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "43"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_43_instance_type
  node_os_architecture    = var.wn_43_os_architecture
  node_linux_distribution = var.wn_43_linux_distribution
  node_rhel_version       = var.wn_43_rhel_version
  node_ubuntu_version     = var.wn_43_ubuntu_version
  node_ubuntu_server_type = var.wn_43_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_44
#####################################################################

module "wn_44" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 44 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "44"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_44_instance_type
  node_os_architecture    = var.wn_44_os_architecture
  node_linux_distribution = var.wn_44_linux_distribution
  node_rhel_version       = var.wn_44_rhel_version
  node_ubuntu_version     = var.wn_44_ubuntu_version
  node_ubuntu_server_type = var.wn_44_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_45
#####################################################################

module "wn_45" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 45 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "45"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_45_instance_type
  node_os_architecture    = var.wn_45_os_architecture
  node_linux_distribution = var.wn_45_linux_distribution
  node_rhel_version       = var.wn_45_rhel_version
  node_ubuntu_version     = var.wn_45_ubuntu_version
  node_ubuntu_server_type = var.wn_45_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_46
#####################################################################

module "wn_16" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 46 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "46"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_46_instance_type
  node_os_architecture    = var.wn_46_os_architecture
  node_linux_distribution = var.wn_46_linux_distribution
  node_rhel_version       = var.wn_46_rhel_version
  node_ubuntu_version     = var.wn_46_ubuntu_version
  node_ubuntu_server_type = var.wn_46_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_47
#####################################################################

module "wn_47" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 47 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "47"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_47_instance_type
  node_os_architecture    = var.wn_47_os_architecture
  node_linux_distribution = var.wn_47_linux_distribution
  node_rhel_version       = var.wn_47_rhel_version
  node_ubuntu_version     = var.wn_47_ubuntu_version
  node_ubuntu_server_type = var.wn_47_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_48
#####################################################################

module "wn_48" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 48 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "48"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_48_instance_type
  node_os_architecture    = var.wn_48_os_architecture
  node_linux_distribution = var.wn_48_linux_distribution
  node_rhel_version       = var.wn_48_rhel_version
  node_ubuntu_version     = var.wn_48_ubuntu_version
  node_ubuntu_server_type = var.wn_48_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_49
#####################################################################

module "wn_49" {
  source = "./nodes/wn"

  count      = local.num_of_wn >= 49 && local.num_of_wn <= 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "49"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_49_instance_type
  node_os_architecture    = var.wn_49_os_architecture
  node_linux_distribution = var.wn_49_linux_distribution
  node_rhel_version       = var.wn_49_rhel_version
  node_ubuntu_version     = var.wn_49_ubuntu_version
  node_ubuntu_server_type = var.wn_49_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_50
#####################################################################

module "wn_50" {
  source = "./nodes/wn"

  count      = local.num_of_wn == 50 ? 1 : 0
  depends_on = [module.mn_1]

  wn_index    = "50"
  swarm_name  = var.swarm_name
  environment = var.environment

  swarm_vpc_id     = local.swarm_vpc_id
  swarm_vpc_cidr   = local.swarm_vpc_cidr
  node_subnet_type = local.swarm_type
  node_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_instance_type      = var.wn_50_instance_type
  node_os_architecture    = var.wn_50_os_architecture
  node_linux_distribution = var.wn_50_linux_distribution
  node_rhel_version       = var.wn_50_rhel_version
  node_ubuntu_version     = var.wn_50_ubuntu_version
  node_ubuntu_server_type = var.wn_50_ubuntu_server_type

  backup_node_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP LOCALS
#####################################################################

locals {
  num_of_wn_grps = var.num_of_wn_grps < 0 || var.num_of_wn_grps > 10 ? 0 : var.num_of_wn_grps

  wn_grp_1_states  = local.num_of_wn_grps >= 1 && local.num_of_wn_grps <= 10 ? module.wn_grp_1[0].node_grp_states : ["none"]
  wn_grp_2_states  = local.num_of_wn_grps >= 2 && local.num_of_wn_grps <= 10 ? module.wn_grp_2[0].node_grp_states : ["none"]
  wn_grp_3_states  = local.num_of_wn_grps >= 3 && local.num_of_wn_grps <= 10 ? module.wn_grp_3[0].node_grp_states : ["none"]
  wn_grp_4_states  = local.num_of_wn_grps >= 4 && local.num_of_wn_grps <= 10 ? module.wn_grp_4[0].node_grp_states : ["none"]
  wn_grp_5_states  = local.num_of_wn_grps >= 5 && local.num_of_wn_grps <= 10 ? module.wn_grp_5[0].node_grp_states : ["none"]
  wn_grp_6_states  = local.num_of_wn_grps >= 6 && local.num_of_wn_grps <= 10 ? module.wn_grp_6[0].node_grp_states : ["none"]
  wn_grp_7_states  = local.num_of_wn_grps >= 7 && local.num_of_wn_grps <= 10 ? module.wn_grp_7[0].node_grp_states : ["none"]
  wn_grp_8_states  = local.num_of_wn_grps >= 8 && local.num_of_wn_grps <= 10 ? module.wn_grp_8[0].node_grp_states : ["none"]
  wn_grp_9_states  = local.num_of_wn_grps >= 9 && local.num_of_wn_grps <= 10 ? module.wn_grp_9[0].node_grp_states : ["none"]
  wn_grp_10_states = local.num_of_wn_grps == 10 ? module.wn_grp_10[0].node_grp_states : ["none"]
}

#####################################################################
# WN_GRP_1
#####################################################################

module "wn_grp_1" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 1 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "1"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_1_instance_type
  node_grp_os_architecture    = var.wn_grp_1_os_architecture
  node_grp_linux_distribution = var.wn_grp_1_linux_distribution
  node_grp_rhel_version       = var.wn_grp_1_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_1_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_1_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_1_max_capacity
  node_grp_min_capacity = var.wn_grp_1_min_capacity < 1 ? 1 : var.wn_grp_1_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_2
#####################################################################

module "wn_grp_2" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 2 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "2"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_2_instance_type
  node_grp_os_architecture    = var.wn_grp_2_os_architecture
  node_grp_linux_distribution = var.wn_grp_2_linux_distribution
  node_grp_rhel_version       = var.wn_grp_2_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_2_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_2_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_2_max_capacity
  node_grp_min_capacity = var.wn_grp_1_min_capacity < 1 ? 1 : var.wn_grp_1_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_3
#####################################################################

module "wn_grp_3" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 3 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "3"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_3_instance_type
  node_grp_os_architecture    = var.wn_grp_3_os_architecture
  node_grp_linux_distribution = var.wn_grp_3_linux_distribution
  node_grp_rhel_version       = var.wn_grp_3_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_3_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_3_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_3_max_capacity
  node_grp_min_capacity = var.wn_grp_3_min_capacity < 1 ? 1 : var.wn_grp_3_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_4
#####################################################################

module "wn_grp_4" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 4 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "4"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_4_instance_type
  node_grp_os_architecture    = var.wn_grp_4_os_architecture
  node_grp_linux_distribution = var.wn_grp_4_linux_distribution
  node_grp_rhel_version       = var.wn_grp_4_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_4_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_4_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_4_max_capacity
  node_grp_min_capacity = var.wn_grp_4_min_capacity < 1 ? 1 : var.wn_grp_4_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_5
#####################################################################

module "wn_grp_5" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 5 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "5"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_5_instance_type
  node_grp_os_architecture    = var.wn_grp_5_os_architecture
  node_grp_linux_distribution = var.wn_grp_5_linux_distribution
  node_grp_rhel_version       = var.wn_grp_5_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_5_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_5_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_5_max_capacity
  node_grp_min_capacity = var.wn_grp_5_min_capacity < 1 ? 1 : var.wn_grp_5_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_6
#####################################################################

module "wn_grp_6" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 6 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "6"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_6_instance_type
  node_grp_os_architecture    = var.wn_grp_6_os_architecture
  node_grp_linux_distribution = var.wn_grp_6_linux_distribution
  node_grp_rhel_version       = var.wn_grp_6_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_6_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_6_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_6_max_capacity
  node_grp_min_capacity = var.wn_grp_6_min_capacity < 1 ? 1 : var.wn_grp_6_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_7
#####################################################################

module "wn_grp_7" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 7 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "7"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_7_instance_type
  node_grp_os_architecture    = var.wn_grp_7_os_architecture
  node_grp_linux_distribution = var.wn_grp_7_linux_distribution
  node_grp_rhel_version       = var.wn_grp_7_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_7_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_7_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_7_max_capacity
  node_grp_min_capacity = var.wn_grp_7_min_capacity < 1 ? 1 : var.wn_grp_7_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_8
#####################################################################

module "wn_grp_8" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 8 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "8"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_8_instance_type
  node_grp_os_architecture    = var.wn_grp_8_os_architecture
  node_grp_linux_distribution = var.wn_grp_8_linux_distribution
  node_grp_rhel_version       = var.wn_grp_8_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_8_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_8_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_8_max_capacity
  node_grp_min_capacity = var.wn_grp_8_min_capacity < 1 ? 1 : var.wn_grp_8_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_9
#####################################################################

module "wn_grp_9" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps >= 9 && local.num_of_wn_grps <= 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "9"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_9_instance_type
  node_grp_os_architecture    = var.wn_grp_9_os_architecture
  node_grp_linux_distribution = var.wn_grp_9_linux_distribution
  node_grp_rhel_version       = var.wn_grp_9_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_9_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_9_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_9_max_capacity
  node_grp_min_capacity = var.wn_grp_9_min_capacity < 1 ? 1 : var.wn_grp_9_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

#####################################################################
# WN_GRP_10
#####################################################################

module "wn_grp_10" {
  source = "./nodes/wn-grp"

  count      = local.num_of_wn_grps == 10 ? 1 : 0
  depends_on = [module.mn_1]

  node_grp_index = "10"
  swarm_name     = var.swarm_name
  environment    = var.environment

  swarm_vpc_id         = local.swarm_vpc_id
  swarm_vpc_cidr       = local.swarm_vpc_cidr
  node_grp_subnet_type = local.swarm_type
  node_grp_subnets     = local.wn_subnets

  num_of_mn = local.num_of_mn

  mn_1_private_eip_name = local.mn_1_private_eip_name
  mn_2_private_eip_name = local.mn_2_private_eip_name
  mn_3_private_eip_name = local.mn_3_private_eip_name
  mn_4_private_eip_name = local.mn_4_private_eip_name
  mn_5_private_eip_name = local.mn_5_private_eip_name
  mn_6_private_eip_name = local.mn_6_private_eip_name
  mn_7_private_eip_name = local.mn_7_private_eip_name

  node_grp_instance_type      = var.wn_grp_10_instance_type
  node_grp_os_architecture    = var.wn_grp_10_os_architecture
  node_grp_linux_distribution = var.wn_grp_10_linux_distribution
  node_grp_rhel_version       = var.wn_grp_10_rhel_version
  node_grp_ubuntu_version     = var.wn_grp_10_ubuntu_version
  node_grp_ubuntu_server_type = var.wn_grp_10_ubuntu_server_type

  node_grp_max_capacity = var.wn_grp_10_max_capacity
  node_grp_min_capacity = var.wn_grp_10_min_capacity < 1 ? 1 : var.wn_grp_10_min_capacity

  backup_node_grp_ssh_private_key = var.backup_nodes_ssh_private_keys
  node_grp_ssh_access_cidr_block  = var.nodes_ssh_access_cidr_block

  swarm_config_files_s3_bucket_name = local.swarm_config_files_s3_bucket_name
  swarm_config_files_s3_bucket      = local.swarm_config_files_s3_bucket

  node_port_services_ingress_from_port = var.node_port_services_ingress_from_port
  node_port_services_ingress_to_port   = var.node_port_services_ingress_to_port

  grant_swarm_services_iam_access = local.grant_swarm_services_iam_access

  enable_node_grp_status_notification = var.enable_nodes_status_notification
  slack_webhook_url_ssm_parameter     = var.slack_webhook_url_ssm_parameter
}

######################################## APACHEPLAYGROUND™ ########################################
