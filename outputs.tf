output "further_instructions" {
  value = <<-EOT
    Set up the DNS forwarding on AD DNS by creating a forwarder (needs to be done just once after the EKS cluster has been created):

    EKS cluster usage instructions (for admins):
      Open SSO login page
      Choose appropriate account and role you have granted the admin access to EKS cluster. Click on "Command line or programmatic access".
      Copy the content of "Option 1: Set AWS environment variables (Short-term credentials)" and paste them into your terminal.
      Execute:
        aws eks update-kubeconfig --name ${var.cluster_name} --role-arn arn:aws:iam::${var.aws_account_id}:role/${var.cluster_name}-admin-team-access
      You are now ready to use kubectl / k9s to talk to your cluster.
  EOT
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "eks_cluster_auth_token" {
  value = data.aws_eks_cluster_auth.this.token
}

output "eks_cluster_arn" {
  value = module.eks.cluster_arn
}
