terraform {
  required_version = ">= 1.0"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# SSH Key for accessing the servers
resource "hcloud_ssh_key" "k3s" {
  name       = "${var.cluster_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# Network for the cluster
resource "hcloud_network" "k3s" {
  name     = "${var.cluster_name}-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "k3s" {
  network_id   = hcloud_network.k3s.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"

  lifecycle {
    create_before_destroy = false
  }
}

# Firewall rules for K3s nodes
resource "hcloud_firewall" "k3s" {
  name = "${var.cluster_name}-firewall"

  # SSH access (temporary for installation)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Internal cluster communication
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  rule {
    direction = "in"
    protocol  = "udp"
    port      = "any"
    source_ips = [
      "10.0.0.0/16"
    ]
  }

  # HTTP traffic for ingress
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # HTTPS traffic for ingress
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Kubernetes API Server (only from internal network and bastion)
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      "10.0.0.0/16"
    ]
  }
}

# K3s Master Node (Server)
resource "hcloud_server" "k3s_master" {
  name        = "${var.cluster_name}-master"
  server_type = var.server_type
  image       = var.server_image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.k3s.id]
  firewall_ids = [hcloud_firewall.k3s.id]

  network {
    network_id = hcloud_network.k3s.id
    ip         = "10.0.1.2"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = {
    role = "master"
    cluster = var.cluster_name
  }

  depends_on = [
    hcloud_network_subnet.k3s
  ]
}

# K3s Worker Nodes
resource "hcloud_server" "k3s_worker" {
  count       = var.worker_count
  name        = "${var.cluster_name}-worker-${count.index + 1}"
  server_type = var.server_type
  image       = var.server_image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.k3s.id]
  firewall_ids = [hcloud_firewall.k3s.id]

  network {
    network_id = hcloud_network.k3s.id
    ip         = "10.0.1.${count.index + 3}"
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = {
    role = "worker"
    cluster = var.cluster_name
  }

  depends_on = [
    hcloud_network_subnet.k3s,
    hcloud_server.k3s_master
  ]
}

# Generate random token for K3s cluster
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/ansible/inventory/hosts.tpl", {
    master_private_ip    = one([for net in hcloud_server.k3s_master.network : net.ip])
    master_public_ip     = hcloud_server.k3s_master.ipv4_address
    worker_private_ips   = [for worker in hcloud_server.k3s_worker : one([for net in worker.network : net.ip])]
    worker_public_ips    = [for worker in hcloud_server.k3s_worker : worker.ipv4_address]
    k3s_version          = var.k3s_version
    k3s_token            = random_password.k3s_token.result
    cluster_name         = var.cluster_name
    ssh_private_key_path = var.ssh_private_key_path
    hcloud_token         = var.hcloud_token
    hcloud_csi_version   = var.hcloud_csi_version
    hcloud_ccm_version   = var.hcloud_ccm_version
    network_id           = hcloud_network.k3s.id
    location             = var.location
    letsencrypt_email    = var.letsencrypt_email
    tailscale_auth_key   = var.tailscale_auth_key
    tailscale_tags       = var.tailscale_tags
    onepassword_credentials_json = var.onepassword_credentials_json
    processcube_api_key          = var.processcube_api_key
    cuby_domain                  = var.cuby_domain
  })
  filename = "${path.module}/ansible/inventory/hosts"

  depends_on = [
    hcloud_server.k3s_master,
    hcloud_server.k3s_worker
  ]
}

# Wait for servers to be ready
resource "null_resource" "wait_for_servers" {
  provisioner "local-exec" {
    command = "sleep 90"
  }

  depends_on = [
    local_file.ansible_inventory
  ]
}

# Run Ansible playbook
resource "null_resource" "ansible_provisioning" {
  provisioner "local-exec" {
    command = "cd ${path.module}/ansible && ansible-playbook -i inventory/hosts site.yml"
  }

  depends_on = [
    null_resource.wait_for_servers
  ]

  triggers = {
    master_id  = hcloud_server.k3s_master.id
    worker_ids = join(",", hcloud_server.k3s_worker[*].id)
    inventory  = local_file.ansible_inventory.content
  }
}

# Cleanup script for LoadBalancers before destroying network
# Uses Terraform's external data source to list and delete LoadBalancers via API
resource "null_resource" "cleanup_loadbalancers" {
  triggers = {
    network_id   = hcloud_network.k3s.id
    hcloud_token = var.hcloud_token
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      #!/bin/bash
      set -e

      echo "Checking for LoadBalancers attached to network ${self.triggers.network_id}..."

      # Use curl to query Hetzner API
      LBS=$(curl -s -H "Authorization: Bearer ${self.triggers.hcloud_token}" \
        "https://api.hetzner.cloud/v1/load_balancers" | \
        jq -r --arg net_id "${self.triggers.network_id}" \
        '.load_balancers[] | select(.private_net[]?.network == ($net_id | tonumber)) | .id')

      if [ -z "$LBS" ]; then
        echo "No LoadBalancers found attached to network."
        exit 0
      fi

      for lb_id in $LBS; do
        echo "Deleting LoadBalancer $lb_id..."
        curl -s -X DELETE -H "Authorization: Bearer ${self.triggers.hcloud_token}" \
          "https://api.hetzner.cloud/v1/load_balancers/$lb_id" || true
      done

      echo "Waiting for LoadBalancers to be fully deleted..."
      sleep 15
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [
    null_resource.ansible_provisioning,
    hcloud_network.k3s
  ]
}
