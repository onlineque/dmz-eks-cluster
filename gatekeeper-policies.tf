data "template_file" "gatekeeper-templates" {
  template = file("${path.module}/helm/gatekeeper-templates/template/values.yaml.tmpl")
  vars = {}
}

resource "helm_release" "gatekeeper-templates" {
  name      = "gatekeeper-templates"
  chart     = "${path.module}/helm/gatekeeper-templates/chart/"
  version   = "1.0.0"
  namespace = "gatekeeper-system"
  values    = [data.template_file.gatekeeper-templates.rendered]

  depends_on = [time_sleep.wait_for_eks_addons]
}

data "template_file" "gatekeeper-constraints" {
  template = file("${path.module}/helm/gatekeeper-constraints/template/values.yaml.tmpl")
  vars = {
    limits_cpu      = var.pod_cpu_limit
    limits_memory   = var.pod_memory_limit
    requests_cpu    = var.pod_cpu_requests
    requests_memory = var.pod_memory_requests
  }
}

resource "helm_release" "gatekeeper-constraints" {
  name      = "gatekeeper-constraints"
  chart     = "${path.module}/helm/gatekeeper-constraints/chart/"
  version   = "1.0.8"
  namespace = "gatekeeper-system"
  values    = [data.template_file.gatekeeper-constraints.rendered]

  depends_on = [time_sleep.wait_for_eks_addons, helm_release.gatekeeper-templates]
}

resource "time_sleep" "wait_for_eks_addons" {
  create_duration = "120s"
  # depends_on       = [module.eks_blueprints_kubernetes_addons]
}
