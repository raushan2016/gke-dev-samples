data "terraform_remote_state" "infra" {
  backend = "local"

  config = {
    path = "${path.module}/../01-infra/terraform.tfstate"
  }
}
