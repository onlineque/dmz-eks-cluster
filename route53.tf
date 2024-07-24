module "zones" {
  source  = "github.com/terraform-aws-modules/terraform-aws-route53//modules/zones?ref=v2.10.2"

  zones = {
    "${var.cluster_name}.private" = {
      comment = "${var.cluster_name} DNS zone for external-dns"
      vpc     = [
        {
          vpc_id = var.vpc_id
        }
      ],
      tags    = local.tags
    }

    "${var.cluster_name}.${var.private_zone_suffix}" = {
      comment = "${var.cluster_name} DNS zone (new naming) for external-dns"
      vpc     = [
        {
          vpc_id = var.vpc_id
        }
      ],
      tags    = local.tags
    }
  }
}

resource "aws_route53_vpc_association_authorization" "route53_association_authorization" {
  count   = length(module.zones.route53_zone_zone_id)
  vpc_id  = var.transit_vpc_id
  zone_id = values(module.zones.route53_zone_zone_id)[count.index]
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
