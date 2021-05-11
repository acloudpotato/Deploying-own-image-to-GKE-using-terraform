terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.52.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }
}

data "terraform_remote_state" "gke" {
  backend = "local"

  config = {
    path = "../Deploying-own-image-to-GKE-using-terraform/terraform.tfstate"
  }
}

# Retrieve GKE cluster information


# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {}

data "google_container_cluster" "my_cluster" {
  name     = data.terraform_remote_state.gke.outputs.kubernetes_cluster_name
  location = data.terraform_remote_state.gke.outputs.region
}

provider "kubernetes" {
  host = data.terraform_remote_state.gke.outputs.kubernetes_cluster_host

  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_deployment" "mydeployment" {
  metadata {
    name = "my-deployment"
    labels = {
      App = "myapp"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "myapp"
      }
    }
    template {
      metadata {
        labels = {
          App = "myapp"
        }
      }
      spec {
        container {
          image = "abhishek7389/trailapp:latest"
          name  = "myapp-helloworld"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mydeployment" {
  metadata {
    name = "my-lb"
  }
  spec {
    selector = {
      App = kubernetes_deployment.mydeployment.spec.0.template.0.metadata[0].labels.App
    }
    port {
      node_port   = 30201
      port        = 80
      target_port = 80
    }

    type = "NodePort"
  }
}
