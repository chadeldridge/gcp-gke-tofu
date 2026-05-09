provider "google" {
  # Leave project blank to get from GOOGLE_PROJECT env var.
  # Otherwise set the GCP Project ID here.
	#project = ""
	region  = "us-east1"
	zone    = "us-east1-d"
}

resource "google_compute_network" "dev_network" {
  name                    = "dev-default"
  auto_create_subnetworks = "true"
}

resource "google_compute_instance" "vm_instance" {
  name         = "tf-instance"
  # e2-micro for free tier.
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    # Reference the network created above by the Terraform ID.
    # Example:
    # projects/$GOOGLE_PROJECT/zones/us-east1-c/networks/dev-default
    network = google_compute_network.dev_network.id
    access_config {
    }
  }
}
