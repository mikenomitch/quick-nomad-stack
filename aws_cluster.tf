locals {
  // general config values

  base_config_values = {
    use_docker           = var.use_docker
    datacenter           = var.region
    region               = var.region
    authoritative_region = var.authoritative_region
    replication_token    = var.replication_token
    retry_provider       = var.retry_join.provider
    retry_tag_key        = var.retry_join.tag_key
    retry_tag_value      = "${var.retry_join.tag_value_prefix}-${var.cluster_name}"
    rpc_port             = var.rpc_port
  }

  nomad_base_config = merge(local.base_config_values, {
    desired_servers      = var.desired_servers
    nomad_version        = var.nomad_version
    nomad_service_config = local.nomad_service_config
  })

  common_tags = {
    Use = var.common_tag
  }

  // serivce config files

  nomad_service_config = templatefile(
    "${path.module}/templates/services/nomad.service.tpl",
    {}
  )

  consul_template_service_config = templatefile(
    "${path.module}/templates/services/consul_template.service.tpl",
    {}
  )

  // serivce setup files

  docker_config = templatefile(
    "${path.module}/templates/docker.sh.tpl",
    {}
  )

  consul_template_config = templatefile(
    "${path.module}/templates/consul_template.sh.tpl",
    { consul_template_service_config = local.consul_template_service_config }
  )

  nomad_server_config = templatefile(
    "${path.module}/templates/nomad.sh.tpl",
    merge(local.nomad_base_config, { is_server = true })
  )

  nomad_client_config = templatefile(
    "${path.module}/templates/nomad.sh.tpl",
    merge(local.nomad_base_config, { is_server = false })
  )

  launch_base_user_data = merge(local.base_config_values, {
    consul_template_config         = local.consul_template_config
    docker_config                  = local.docker_config
    consul_template_service_config = local.consul_template_service_config
  })
}

# VPC AND SUBNETS

resource "aws_vpc" "nomadstack" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  enable_classiclink   = false
  instance_tenancy     = "default"

  tags = local.common_tags
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.nomadstack.id
  cidr_block              = "10.0.10${count.index}.0/24"
  availability_zone       = var.availability_zones[var.region][count.index]
  map_public_ip_on_launch = true

  tags = local.common_tags
}

resource "aws_internet_gateway" "nomadstack" {
  vpc_id = aws_vpc.nomadstack.id

  tags = local.common_tags
}

resource "aws_route_table" "nomadstack" {
  vpc_id = aws_vpc.nomadstack.id

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nomadstack.id
  }

  tags = local.common_tags
}

resource "aws_route_table_association" "main" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.nomadstack.id
}

# INSTANCES & CONFIG

