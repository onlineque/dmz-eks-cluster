locals {
  monitoring_namespace        = "prometheus"
  loki_bucket                 = var.loki_bucket
  loki_serviceaccount         = "${local.monitoring_namespace}:loki-sa"
  loki_gateway_monitoring_url = "http://loki-gateway.${local.monitoring_namespace}.svc.cluster.local"
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = local.monitoring_namespace
  }
}

resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "48.1.0"
  namespace  = local.monitoring_namespace
  values = [
    templatefile("${path.module}/helm/kube-prometheus-stack/template/values.yaml.tmpl",
      {
        prometheus_route53_fqdn  = var.prometheus_route53_fqdn
        prometheus_internal_fqdn = var.prometheus_internal_fqdn
    })
  ]

  depends_on = [time_sleep.wait_for_eks_addons,kubernetes_namespace.monitoring]
}

# loki
data "aws_iam_policy_document" "loki_s3_bucket_policy" {
  statement {
    sid    = "RestrictAccessToSpecificRole"
    effect = "Allow"
    resources = ["arn:aws:s3:::${local.loki_bucket}",
      "arn:aws:s3:::${local.loki_bucket}/*",
    ]
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = [module.loki_s3_irsa.iam_role_arn]
    }
  }

  statement {
    sid    = "DenyAllOtherAccess"
    effect = "Deny"
    resources = ["arn:aws:s3:::${local.loki_bucket}",
      "arn:aws:s3:::${local.loki_bucket}/*",
    ]
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

module "loki_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "3.10.1"

  bucket = local.loki_bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true


  force_destroy                         = true
  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true


  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  versioning = {
    enabled = false
  }

  lifecycle_rule = [
    {
      id = "rule-to-intelligent-tiering"
      transition = {
        days          = 0
        storage_class = "INTELLIGENT_TIERING"
      }

      status = "Enabled"
    }
  ]

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  policy = data.aws_iam_policy_document.loki_s3_bucket_policy.json

  tags = var.tags
}

data "aws_iam_policy_document" "loki_s3_policy" {
  statement {
    sid    = ""
    effect = "Allow"

    resources = [
      "arn:aws:s3:::${local.loki_bucket}",
      "arn:aws:s3:::${local.loki_bucket}/*",
    ]

    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]
  }
}

module "loki_s3_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "5.17.0"

  name        = "loki-s3"
  description = "Access to loki S3 bucket from loki itself"
  tags        = var.tags
  policy      = data.aws_iam_policy_document.loki_s3_policy.json
}

module "loki_s3_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version = "5.17.0"

  role_name        = "loki-s3-irsa"
  role_description = "IRSA for Loki to access its S3 bucket"
  role_policy_arns = {
    policy = module.loki_s3_policy.arn
  }

  cluster_service_accounts = {
    "${var.cluster_name}" = [
      local.loki_serviceaccount,
    ]
  }

  depends_on = [
    module.eks
  ]

  tags = var.tags
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = local.monitoring_namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "5.5.11"
  values = [
    templatefile("${path.module}/templates/loki-values.yaml.tmpl",
      {
        loki_bucket                = local.loki_bucket
        sa_role_arn                = module.loki_s3_irsa.iam_role_arn
        region                     = var.aws_region
        loki_gateway_route53_fqdn  = var.loki_gateway_route53_fqdn
        loki_gateway_internal_fqdn = var.loki_gateway_internal_fqdn
    })
  ]
  #won't create resource unless namespace 'monitoring' is created and addons up
  depends_on = [kubernetes_namespace.monitoring,time_sleep.wait_for_eks_addons]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = local.monitoring_namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "6.11.3"
  values = [
    templatefile("${path.module}/templates/promtail-values.yaml.tmpl",
      {
        loki_gateway_monitoring_url = local.loki_gateway_monitoring_url
    })
  ]
  #won't create resource unless namespace 'monitoring' is created
  depends_on = [kubernetes_namespace.monitoring,time_sleep.wait_for_eks_addons]
}

resource "helm_release" "kubernetes_event_exporter" {
  name       = "kubernetes-event-exporter"
  namespace  = local.monitoring_namespace
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kubernetes-event-exporter"
  version    = "2.5.3"
  values = [
    templatefile("${path.module}/templates/kubernetes-event-exporter.yaml.tmpl",
      {
        loki_gateway_monitoring_url = local.loki_gateway_monitoring_url
    })
  ]
  #won't create resource unless namespace 'monitoring' is created
  depends_on = [kubernetes_namespace.monitoring,time_sleep.wait_for_eks_addons]
}
