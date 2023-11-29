provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  # token                  = data.aws_eks_cluster_auth.this.token

  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = [ "eks", "get-token", "--cluster-name", var.cluster_name ]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    # token                  = data.aws_eks_cluster_auth.this.token

    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = [ "eks", "get-token", "--cluster-name", var.cluster_name ]
      command     = "aws"
    }
  }
}
