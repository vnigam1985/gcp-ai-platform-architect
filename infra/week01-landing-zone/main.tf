# =============================================================================
# Week 1: a private network for AI workloads
# -----------------------------------------------------------------------------
#   - The Google APIs the course uses, turned on
#   - A custom-mode VPC with one subnet in Montreal, 10.30.0.0/24
#       * Private Google Access ON: machines with no external IP can still
#         reach Google APIs (Gemini, Artifact Registry, Secret Manager...)
#       * VPC flow logs ON
#   - No Cloud NAT and no external IPs anywhere: nothing can reach the internet
#   - Firewall: SSH only from Google's IAP range (for the week 2 test VM) and
#     traffic inside the VPC. With no NAT and no external IPs, there is no path
#     to the internet; Private Google Access is the only way out, to Google APIs
#   - A Serverless VPC subnet for Cloud Run Direct VPC egress (weeks 4 and 5)
# =============================================================================

locals {
  apis = [
    "compute.googleapis.com",
    "aiplatform.googleapis.com",
    "dns.googleapis.com",
    "iap.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudbuild.googleapis.com",
    "modelarmor.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "lab" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "workloads" {
  name                     = "${var.prefix}-workloads"
  network                  = google_compute_network.lab.id
  region                   = var.region
  ip_cidr_range            = "10.30.0.0/24"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "serverless" {
  # Cloud Run services and jobs attach here with Direct VPC egress.
  name                     = "${var.prefix}-serverless"
  network                  = google_compute_network.lab.id
  region                   = var.region
  ip_cidr_range            = "10.30.1.0/26"
  private_ip_google_access = true
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "${var.prefix}-allow-iap-ssh"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"] # Google's IAP TCP forwarding range
  target_tags   = ["jumpbox"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "internal" {
  name          = "${var.prefix}-allow-internal"
  network       = google_compute_network.lab.id
  direction     = "INGRESS"
  source_ranges = ["10.30.0.0/23"]
  allow {
    protocol = "all"
  }
}

output "network_id" { value = google_compute_network.lab.id }
output "network_name" { value = google_compute_network.lab.name }
output "subnet_id" { value = google_compute_subnetwork.workloads.id }
output "serverless_subnet_id" { value = google_compute_subnetwork.serverless.id }
