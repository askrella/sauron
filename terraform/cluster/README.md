# Cluster Module

Since Terraform does not support dynamic providers, we need a clever workaround.
We do this by invoking a new terraform apply for each server with all
required variables from the previous steps.
