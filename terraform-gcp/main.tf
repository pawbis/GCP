#created project named terraform before
#service account
resource "google_service_account" "terraform-service" {
    account_id = "terraform-service"
}

#iam member and 
resource "google_project_iam_member" "terraform-service" {
    project = "terraform"
    role = "roles/owner"
    member = google_service_account.terraform-service.email
}

#vpc network
resource "google_compute_network" "vpc_network" {
    name = "terraform-network"
    routing_mode = "REGIONAL"
    auto_create_subnetworks = false
}

#subnetwork with ip ranges
resource "google_compute_subnetwork" "vpc_subnetwork" {
    name = "terraform-subnetwork"
    ip_cidr_range = "10.0.0.0/26"
    region = "europe-central2"
    network = google_compute_network.vpc_network.id
    private_ip_google_access = true

    secondary_ip_range {
        range_name = "gke-pods"
        ip_cidr_range = "10.10.0.0/28"
    }

    secondary_ip_range {
        range_name = "gke-svc"
        ip_cidr_range = "10.11.0.0/28"
    }
}

#gke settings
resource "google_container_cluster" "terraform-gke" {
    name = "terraform-gke"
    location = "europe-central2-a"
    remove_default_node_pool = true
    initial_node_count = 1
    network = google_compute_network.vpc_network.self_link
    subnetwork = google_compute_subnetwork.vpc_subnetwork.self_link
    logging_service = "logging.googleapis.com/kubernetes"
    monitoring_service = "monitoring.googleapis.com/kubernetes"
    networking_mode = "VPC_NATIVE"

    addons_config {
        horizontal_pod_autoscaling {
        disabled = true
        } 
    }
    release_channel {
      channel = "REGULAR"
    }
    ip_allocation_policy {
      cluster_secondary_range_name = "gke-pods"
      services_secondary_range_name = "gke-svc"
    }
    private_cluster_config {
      enable_private_nodes = true
      enable_private_endpoint = false
      master_ipv4_cidr_block = "172.16.0.0/28"
    }
}

#node
resource "google_container_node_pool" "terraform-node" {
    name = "terraform-node"
    cluster = google_container_cluster.terraform-gke.id
    node_count = 1

    management {
      auto_repair = true
      auto_upgrade = true
    }
    node_config {
        preemptible = false
        machine_type = "e2-small"

    service_account = google_service_account.terraform-service.email
    oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
     ]
    }
}