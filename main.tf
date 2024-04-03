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

variable "image_name" {
  type = string
  description = "image name"
  default = "webapp-custom-image"
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

variable "db_username" {
  type = string
  description = "db database user name"
  default = "webapp"
}

variable "boot_disk_size" {
  type = number
  description = "vm boot disk size"
  default = 100
}

variable "dns_name" {
  type = string
  description = "dns name"
  default = "sanumula6225.me."
}

variable "dns_managed_zone" {
  type = string
  default = "webapp-public-zone"
}

variable "vm_account_id" {
  type = string
  description = "default dev account id"
  default = "webapp-vm"
}

variable "fn_account_id" {
  type = string
  description = "default dev account id"
  default = "email-fn"
}

variable "vm_machine_type" {
  type = string
  default = "e2-medium"
}

variable "db_machine_type" {
  type = string
  default = "db-f1-micro"
}

variable "pubsub_email_topic_name" {
  type = string
  default = "verify_email"
}

variable "storage_bucket_name" {
  type = string
  default = "csye6225_sanumula"
}

variable "fn_object_path" {
  type = string
  default = "functions/email_notifications/serverless.zip"
}

variable "min" {
  type = number
  default = 1
}

variable "max" {
  type = number
  default = 5
}

variable "cpu_util" {
  type = number
  default = 0.5
}

variable "cool_down_period" {
  type = number
  default = 90
}

variable "health_src_range" {
  type = string
  default = "0.0.0.0/0"
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
  private_ip_google_access = false
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
  description = "creates firewall rule targetting tagged instances to deny all ssh traffic"
  deny {
    protocol = "all"
  }
  priority      = 1000
  target_tags   = ["http-webapp"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_sql_database_instance" "MYSQL" { 
  database_version = "MYSQL_8_0"
  deletion_protection = var.db_deletion_protection
  settings {
    availability_type = var.db_availability
    tier    = var.db_machine_type
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
  name = var.db_username
  instance = google_sql_database_instance.MYSQL.name
  password = random_password.password.result
}

resource "random_password" "password" {
  length           = 16
  special          = false
}

resource "google_service_account" "vm_service_account" {
  account_id   = var.vm_account_id
  project = var.project_id

  display_name = "VM Service Account"
  create_ignore_already_exists = false
}

resource "google_project_iam_binding" "service_account_logging_writer" {
  project = var.project_id
  role    = "roles/logging.admin"

  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_project_iam_binding" "service_account_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_project_iam_binding" "service_account_topic_publish" {
  project = var.project_id
  role    = "roles/pubsub.publisher"

  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_project_iam_binding" "service_account_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"

  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_dns_record_set" "dns_record" {
  name = var.dns_name
  type = "A"
  managed_zone = var.dns_managed_zone
  rrdatas = [google_compute_global_address.webapp_address.address]
}

resource "google_pubsub_schema" "email_schema" {
  name = "email_schema"
  type = "AVRO"
  definition = "{\"type\":\"record\",\"name\":\"emailverify\",\"fields\":[{\"name\":\"username\",\"type\":\"string\"}]}"
}

resource "google_pubsub_topic" "verify_email" {
  name = var.pubsub_email_topic_name
  schema_settings {
    schema = "projects/${var.project_id}/schemas/email_schema"
    encoding = "JSON"
  }
  message_retention_duration = "604800s"
}

resource "google_cloudfunctions_function" "verify_email_fn" {
  name        = "verify-email-fn"
  description = "My function"
  runtime     = "java17"

  available_memory_mb   = 512
  source_archive_bucket = var.storage_bucket_name
  source_archive_object = var.fn_object_path
  entry_point           = "com.myjava.functions.SendVerifyMail"
  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource = google_pubsub_topic.verify_email.id
  }
  vpc_connector = google_vpc_access_connector.vpc_access.id
  environment_variables = {
      MYSQL_APP_USER=google_sql_user.sqlUser.name
      MYSQL_APP_PASSWORD=google_sql_user.sqlUser.password
      MYSQL_APP_HOST="jdbc:mysql://${google_sql_database_instance.MYSQL.private_ip_address}:3306/${google_sql_database.webappDb.name}?createDatabaseIfNotExist=true"
      DNS_NAME="${google_dns_record_set.dns_record.name}"
    }
}

# csye6225dev-414621@appspot.gserviceaccount.com
resource "google_vpc_access_connector" "vpc_access" {
  name = "sql-vpc-connector"
  network = google_compute_network.vpc6225.id
  ip_cidr_range = "10.8.0.0/28"
}
resource "google_project_iam_binding" "fn_service_account_mysql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"

  members = [
    "serviceAccount:${var.project_id}@appspot.gserviceaccount.com",
  ]
}


resource "google_compute_region_instance_template" "webapp_vm" {
  disk {
    auto_delete = true
    device_name = var.compute_intstance_name
    disk_size_gb = var.boot_disk_size
    disk_type  = "pd-balanced"
    source_image = "projects/${var.project_id}/global/images/${var.image_name}"
    mode = "READ_WRITE"
  }
  
  metadata = {
    startup-script = <<-EOF
    #!/bin/bash
    echo "MYSQL_APP_USER=${google_sql_user.sqlUser.name}" >> /etc/environment
    echo "MYSQL_APP_PASSWORD=${google_sql_user.sqlUser.password}" >> /etc/environment
    echo "MYSQL_APP_HOST=jdbc:mysql://${google_sql_database_instance.MYSQL.private_ip_address}:3306/${google_sql_database.webappDb.name}?createDatabaseIfNotExist=true" >> /etc/environment   
    echo "GOOGLE_PROJECT_ID=${var.project_id}" >> /etc/environment
    echo "GOOGLE_TOPIC_ID=${google_pubsub_topic.verify_email.id}" >> /etc/environment
    gcloud auth application-default login --impersonate-service-account ${google_service_account.vm_service_account.email}
    . /etc/environment
  EOF
  }
  can_ip_forward      = false

  labels = {
    goog-ec-src = "vm_add-tf"
  }

  machine_type = var.vm_machine_type
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
    email  = "${google_service_account.vm_service_account.email}"
    scopes = ["https://www.googleapis.com/auth/devstorage.read_only", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append", "https://www.googleapis.com/auth/pubsub", "https://www.googleapis.com/auth/cloud-platform"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  tags = ["http-webapp", "allow-health-check"]

  depends_on = [ google_compute_subnetwork.webapp, google_sql_database_instance.MYSQL ]
}

resource "google_compute_health_check" "webapp_http_health_check" {
  name        = "webapp-http-health-check"
  description = "Health check via http"

  timeout_sec         = 5
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  http_health_check {
    port_name = "webapp-http"
    port = "8030"
    request_path = "/healthz"
  }
}

resource "google_compute_region_instance_group_manager" "webapp_server" {
  name = "webapp-vm-group"
  base_instance_name = "webapp"
  region = var.provider_region
  version {
    name = "webapp-instance"
    instance_template = google_compute_region_instance_template.webapp_vm.self_link
  }
  auto_healing_policies {
    health_check = google_compute_health_check.webapp_http_health_check.id
    initial_delay_sec = 300
  }
  named_port {
    name = "webapp-port"
    port = 8030
  }
}

resource "google_compute_region_autoscaler" "webapp_auto_scaler" {
  name = "webapp-autoscaler"
  target = google_compute_region_instance_group_manager.webapp_server.id
  autoscaling_policy {
    max_replicas = var.max
    min_replicas = var.min
    cooldown_period = var.cool_down_period
    cpu_utilization {
      target = var.cpu_util
    }
  }
}

resource "google_compute_backend_service" "webapp_backend" {
  name                    = "webapp-backend-service"
  protocol                = "HTTP"
  port_name               = "webapp-port"
  load_balancing_scheme   = "EXTERNAL"
  timeout_sec             = 10
  health_checks           = [google_compute_health_check.webapp_http_health_check.id]
  backend {
    group           = google_compute_region_instance_group_manager.webapp_server.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }
}

resource "google_compute_global_address" "webapp_address" {
  name     = "webapp-static-ip"
}

resource "google_compute_url_map" "webapp_url_map" {
  name            = "webapp-url-map"
  default_service = google_compute_backend_service.webapp_backend.id
}

# http proxy
resource "google_compute_target_https_proxy" "webapp_proxy" {
  name     = "webapp-target-https-proxy"
  url_map  = google_compute_url_map.webapp_url_map.id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.webapp_cert_map.id}"
}

resource "google_certificate_manager_certificate_map" "webapp_cert_map" {
  name        = "cert-map"
  description = "webapp certificate map"
  labels      = {
    "terraform" : true,
    "acc-test"  : true,
  }
}

resource "google_certificate_manager_certificate_map_entry" "webapp_cert_map_entry" {
  name        = "webapp-cert-entry"
  description = "example certificate map entry"
  map         = google_certificate_manager_certificate_map.webapp_cert_map.name
  labels = {
    "terraform" : true
  }
  certificates = [google_certificate_manager_certificate.webapp_v1_cert.id]
  hostname     = "sanumula6225.me"
}

resource "google_compute_global_forwarding_rule" "webapp_fwd_rule" {
  name                  = "webapp-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.webapp_proxy.id
  ip_address            = google_compute_global_address.webapp_address.address
}

resource "google_compute_firewall" "health_check" {
  name          = "webapp-allow-hc"
  direction     = "INGRESS"
  network       = google_compute_network.vpc6225.id
  allow {
    protocol = "tcp"
    ports = ["8030"]
  }
  source_ranges=[var.health_src_range]
  priority = 998
  target_tags = ["allow-health-check"]
}

resource "google_certificate_manager_dns_authorization" "default" {
  name        = "new-dnsauth-a08"
  description = "The default dns auth"
  domain      = "sanumula6225.me"
  labels = {
    "terraform" : true
  }
}

resource "google_dns_record_set" "cname" {
  name         = google_certificate_manager_dns_authorization.default.dns_resource_record[0].name
  managed_zone = "webapp-public-zone"
  type         = google_certificate_manager_dns_authorization.default.dns_resource_record[0].type
  ttl          = 300
  rrdatas      = [google_certificate_manager_dns_authorization.default.dns_resource_record[0].data]
}

resource "google_certificate_manager_certificate" "webapp_v1_cert" {
  name        = "webapp-v1-cert"
  description = "The wildcard cert"
  managed {
    domains = ["sanumula6225.me"]
    dns_authorizations = [
      google_certificate_manager_dns_authorization.default.id
    ]
  }
  labels = {
    "terraform" : true
  }
}

