resource "aws_route53_zone" "not_shared_hosted_zone" {
  name = "${var.cluster_name}.private"
  comment = "${var.cluster_name} DNS zone for external-dns"

  vpc {
    vpc_id = var.vpc_id
  }
  tags    = local.tags

  # Prevent the deletion of associated VPCs after
  # the initial creation. See documentation on
  # aws_route53_zone_association for details
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_zone" "shared_hosted_zone" {
  name = "${var.cluster_name}.${var.private_zone_suffix}"
  comment = "${var.cluster_name} DNS zone (new naming) for external-dns"

  vpc {
    vpc_id = var.vpc_id
  }

  tags    = local.tags
  # Prevent the deletion of associated VPCs after
  # the initial creation. See documentation on
  # aws_route53_zone_association for details
  lifecycle {
    ignore_changes = [vpc]
  }
}

resource "aws_route53_vpc_association_authorization" "route53_association_authorization_not_shared" {
  vpc_id  = var.transit_vpc_id
  zone_id = aws_route53_zone.not_shared_hosted_zone.id
}

resource "aws_route53_vpc_association_authorization" "route53_association_authorization_shared" {
  vpc_id  = var.transit_vpc_id
  zone_id = aws_route53_zone.shared_hosted_zone.id
}

resource "aws_route53_resolver_endpoint" "dns_inbound_resolver" {
  name      = "dns_inbound_resolver"
  direction = "INBOUND"

  security_group_ids = [
    module.sgr-i-ALL-from-OnPremises.security_group_id
  ]

  ip_address {
    subnet_id = var.vpc_subnet1_id
  }

  ip_address {
    subnet_id = var.vpc_subnet2_id
  }

  tags = local.tags
}

data "aws_route53_resolver_endpoint" "dns_inbound_resolver" {
  resolver_endpoint_id = aws_route53_resolver_endpoint.dns_inbound_resolver.id
}
