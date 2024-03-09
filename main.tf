terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.17.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "this variable accepts project id"
}

variable "credentials_path" {
  type        = string
  description = "path to cred"
}

variable "provider_region" {
  type        = string
  description = "provider region"
}

variable "provider_region_zone" {
  type        = string
  description = "provider region zone"
}

variable "vpc_name" {
  type        = string
  description = "name of vpc"
}

variable "vpc_subnet_1" {
  type        = string
  description = "name of subnet-1"
}

variable "vpc_subnet_1_region" {
  type        = string
  description = "subnet-1 region"
}

variable "vpc_subnet_1_cidr" {
  type        = string
  description = "subnet-1 cidr"
}

variable "vpc_subnet_2" {
  type        = string
  description = "name of subnet-2"
}

variable "vpc_subnet_2_region" {
  type        = string
  description = "subnet-2 region"
}

variable "vpc_subnet_2_cidr" {
  type        = string
  description = "subnet-2 cidr"
}

variable "route_name" {
  type        = string
  description = "compute route name"
}

variable "compute_intstance_name" {
  type = string
  description = "Compute Instance Name"
}

variable "db_deletion_protection" {
  type = bool
  description = "prevents deletion - false"
  default = false
}

variable "db_availability" {
  type = string
  description = "db availability defaults - REGIONAL"
  default = "REGIONAL"
}

variable "db_disk_type" {
  type = string
  description = "db disk_type - pd-ssd"
  default = "pd-ssd"
}

variable "db_disk_size" {
  type = number
  description = "db disk_size - pd-ssd"
  default = 100
}

variable "db_ipv4_enabled" {
  type = bool
  description = "db ipv4_enabled - false"
  default = false
}

variable "db_name" {
  type = string
  description = "db database"
  default = "webapp"
}

provider "google" {
  credentials = var.credentials_path
  project     = var.project_id
  region      = var.provider_region
  zone        = var.provider_region_zone
}

resource "google_compute_network" "vpc6225" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_global_address" "private_ip_address" {
  name          = "webapp-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  ip_version = "IPV4"
  prefix_length = 20
  network       = google_compute_network.vpc6225.id
  depends_on = [ google_compute_network.vpc6225 ]
}

resource "google_service_networking_connection" "connection" {
  network                 = google_compute_network.vpc6225.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
  depends_on = [ google_compute_network.vpc6225, google_compute_global_address.private_ip_address ]
}

resource "google_compute_subnetwork" "webapp" {
  name          = var.vpc_subnet_1
  ip_cidr_range = var.vpc_subnet_1_cidr
  network       = google_compute_network.vpc6225.name
  region        = var.vpc_subnet_1_region
  private_ip_google_access = true
  depends_on    = [google_compute_network.vpc6225]
}

resource "google_compute_subnetwork" "db" {
  name          = var.vpc_subnet_2
  ip_cidr_range = var.vpc_subnet_2_cidr
  network       = google_compute_network.vpc6225.name
  region        = var.vpc_subnet_2_region
  depends_on    = [google_compute_network.vpc6225]
}

resource "google_compute_route" "routewebapp" {
  name        = var.route_name
  dest_range = "0.0.0.0/0"
  network     = google_compute_network.vpc6225.name
  tags = [ "http-webapp" ]
  next_hop_gateway = "default-internet-gateway"
  depends_on  = [google_compute_network.vpc6225, google_compute_subnetwork.webapp]
}

resource "google_compute_firewall" "allow_http" {
  name        = "webapphttpallow"
  network     = google_compute_network.vpc6225.name
  description = "creates firewall rule targetting tagged instances to allow http traffic"
  allow {
    protocol = "tcp"
    ports    = ["8030"]
  }
  priority      = 999
  target_tags   = ["http-webapp"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "deny_ssh" {
  name        = "webappsshdeny"
  network     = google_compute_network.vpc6225.name
  description = "creates firewall rule targetting tagged instances to deny ssh traffic"
  deny {
    protocol = "all"
  }
  priority      = 1000
  target_tags   = ["http-server"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_sql_database_instance" "MYSQL" {
  database_version = "MYSQL_8_0"
  deletion_protection = var.db_deletion_protection
  settings {
    availability_type = var.db_availability
    tier    = "db-f1-micro"
    disk_type = var.db_disk_type
    disk_size = var.db_disk_size
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
    ip_configuration {
      ipv4_enabled = var.db_ipv4_enabled
      private_network = google_compute_network.vpc6225.id
    }
  }
  
  depends_on = [ google_compute_network.vpc6225, google_service_networking_connection.connection, google_compute_global_address.private_ip_address]
}

resource "google_sql_database" "webappDb" {
  name = var.db_name
  instance = google_sql_database_instance.MYSQL.name
}

resource "google_sql_user" "sqlUser" {
  name = "webapp"
  instance = google_sql_database_instance.MYSQL.name
  password = random_password.password.result
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}


# This code is compatible with Terraform 4.25.0 and versions that are backwards compatible to 4.25.0.
# For information about validating this Terraform code, see https://developer.hashicorp.com/terraform/tutorials/gcp-get-started/google-cloud-platform-build#format-and-validate-the-configuration

resource "google_compute_instance" "webapp_vm" {
  boot_disk {
    auto_delete = true
    device_name = var.compute_intstance_name

    initialize_params {
      image = "projects/${var.project_id}/global/images/webapp-custom-image"
      size  = 100
      type  = "pd-balanced"
    }

    mode = "READ_WRITE"
  }
  
  metadata = {
    startup-script = <<-EOF
    #!/bin/bash
    echo "export MYSQL_APP_USER=${google_sql_user.sqlUser.name}" >> /etc/environment
    echo "export MYSQL_APP_PASSWORD=${google_sql_user.sqlUser.password}" >> /etc/environment
    echo "export MYSQL_APP_HOST=${google_sql_database_instance.MYSQL.private_ip_address}" >> /etc/environment
  EOF
  }
  can_ip_forward      = false
  deletion_protection = false
  enable_display      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = "e2-medium"
  name         = var.compute_intstance_name

  network_interface {
    access_config {
      network_tier = "STANDARD"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork = google_compute_subnetwork.webapp.name
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email  = "1018450228601-compute@developer.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  tags = ["http-webapp"]
  zone = var.provider_region_zone

  depends_on = [ google_compute_subnetwork.webapp, google_sql_database_instance.MYSQL ]
}


