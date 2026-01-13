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
    labels = {
      "kueue.x-k8s.io/queue-name" = "local-queue"
    }
  }

  spec {
    # Kueue requires the job to be suspended initially
    # support for 'suspend' field depends on provider version, ensuring it's present
    # If using older provider, this might need a 'wait_for_completion = false' or similar if suspend isn't supported directly, 
    # but 'suspend' is standard in BatchV1 Job spec.
    # The terraform kubernetes provider supports `suspend` in the schema.
    # checking schema... assuming it is supported.
    # It seems `suspend` is NOT a top level field in kubernetes_job spec in older providers, but `manual_selector` etc are.
    # Let's check if I can just add it. 'suspend' was added in K8s 1.21.
    # Provider version is >= 2.25, which should support it.
    # Actually, looking at docs, `suspend` is not always exposed in `spec` block of `kubernetes_job`. 
    # If it fails verification, I might need to use `kubernetes_manifest` for the job or `ignore_changes`. 
    # But let's try standard field.
    
    # Wait, `suspend` is not in the hashicorp/kubernetes provider `spec` block documentation commonly.
    # However, it IS in the K8s API. 
    # If the provider doesn't support it, I will have to rely on Kueue suspending it via webhook (which it does if queue-name is present).
    # Kueue docs say: "When you create a Job, the Kueue admission webhook inspects it... and suspends it".
    # So I might NOT need to set `suspend = true` explicitly if the webhook is working.
    # I will just add the label.
    
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
