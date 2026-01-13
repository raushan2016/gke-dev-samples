resource "kubernetes_namespace" "example" {
  metadata {
    name = "migration-demo"
  }
}



resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.example.metadata[0].name
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:1.21.6"
          name  = "nginx"

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

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}

resource "kubernetes_job" "hello_job" {
  metadata {
    name      = "hello-job"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  spec {
    template {
      metadata {}
      spec {
        container {
          name    = "hello"
          image   = "busybox"
          command = ["/bin/sh", "-c", "echo 'Hello from Stage 2' && sleep 5000"]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 4
  }
}
