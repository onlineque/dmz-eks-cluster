# locals {
#   secret_arn_root = "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.cluster_name}/certs"
# }
#
# data "aws_secretsmanager_secret_version" "wildcard_ssl_crt" {
#   secret_id = "${local.secret_arn_root}/${var.crt_secret}"
# }
#
# data "aws_secretsmanager_secret_version" "wildcard_ssl_key" {
#   secret_id = "${local.secret_arn_root}/${var.key_secret}"
# }
#
# data "aws_secretsmanager_secret_version" "ca_crt" {
#   secret_id = "${local.secret_arn_root}/${var.ca_crt_secret}"
# }
#
# resource "aws_acm_certificate" "wildcard_ssl_certificate" {
#   certificate_body  = data.aws_secretsmanager_secret_version.wildcard_ssl_crt.secret_string
#   private_key       = data.aws_secretsmanager_secret_version.wildcard_ssl_key.secret_string
#   certificate_chain = data.aws_secretsmanager_secret_version.ca_crt.secret_string
# }
