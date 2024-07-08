variable "gcp_region" {
  description = "Google Cloud region"
}
# variable "gcp_zone" {
#   description = "Google Cloud region"
#   validation {
#     # Validating that zone is within the region
#     condition     = var.gcp_zone == regex("[a-z]+-[a-z]+[0-1]-[abc]",var.gcp_zone)
#     error_message = "The GCP zone ${var.gcp_zone} needs to be a valid one."
#   }

# }
variable "gcp_project" {
  description = "Cloud project"
}
variable "gcp_sa" {
  description = "GCP Service Account to use for scopes"
}
variable "gcp_instance" {
  description = "Machine type for nodes"
}
# variable "gcp_zones" {
#   description = "availability zones"
#   type = list(string)
# }
variable "numnodes" {
  description = "number of server nodes"
  default = 6
}
variable "numclients" {
  description = "number of client nodes"
  default = 2
}
variable "cluster_name" {
  description = "Name of the cluster"
}
variable "owner" {
  description = "Owner of the cluster"
}
variable "server" {
  description = "Prefix for server names"
  default = "consul-server"
}
variable "consul_license" {
  description = "Consul Enterprise license text"
}


variable "consul_bootstrap_token" {
  description = "Bootstrap token for Consul"
  default = "ConsulR0cks!"
}

variable "consul_fqdn" {
  description = "Value for the Consul FQDN if set externally"
  default = ""
}

variable "image_family" {
  default = "hashistack"
}

variable "dns_zone" {
  default = "doormat-useremail"
}

variable "create_dns" {
  default = false
}

variable "use_hcp_packer" {
  description = "Use HCP Packer to store images"
  default = false
}

variable "hcp_packer_bucket" {
  description = "Bucket name for HCP Packer"
  default = "consul"  
}

variable "hcp_packer_channel" {
  description = "Channel for HCP Packer"
  default = "latest"
}

variable "hcp_packer_region" {
  description = "Region for HCP Packer"
  default = "europe-west1-c"
}

# Variables to be used for TLS certificates
variable "create_certs" {
  description = "Create certificates for Consul"
  default = false
}

variable "algorithm" {
  description = "Private key algorithm"
  default = "RSA"
}
variable "ecdsa_curve" {
    description = "Elliptive curve to use for ECDS algorithm"
    default = "P521"
}
variable "rsa_bits" {
  description = "Size of RSA algorithm. 2048 by default."
  default = 2048
}

variable "ca_common_name" {
  default = "consul-ca.local"
}
variable "ca_organization" {
  default = "Hashi Consul"
}
variable "common_name" {
  default = "consul.local"
}

variable "validity_period_hours" {
  default = 8760
}
