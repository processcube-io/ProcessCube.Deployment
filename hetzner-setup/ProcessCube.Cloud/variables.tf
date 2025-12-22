variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "processcube-k3s"
}

variable "location" {
  description = "Hetzner Cloud location"
  type        = string
  default     = "fsn1" 
  # Available: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki)
}

variable "server_type" {
  description = "Hetzner Cloud server type"
  type        = string
  default     = "cx11" # 2 vCPU, 4GB RAM
  # Options: cx11, cx21, cx31, cx41, cx51
  # cpx11, cpx21, cpx31, cpx41, cpx51 (AMD)
}

variable "server_image" {
  description = "Server image to use"
  type        = string
  default     = "ubuntu-22.04"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.28.5+k3s1"
}

variable "hcloud_csi_version" {
  description = "Hetzner Cloud CSI Driver version"
  type        = string
  default     = "v2.18.1"
}

variable "hcloud_ccm_version" {
  description = "Hetzner Cloud Controller Manager version"
  type        = string
  default     = "v1.20.0"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file for Ansible"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale authentication key (optional - Tailscale will only be installed if this is set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tailscale_tags" {
  description = "Tailscale tags to apply to nodes (optional)"
  type        = string
  default     = ""
}

variable "onepassword_credentials_json" {
  description = "Path to 1Password Connect credentials JSON file"
  type        = string
  sensitive   = true
}
