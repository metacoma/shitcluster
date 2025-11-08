[package]
name = "shitcluster"
edition = "v0.11.1"
version = "0.0.1"

[dependencies]
argoproj = { oci = "oci://ghcr.io/kcl-lang/argoproj", tag = "3.0.12" }
k8s = { oci = "oci://ghcr.io/kcl-lang/k8s", tag = "1.32.4", version = "1.32.4" }
