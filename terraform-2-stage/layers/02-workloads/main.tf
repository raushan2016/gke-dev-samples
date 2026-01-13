resource "kubernetes_namespace" "example" {
  metadata {
    name = "migration-demo"
  }
}

# Example of using kubernetes_manifest (Server-Side Apply)
resource "kubernetes_manifest" "example_configmap" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "example-config"
      namespace = kubernetes_namespace.example.metadata[0].name
    }
    data = {
      "message" = "Hello from the official hashicorp/kubernetes provider!"
      "verdict" = "Chicken and egg problem solved via layering."
    }
  }
}
