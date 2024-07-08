## ----- Network capabilities ------
# VPC creation
resource "google_compute_network" "network" {
  name = "${var.cluster_name}-network"
  routing_mode = "REGIONAL"
  auto_create_subnetworks = false
}


# Subnet creation
resource "google_compute_subnetwork" "subnet" {
  name = "${var.cluster_name}-subnetwork"

  ip_cidr_range = "10.2.0.0/16"
  region        = var.gcp_region
  network       = google_compute_network.network.id
}

# Create an ip address for the load balancer
resource "google_compute_address" "global-ip" {
  name = "consul-lb-ip"
  region = var.gcp_region
}

# Create firewall rules

resource "google_compute_firewall" "consul" {
  name    = "hashi-rules"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
    ports    = ["22","443","8500","8501","8600"]
  }
  # In case we want to connect external clients without specific closed routes
  allow {
    protocol = "udp"
    ports = ["8600","8301","8302"]
  }
  # We are creating a passthroough LB so we need to give access to the required ports from the LB
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [var.cluster_name,"consul-${var.cluster_name}"]
}

resource "google_compute_firewall" "internal" {
  name    = "hashi-internal-rules"
  network = google_compute_network.network.name

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }

  source_tags = [var.cluster_name,"consul-${var.cluster_name}"]
  target_tags   = [var.cluster_name,"consul-${var.cluster_name}"]
}     


# forwarding rule
resource "google_compute_forwarding_rule" "lb" {
  name = "consul-lb-${var.cluster_name}"
  backend_service = google_compute_region_backend_service.consul_backend.id
  region = var.gcp_region
  ip_address = google_compute_address.global-ip.address
  ip_protocol = "TCP"
  ports = [ 8500, 8501 ]
  # all_ports             = true
  # allow_global_access   = true
  # network = google_compute_network.network.id
  # subnetwork = google_compute_subnetwork.subnet.id
}

# backend service
resource "google_compute_region_backend_service" "consul_backend" {
  name = "consul-backend-${var.cluster_name}"
  region = var.gcp_region
  protocol = "TCP"
  health_checks = [google_compute_region_health_check.https_health_check.id]
  load_balancing_scheme = "EXTERNAL"
  backend {
    group  = google_compute_region_instance_group_manager.consul.instance_group
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_region_health_check" "https_health_check" {
  name = "https-health-check-${var.cluster_name}"
  region = var.gcp_region
  timeout_sec        = 1
  check_interval_sec = 1

  # https_health_check {
  #   port = "8501"
  #   request_path = "/v1/sys/health"
  # }
  tcp_health_check {
    port = "8501"
  }
}

