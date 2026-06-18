resource "google_compute_network" "main" {
  name                    = "${var.cluster_name}-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.cluster_name}-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.main.id
  ip_cidr_range = "10.0.0.0/20"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.4.0.0/14"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.8.0.0/20"
  }

  private_ip_google_access = true
}

# Private node public egress.
resource "google_compute_router" "main" {
  name    = "${var.cluster_name}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name                               = "${var.cluster_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.main.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}