################################################################################
# Cluster Config
# Delete default node pool.
################################################################################
resource "google_container_cluster" "primary" {
  ###########################################
  # Cluster config
  ###########################################
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # Ensure all required GCP APIs are enabled before creating the cluster.
  depends_on = [ google_project_service.enabled_apis ]

  # Delete the node pool to use separately managed one.addons_config
  # This allows for node pool replacement withouth having to delete the cluster.
  # Setting to 1 node means only 1 node has to be built and deleted.
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  min_master_version = var.kubernetes_version

  # Enable cluster level Workload Identity.
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ###########################################
  # Networks
  ###########################################
  network    = var.network_name
  subnetwork = var.subnetwork_name

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Enable network policy Dataplane V2
  datapath_provider = "ADVANCED_DATAPATH"

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0"
      display_name = "All networks"
    }
  }

  ###########################################
  # Logging and Monitoring
  ###########################################
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  ###########################################
  # Security and Other
  ###########################################
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  release_channel {
    channel = "REGULAR"
  }
}

################################################################################
# Node Pool Config
################################################################################
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-primary-pool"
  location = var.region
  project  = var.project_id
  cluster  = google_container_cluster.primary.name

  # node_locations pins nodes to specific zones so node_count is not multiplied
  # across every zone in the region (regional cluster default behavior).
  node_locations = length(var.node_zones) > 0 ? var.node_zones : null

  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = "pd-ssd"

    # Use a minimal service account for nodes.
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable node level Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      cluster = var.cluster_name
      pool    = "primary"
    }
  }
}

################################################################################
# Service Account Config
################################################################################
# Minimal service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
  project      = var.project_id
}

# Grant minimal permissions to the node service account
resource "google_project_iam_member" "gke_nodes_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

resource "google_project_iam_member" "gke_nodes_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}
