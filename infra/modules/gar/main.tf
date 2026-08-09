data "google_project" "project" {}

resource "google_artifact_registry_repository" "docker_repo" {
  # checkov:skip=CKV_GCP_84: Google-managed encryption is sufficient for this environment; avoiding KMS key-management overhead
  # Ensure all required GCP APIs are enabled before creating the repository.
  depends_on = [google_project_service.enabled_apis]

  location        = var.region
  repository_id   = var.docker_repo_name
  deletion_policy = "Docker repository managed by Terraform"
  format          = "DOCKER"

  # Enable immutable tags
  #docker_config {
  #  immutable_tags = true
  #}

  labels = {
    environment      = var.env
    docker_repo_name = var.docker_repo_name
    managed_by       = "terraform"
  }

  # Pull in remote repositories.
  #remote_repository_config {
  #  description = "docker hub"
  #  docker_repository {
  #    public_repository = "DOCKER_HUB"
  #  }
  #}

  # Create virtual repository config with upstream policies.
  #virtual_repository_config {
  #  upstream_policies {
  #    id = "app_repo_upstream_1"
  #    repository = google_artifact_registry_repository.app_repo_upstream_1.id
  #    priority = 10
  #  }
  #  upstream_policies {
  #    id = "app_repo_upstream_2"
  #    repository = google_artifact_registry_repository.app_repo_upstream_2.id
  #    priority = 20
  #  }
  #}

  # Cleanup untagged images to help with cost control.
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state = "UNTAGGED"
    }
  }
  # Prevent deleting untagged images immediately.
  cleanup_policies {
    id     = "keep-new-untagged"
    action = "KEEP"
    condition {
      tag_state  = "UNTAGGED"
      newer_than = "${var.untagged_keep_days}d"
    }
  }
  cleanup_policies {
    id     = "keep-tagged-release"
    action = "KEEP"
    condition {
      tag_state    = "TAGGED"
      tag_prefixes = ["release"]
      #package_name_prefixes = ["webapp", "mobile"]
    }
  }
  # Cleanup old images to help with cost control.
  cleanup_policies {
    id     = "keep-most-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.versions_keep_count
    }
  }
}
