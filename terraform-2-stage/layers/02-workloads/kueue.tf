resource "null_resource" "kueue_installation" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${data.terraform_remote_state.infra.outputs.cluster_name} --region ${data.terraform_remote_state.infra.outputs.location} --project ${var.project_id}
      kubectl apply --server-side -f https://github.com/kubernetes-sigs/kueue/releases/download/v0.15.2/manifests.yaml
    EOT
  }
}

resource "null_resource" "kueue_config" {
  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [null_resource.kueue_installation]

  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${data.terraform_remote_state.infra.outputs.cluster_name} --region ${data.terraform_remote_state.infra.outputs.location} --project ${var.project_id}
      # Wait for webhook service to be ready (naive wait)
      sleep 10
      kubectl apply -f ${path.module}/kueue_config.yaml
    EOT
  }
}
