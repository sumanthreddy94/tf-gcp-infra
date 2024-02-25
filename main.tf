terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.16.0"
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

resource "google_compute_subnetwork" "webapp" {
  name          = var.vpc_subnet_1
  ip_cidr_range = var.vpc_subnet_1_cidr
  network       = google_compute_network.vpc6225.name
  region        = var.vpc_subnet_1_region
}

resource "google_compute_subnetwork" "db" {
  name          = var.vpc_subnet_2
  ip_cidr_range = var.vpc_subnet_2_cidr
  network       = google_compute_network.vpc6225.name
  region        = var.vpc_subnet_2_region
}

resource "google_compute_route" "routewebapp" {
  name        = var.route_name
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.vpc6225.name
  next_hop_ip = google_compute_subnetwork.webapp.gateway_address
}