data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

data "aws_availability_zones" "available" {}

locals {
  region   = var.aws_region
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [ var.vpc_subnet1_id, var.vpc_subnet2_id ]
  private_subnets_cidr_blocks = [ var.csr1-cidr-block, var.csr2-cidr-block ]

  tags = var.tags

  nginx_ingress_server_snippet = <<EOT
    client_max_body_size 50m;
    listen 8000;
    if ( $server_port = 80 ) {
      return 308 https://$host$request_uri;
    }
  EOT
}

################################################################################
# Cluster
################################################################################

#tfsec:ignore:aws-eks-enable-control-plane-logging
module "eks" {
  # source = "github.com/aws-ia/terraform-aws-eks-blueprints?ref=v4.32.1"
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.13"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version

  ####
  # Backwards compatibility
  ####
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = false
  cluster_enabled_log_types      = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  iam_role_name                  = "${var.cluster_name}-cluster-role"
  iam_role_use_name_prefix       = false
  kms_key_aliases = [var.cluster_name]
  create_cloudwatch_log_group = false

  # Todo: define what this is and how to import it
  # platform_teams    = var.platform_teams
  # application_teams = var.application_teams

  vpc_id     = var.vpc_id
  subnet_ids = local.private_subnets

  manage_aws_auth_configmap = true
  aws_auth_roles = flatten([
    module.admin_team.aws_auth_configmap_role,
  ])

  eks_managed_node_groups = {
    for k1, v1 in var.managed_node_groups :
        k1 => {
            ####
            # Backwards compatibility
            ####
            iam_role_name              = "${var.cluster_name}-${k1}"
            iam_role_use_name_prefix   = false
            use_custom_launch_template = false

            instance_types = v1.instance_types
            min_size = v1.min_size
            max_size = v1.max_size
            desired_size = v1.desired_size
            disk_size = v1.disk_size
            tags = v1.labels

            iam_role_additional_policies = {
              AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
            }
        }
  }

  #create_cluster_security_group = false
  #create_node_security_group    = false

  tags = local.tags
}

# Backward compatibility
resource aws_iam_instance_profile "managed_ng" {
  name = "${var.cluster_name}-initial"
}
resource "aws_iam_role_policy_attachment" "managed_ng" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = "${var.cluster_name}-initial" # linked to ${var.cluster_name}-managed_node_groups-$k1
}


################################################################################
# Kubernetes Teams
################################################################################

module "admin_team" {
  source = "aws-ia/eks-blueprints-teams/aws"

  name = "admin-team"

  # Enables elevated, admin privileges for this team
  enable_admin = true
  users        = [var.admin_team_arn]
  cluster_arn  = module.eks.cluster_arn
}

################################################################################
# Kubernetes Addon
################################################################################

module "eks_blueprints_addon" {
  source = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  # Disable helm release
  create_release = false

  # IAM role for service account (IRSA)
  create_role = true
  create_policy = false
  role_name   = "aws-vpc-cni-ipv4"
  role_policies = {
    AmazonEKS_CNI_Policy = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }

  oidc_providers = {
    this = {
      provider_arn    = module.eks.oidc_provider_arn
      namespace       = "kube-system"
      service_account = "aws-node"
    }
  }

  tags = {
    Environment = "dev"
  }
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = "${var.cluster_name}-ebs-csi-driver-"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

################################################################################
# Kubernetes Addons
################################################################################

module "eks_blueprints_kubernetes_addons" {
  # source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.32.1"
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-efs-csi-driver = {
      most_recent = true
    }
  }

  # Enable Metrics server
  enable_metrics_server = true

  # Enable EFS CSI driver
  enable_aws_efs_csi_driver = true

  # Todo
  # Enable EBS CSI driver
  # enable_amazon_eks_aws_ebs_csi_driver = true

  # Enable Cluster Autoscaler
  enable_cluster_autoscaler = true

  # Enable Prometheus
  # enable_prometheus = true
  # prometheus_helm_config = {
  #    set = [
  #      {
  #         name  = "server.ingress.enabled"
  #         value = "true"
  #      },
  #      {
  #         name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/group\\.name"
  #         value = "prometheus"
  #      },
  #      {
  #         name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
  #         value = "[{\"HTTP\": 80}\\,{\"HTTPS\": 443}]"
  #      },
  #      {
  #         name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
  #         value = "${aws_acm_certificate.wildcard_ssl_certificate.arn}"
  #      },
  #      {
  #         name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
  #         value = "internal"
  #      },
  #      {
  #         name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
  #         value = "443"
  #      },
  #      {
  #         name  = "server.ingress.annotations.kubernetes\\.io/ingress\\.class"
  #         value = "alb"
  #      },
  #      {
  #         name  = "server.ingress.hosts[0]"
  #         value = "prometheus.${var.cluster_name}.private"
  #      },
  #      {
  #         name  = "server.ingress.hosts[1]"
  #         value = "prometheus-${var.cluster_name}.agcintranet.eu"
  #      },
  #      {
  #         name  = "server.ingress.tls[0].hosts[0]"
  #         value = "prometheus-${var.cluster_name}.agcintranet.eu"
  #      }
  #    ]
  #  }

