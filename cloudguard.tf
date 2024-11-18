resource "kubernetes_manifest" "serviceaccount_cloudguard_controller" {
  manifest = {
    "apiVersion" = "v1"
    "kind"       = "ServiceAccount"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "cloudguard-controller"
      "namespace"         = "default"
    }
  }
}

resource "kubernetes_manifest" "clusterrole_endpoint_reader" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "endpoint-reader"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "endpoints",
        ]
        "verbs" = [
          "get",
          "list",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_allow_cloudguard_access_endpoints" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "allow-cloudguard-access-endpoints"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "endpoint-reader"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "cloudguard-controller"
        "namespace" = "default"
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrole_pod_reader" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "pod-reader"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "pods",
        ]
        "verbs" = [
          "get",
          "list",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_allow_cloudguard_access_pods" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "allow-cloudguard-access-pods"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "pod-reader"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "cloudguard-controller"
        "namespace" = "default"
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrole_service_reader" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "service-reader"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "services",
        ]
        "verbs" = [
          "get",
          "list",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_allow_cloudguard_access_services" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "allow-cloudguard-access-services"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "service-reader"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "cloudguard-controller"
        "namespace" = "default"
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrole_node_reader" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRole"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "node-reader"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "nodes",
        ]
        "verbs" = [
          "get",
          "list",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_allow_cloudguard_access_nodes" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind"       = "ClusterRoleBinding"
    "metadata" = {
      "creationTimestamp" = null
      "name"              = "allow-cloudguard-access-nodes"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind"     = "ClusterRole"
      "name"     = "node-reader"
    }
    "subjects" = [
      {
        "kind"      = "ServiceAccount"
        "name"      = "cloudguard-controller"
        "namespace" = "default"
      },
    ]
  }
}

resource "kubernetes_manifest" "secret_cloudguard_controller_secret" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Secret"
    "metadata" = {
      "annotations" = {
        "kubernetes.io/service-account.name" = "cloudguard-controller"
      }
      "name" = "cloudguard-controller-secret"
    }
    "type" = "kubernetes.io/service-account-token"
  }
}
