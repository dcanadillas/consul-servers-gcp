variable "gcp_project" {
  description = "GCP Project"
}
variable "sshuser" {
  description = "Username for SSH"
}
variable "gcp_zone" {
  description = "GCP Zone"
  default = "europe-west1-c"
}
variable "image" {
  default = "consul"
}
variable "consul_version" {
  default = "1.17.1"
}
variable "image_family" {
  default = "hashistack"
}
variable "source_image_family" {
  default = "debian-11"
}
variable "owner" {
  default = "dcanadillas"
}

locals {
  consul_version = regex_replace(var.consul_version,"\\.+|\\+","-")
}


source "googlecompute" "consul" {
  project_id = var.gcp_project
  source_image_family = var.source_image_family
  image_name = "${var.image}-${local.consul_version}"
  image_family = var.image_family
  machine_type = "n2-standard-2"
  # disk_size = 50
  ssh_username = var.sshuser
  zone = var.gcp_zone
  # image_licenses = ["projects/vm-options/global/licenses/enable-vmx"]
}


build {
  hcp_packer_registry {
    bucket_name = "consul"
    description = <<EOT
Image for Consul
    EOT
    bucket_labels = {
      "hashicorp"    = "Consul",
      "owner" = "${var.owner}",
      "platform" = "hashicorp",
    }
    build_labels = {
      "consul_version" = "${var.consul_version}"
    }
  }
  sources = ["sources.googlecompute.consul"]
  provisioner "shell" {
    scripts = ["../consul_prep.sh"]
    # execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo '{{ .Path }}'"
    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
    ]
  }
}