resource "aws_launch_configuration" "server_launch" {
  name_prefix   = "nomadstack-server"
  image_id      = var.base_amis[var.region]
  instance_type = var.server_instance_type
  key_name      = var.key_name

  security_groups             = [aws_security_group.nomadstack.id]
  associate_public_ip_address = var.associate_public_ip_address

  iam_instance_profile = aws_iam_instance_profile.auto-join.name

  user_data = templatefile(
    "${path.module}/templates/startup.sh.tpl",
    merge(local.launch_base_user_data, {
      nomad_config  = local.nomad_server_config
      is_server     = true
    })
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "client_launch" {
  name_prefix   = "nomadstack-client"
  image_id      = var.base_amis[var.region]
  instance_type = var.client_instance_type
  key_name      = var.key_name

  security_groups             = [aws_security_group.nomadstack.id]
  associate_public_ip_address = var.associate_public_ip_address

  iam_instance_profile = aws_iam_instance_profile.auto-join.name

  user_data = templatefile(
    "${path.module}/templates/startup.sh.tpl",
    merge(local.launch_base_user_data, {
      nomad_config  = local.nomad_client_config
      is_server     = false
    })
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "servers" {
  desired_capacity = var.desired_servers
  max_size         = var.max_servers
  min_size         = var.min_servers

  launch_configuration = aws_launch_configuration.server_launch.name
  vpc_zone_identifier  = aws_subnet.public.*.id

  target_group_arns = [ aws_alb_target_group.nomad_servers.arn ]

  tags = [
    {
      key                 = "Name"
      value               = "${var.cluster_name}-server"
      propagate_at_launch = true
    },
    {
      key                 = var.retry_join.tag_key
      value               = "${var.retry_join.tag_value_prefix}-${var.cluster_name}"
      propagate_at_launch = true
    },
    {
      key                 = "Use"
      value               = var.common_tag
      propagate_at_launch = true
    }
  ]
}

resource "aws_autoscaling_group" "clients" {
  desired_capacity = var.desired_clients
  max_size         = var.max_servers
  min_size         = var.min_servers

  launch_configuration = aws_launch_configuration.client_launch.name
  vpc_zone_identifier  = aws_subnet.public.*.id

  target_group_arns = [
    aws_alb_target_group.nomad_clients.arn
  ]

  tags = [
    {
      key                 = "Name"
      value               = "${var.cluster_name}-client"
      propagate_at_launch = true
    },
    {
      key                 = var.retry_join.tag_key
      value               = "${var.retry_join.tag_value_prefix}-${var.cluster_name}"
      propagate_at_launch = true
    },
    {
      key                 = "Use"
      value               = var.common_tag
      propagate_at_launch = true
    }
  ]
}

# LOAD BALANCING

resource "aws_alb" "nomad_servers" {
  name            = "${var.cluster_name}-nomad-servers"
  security_groups = [aws_security_group.nomadstack.id]
  subnets         = aws_subnet.public.*.id
  internal        = false
  idle_timeout    = 60

  tags = local.common_tags
}

resource "aws_alb_target_group" "nomad_servers" {
  name     = "${var.cluster_name}-nomad-servers"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = aws_vpc.nomadstack.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/v1/agent/health"
    port                = 4646
  }

  tags = local.common_tags
}

resource "aws_alb_listener" "nomad_servers" {
  load_balancer_arn = aws_alb.nomad_servers.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.nomad_servers.arn
  }

  tags = local.common_tags
}

resource "aws_autoscaling_attachment" "nomad_servers" {
  autoscaling_group_name = aws_autoscaling_group.servers.id
  alb_target_group_arn   = aws_alb_target_group.nomad_servers.arn
}

# LOAD BALANCING - NOMAD CLIENTS

# NOTE: The first LB and associated resouces are to get to
# the Nomad UI on the clients. When attached, this makes TF wait
# for a healthy state for the client ASG until it completes.

# This might not be necessary, but there may be some reason you
# would want to get to the Nomad client UI, and I'm keeping it
# as an easy way to block on the client ASG & Nomad health.

# Scroll down for the other Nomad Client ASG which is meant
# for exposing load balancers or applications to the public.

resource "aws_alb" "nomad_clients" {
  name            = "${var.cluster_name}-nomad-clients"
  security_groups = [aws_security_group.nomadstack.id]
  subnets         = aws_subnet.public.*.id
  internal        = false
  idle_timeout    = 60

  tags = local.common_tags
}

resource "aws_alb_target_group" "nomad_clients" {
  name     = "${var.cluster_name}-nomad-clients"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = aws_vpc.nomadstack.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/v1/agent/health"
    port                = 4646
  }

  tags = local.common_tags
}

resource "aws_alb_listener" "nomad_clients" {
  load_balancer_arn = aws_alb.nomad_clients.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.nomad_clients.arn
  }

  tags = local.common_tags
}

resource "aws_autoscaling_attachment" "nomad_clients" {
  autoscaling_group_name = aws_autoscaling_group.clients.id
  alb_target_group_arn   = aws_alb_target_group.nomad_clients.arn
}

# NOTE: This load balancer is meant to expose a load balancer
# on the clients to the general public.

# It does not have a health check associated with it, as
# the Nomad job to configure a load balances has likely
# not been deployed yet.

resource "aws_alb" "nomad_clients_lb" {
  name            = "${var.cluster_name}-nomad-clients-lb"
  security_groups = [aws_security_group.nomadstack.id]
  subnets         = aws_subnet.public.*.id
  internal        = false
  idle_timeout    = 60

  tags = local.common_tags
}

resource "aws_alb_target_group" "nomad_clients_lb" {
  name     = "${var.cluster_name}-nomad-clients-lb"
  port     = var.nomad_client_appliicaton_port // 8080 default
  protocol = "HTTP"
  vpc_id   = aws_vpc.nomadstack.id

  tags = local.common_tags
}

resource "aws_alb_listener" "nomad_clients_lb" {
  load_balancer_arn = aws_alb.nomad_clients_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.nomad_clients_lb.arn
  }

  tags = local.common_tags
}

resource "aws_autoscaling_attachment" "nomad_clients_lb" {
  autoscaling_group_name = aws_autoscaling_group.clients.id
  alb_target_group_arn   = aws_alb_target_group.nomad_clients_lb.arn
}


# OUTPUTS

output "nomad_server_url" {
  value = "http://${aws_alb.nomad_servers.dns_name}"
}

output "nomad_client_lb_url" {
  value = "http://${aws_alb.nomad_clients_lb.dns_name}"
}
