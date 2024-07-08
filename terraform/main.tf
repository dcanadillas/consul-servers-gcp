resource "random_id" "server" {
  byte_length = 1
}

# Creating an UID fot the Consul Bootstrap Token
resource "random_uuid" "consul_bootstrap_token" {
}

# Collect client config for GCP
data "google_client_config" "current" {
}
data "google_service_account" "owner_project" {
  account_id = var.gcp_sa
}

data "google_compute_zones" "available" {
  region = var.gcp_region
}


data "google_compute_image" "my_image" {
  family  = var.image_family
  project = var.gcp_project
}

# Let's take the image from HCP Packer
data "hcp_packer_version" "hardened-source" {
  count = var.use_hcp_packer ? 1 : 0
  bucket_name  = var.hcp_packer_bucket
  channel_name = var.hcp_packer_channel
}

data "hcp_packer_artifact" "consul-nomad" {
  count              = var.use_hcp_packer ? 1 : 0
  bucket_name         = var.hcp_packer_bucket
  version_fingerprint = data.hcp_packer_version.hardened-source[0].fingerprint
  platform            = "gce"
  region              = var.hcp_packer_region
}


data "google_dns_managed_zone" "doormat_dns_zone" {
  count = var.create_dns ? 1 : 0
  name = var.dns_zone
}

resource "google_dns_record_set" "dns" {
  count = var.create_dns ? 1 : 0
  name = "consul.${data.google_dns_managed_zone.doormat_dns_zone[0].dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = data.google_dns_managed_zone.doormat_dns_zone[0].name

  rrdatas = [google_compute_address.global-ip.address]
}


