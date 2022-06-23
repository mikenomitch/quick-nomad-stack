// ==========================
// == SECURITY GROUP RULES ==
// ==========================

// == HTTP ==

resource "aws_security_group_rule" "allow_http_inbound" {
  type        = "ingress"
  from_port   = var.http_port_from
  to_port     = var.http_port_to
  protocol    = "tcp"
  cidr_blocks = [var.whitelist_ip]

  security_group_id = aws_security_group.hashistack.id
}

// == RPC ==

resource "aws_security_group_rule" "allow_rpc_inbound" {
  type        = "ingress"
  from_port   = var.rpc_port
  to_port     = var.rpc_port
  protocol    = "tcp"
  cidr_blocks = [var.whitelist_ip]

  security_group_id = aws_security_group.hashistack.id
}

// == TCP ==

resource "aws_security_group_rule" "allow_serf_tcp_inbound" {
  type        = "ingress"
  from_port   = var.serf_port
  to_port     = var.serf_port
  protocol    = "tcp"
  cidr_blocks = [var.whitelist_ip]

  security_group_id = aws_security_group.hashistack.id
}

// == UDP ==

resource "aws_security_group_rule" "allow_serf_udp_inbound" {
  type        = "ingress"
  from_port   = var.serf_port
  to_port     = var.serf_port
  protocol    = "udp"
  cidr_blocks = [var.whitelist_ip]

  security_group_id = aws_security_group.hashistack.id
}

// == SSH ==

resource "aws_security_group_rule" "allow_ssh_inbound" {
  type        = "ingress"
  from_port   = var.ssh_port
  to_port     = var.ssh_port
  protocol    = "tcp"
  cidr_blocks = [var.whitelist_ip]

  security_group_id = aws_security_group.hashistack.id
}

// == OUTBOUND ==

resource "aws_security_group_rule" "allow_all_outbound" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.hashistack.id
}

// =====================
// == SECURITY GROUPS ==
// =====================

resource "aws_security_group" "hashistack" {
  name_prefix = var.cluster_name
  description = "Security group for the ${var.cluster_name} launch configuration"
  // if this is empty, does it set it up on the parent vpc
  vpc_id      = aws_vpc.hashistack.id
}

// =================
// == PERMISSIONS ==
// =================

// Allow nomad auto-join

data "aws_iam_policy_document" "describe-instances" {
  statement {
    effect  = "Allow"
    actions = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "assume-role" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "auto-join" {
  name        = "auto-join-${var.region}-${var.cluster_name}"
  description = "Allows Nomad nodes to describe instances for joining."
  policy      =  data.aws_iam_policy_document.describe-instances.json
}

resource "aws_iam_role" "auto-join" {
  name = "auto-join-${var.region}-${var.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.assume-role.json
}

resource "aws_iam_policy_attachment" "auto-join" {
  name       = "auto-join-${var.region}-${var.cluster_name}"
  roles      = [aws_iam_role.auto-join.name]
  policy_arn = aws_iam_policy.auto-join.arn
}

resource "aws_iam_instance_profile" "auto-join" {
  name = "auto-join-${var.region}-${var.cluster_name}"
  role = aws_iam_role.auto-join.name
}