  # Enable nginx ingress controller
  enable_ingress_nginx = true
  ingress_nginx = {
    set = [
      {
        name  = "controller.containerPort.http"
        value = "80"
      },
      {
        name  = "controller.containerPort.https"
        value = "443"
      },
      {
        name  = "controller.containerPort.special"
        value = "8000"
      },
      {
        name  = "controller.config.ssl-redirect"
        value = "false"
      },
      {
        name  = "controller.config.server-snippet"
        value = local.nginx_ingress_server_snippet
      },
      {
        name  = "controller.resources.limits.cpu"
        value = "1000m"
      },
      {
        name  = "controller.resources.limits.memory"
        value = "2048Mi"
      },
      {
        name  = "controller.service.enabled"
        value = "true"
      },
      {
        name  = "controller.service.ports.http"
        value = "80"
      },
      {
        name  = "controller.service.ports.https"
        value = "443"
      },
      {
        name  = "controller.service.targetPorts.http"
        value = "http"
      },
      {
        name  = "controller.service.targetPorts.https"
        value = "special"
      },
      {
        name  = "controller.service.type"
        value = "LoadBalancer"
      },
      {
        name  = "controller.service.external.enabled"
        value = "false"
      },
      {
        name  = "controller.service.internal.enabled"
        value = "true"
      },
      {
        name  = "controller.service.internal.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-internal"
        value = "true"
      },
      {
        name  = "controller.service.internal.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
        value = "ip"
      },
      {
        name  = "controller.service.internal.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
        value = "internal"
      },
      # {
      #   name  = "controller.service.internal.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-cert"
      #   value = aws_acm_certificate.wildcard_ssl_certificate.arn
      # },
      {
        name  = "controller.service.internal.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-ssl-ports"
        value = "443"
      },
      {
        name  = "controller.service.internal.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
        value = "nlb"
      },
      {
        name  = "controller.service.internal.ports.http"
        value = "80"
      },
      {
        name  = "controller.service.internal.ports.https"
        value = "443"
      },
      {
        name  = "controller.service.internal.targetPorts.http"
        value = "http"
      },
      {
        name  = "controller.service.internal.targetPorts.https"
        value = "special"
      }
    ]
  }

  # Enable Gatekeeper
  enable_gatekeeper = true
  gatekeeper = {
    values = [
      <<-EOT
        postInstall:
          labelNamespace:
            extraRules:
            - apiGroups:
              - management.cattle.io
              resources:
              - projects
              verbs:
              - updatepsa
      EOT
    ]
  }

  # Enable Velero
  enable_velero           = true
  velero = {
    s3_backup_location = module.s3_bucket_velero.s3_bucket_arn
  }

  # Enable external-dns
  enable_external_dns            = true
  external_dns_route53_zone_arns = [module.zones.route53_zone_zone_arn["${var.cluster_name}.private"]]

  external_dns = { # todo check
    # route53_zone_zone_arns = [module.zones.route53_zone_zone_arn["${var.cluster_name}.private"]]
    # private_zone      = true # deprecated
    addon_context = {
        eks_cluster_name = "${var.cluster_name}"
    }

    create_role = true

    set = [
      {
        name  = "policy"
        value = "sync"
      }
    ]
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
      values = [
        <<-EOT
          podDisruptionBudget:
            maxUnavailable: 1
          vpcId: ${var.vpc_id}
        EOT
      ]
  }

  tags = local.tags
  depends_on = [module.zones]
}

# TODO ?
#  private_subnet_tags = {
#    "kubernetes.io/role/internal-elb" = 1
#  }

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "~> 1.0"

  creation_token = var.cluster_name
  name           = var.cluster_name

  # Mount targets / security group
  mount_targets = {
    for k, v in zipmap(local.azs, local.private_subnets) : k => { subnet_id = v }
  }
  security_group_description = "${var.cluster_name} EFS security group"
  security_group_vpc_id      = var.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provdied for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = local.private_subnets_cidr_blocks
    }
  }

  tags = local.tags
}

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  parameters = {
    provisioningMode = "efs-ap" # Dynamic provisioning
    fileSystemId     = module.efs.id
    directoryPerms   = "700"
  }

  mount_options = [
    "iam"
  ]

  depends_on = [
    module.eks
  ]
}

module "s3_bucket_velero" {
  source = "github.com/terraform-aws-modules/terraform-aws-s3-bucket?ref=v3.7.0"

  bucket = "s3s-i-velero-${var.cluster_name}"

  # S3 bucket-level Public Access Block configuration
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  acl = "private"

  # S3 Bucket Ownership Controls
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  versioning = {
    status     = true
    mfa_delete = false
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  #intelligent_tiering = {
  #    general = {
  #      status = "Enabled"
  #      filter = {
  #        prefix = "/"
  #      }
  #      tiering = {
  #        DEEP_ARCHIVE_ACCESS = {
  #          days = 0
  #        }
  #      }
  #    }
  #  }

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  tags = local.tags
}
