module "sgr-i-ALL-from-OnPremises" {
  source  = "github.com/terraform-aws-modules/terraform-aws-security-group?ref=v4.17.1"
  name        = "sgr-i-ALL-from-OnPremises"
  description = "All ports from On-Premises"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "all"
      description = "All ports"
      cidr_blocks = "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
    }
  ]
}
