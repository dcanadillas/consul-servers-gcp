resource "google_compute_health_check" "autohealing" {
  name                = "autohealing-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10 # 50 seconds

  http_health_check {
    request_path = "/healthz"
    port         = "8080"
  }
}

locals {
  vm_image = var.use_hcp_packer ? data.hcp_packer_artifact.consul-nomad[0].external_identifier : data.google_compute_image.my_image.self_link
  consul_bootstrap_token = var.consul_bootstrap_token == "" ? random_uuid.consul_bootstrap_token.result : var.consul_bootstrap_token
  consul_fqdn = var.create_dns ? trimsuffix(google_dns_record_set.dns[0].name,".") : var.consul_fqdn != "" ? var.consul_fqdn : "${google_compute_address.global-ip.address}.nip.io"
}

resource "google_compute_region_instance_group_manager" "consul" {
  name = "consul-server-igm"

  base_instance_name         = "server"
  region                     = var.gcp_region
  distribution_policy_zones  = slice(data.google_compute_zones.available.names, 0, 3)

  version {
    instance_template = google_compute_instance_template.servers.self_link
  }

  all_instances_config {
    metadata = {
      component = "server"
    }
    labels = {
      server = "voter"
    }
  }

  update_policy {
    type  = "PROACTIVE"
    minimal_action = "REPLACE"
    max_unavailable_fixed = floor(var.numnodes / 2)
  }


  # target_pools = [google_compute_target_pool.appserver.id]
  target_size  = var.numnodes

  named_port {
    name = "consul"
    port = 8500
  }
  named_port {
    name = "consul-sec"
    port = 8501
  }
  named_port {
    name = "consul-grpc"
    port = 8502
  }
  named_port {
    name = "consul-lan"
    port = 8301
  }
  named_port {
    name = "consul-wan"
    port = 8302
  }
  named_port {
    name = "consul-server"
    port = 8300
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.autohealing.id
    initial_delay_sec = 300
  }
}

# Creating the instance template to be use from instances
resource "google_compute_instance_template" "servers" {
  # count = var.numnodes
  name_prefix  = "servers-"
  machine_type = var.gcp_instance
  region       = var.gcp_region

  tags = [var.cluster_name,var.owner,"consul-${var.cluster_name}"]

  // boot disk
  disk {
    source_image = local.vm_image
    device_name = "consul-${var.cluster_name}"
    # source = google_compute_region_disk.vault_disk.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link

    access_config {
      # nat_ip = google_compute_address.server_addr.address
    }
  }

  metadata_startup_script = templatefile("${path.module}/templates/template.tpl",{
    dc_name = var.cluster_name,
    gcp_project = var.gcp_project,
    tag = var.cluster_name,
    consul_license = var.consul_license,
    region = var.gcp_region,
    bootstrap_token = local.consul_bootstrap_token,
    consul_fqdn = local.consul_fqdn,
    consul_ca = var.create_certs ? "${tls_self_signed_cert.ca.cert_pem}" : "",
    consul_ca_key = var.create_certs ? "${tls_private_key.ca.private_key_pem}" : "",
    consul_cert = var.create_certs ? "${tls_locally_signed_cert.server.cert_pem}" : "",
    consul_key = var.create_certs ? "${tls_private_key.server.private_key_pem}" : "",
  })

  service_account {
    email  = data.google_service_account.owner_project.email
    scopes = ["cloud-platform", "compute-rw", "compute-ro", "userinfo-email", "storage-ro"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
