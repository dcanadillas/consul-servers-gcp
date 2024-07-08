output "CONSUL_HTTP_ADDR" {
  value = "https://${local.consul_fqdn}:8501"
}

output "CONSUL_HTTP_TOKEN" {
  value = local.consul_bootstrap_token
  sensitive = true
}

output "consul_ca" {
  value = var.create_certs ? tls_self_signed_cert.ca.cert_pem : "curl -k -H \"X-Consul-Token: ${local.consul_bootstrap_token}\" https://${local.consul_fqdn}:8501/v1/connect/ca/roots"
}