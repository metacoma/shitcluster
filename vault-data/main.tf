terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }
}

provider vault {
}

variable "vault_data_file" {
  description = "Path to the vault_data.yaml file"
  type        = string
  #  default     = "${path.module}/vault_data.yaml"
}

locals {
  vault_yaml = yamldecode(file(var.vault_data_file))
  vault_data = local.vault_yaml.vault_data
}

resource "vault_kv_secret_v2" "from_yaml" {

  # for_each over map: "some/path1" => { key1 = "...", key2 = "..." }
  for_each = local.vault_data

  mount = "kv"
  name  = each.key            # "some/path1", "some/path2/xxx", ...

  # each.value is the whole object for this path; can be nested maps/lists
  data_json = jsonencode(each.value)
}
