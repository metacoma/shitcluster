infra = {
  ns = "infra"
  sops = {
    secret = "sops"
    public_key = "ref+vault://kv/sops#public_key"
    age_key = "ref+vault://kv/sops#age_secret_key"
  }
}
