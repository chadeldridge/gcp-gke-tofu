variable "gcp_apis" {
  default = [
    "artifactregistry.googleapis.com",
    #"secretmanager.googleapis.com"
  ]
}

resource "google_project_service" "enabled_apis" {
  for_each           = toset(var.gcp_apis)
  service            = each.key
  disable_on_destroy = false
}
