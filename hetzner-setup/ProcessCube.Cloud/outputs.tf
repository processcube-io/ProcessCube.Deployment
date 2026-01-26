output "master_public_ip" {
  description = "Public IP address of the master node"
  value       = hcloud_server.k3s_master.ipv4_address
}

output "master_private_ip" {
  description = "Private IP address of the master node"
  value       = one([for net in hcloud_server.k3s_master.network : net.ip])
}

output "worker_public_ips" {
  description = "Public IP addresses of worker nodes"
  value       = [for worker in hcloud_server.k3s_worker : worker.ipv4_address]
}

output "worker_private_ips" {
  description = "Private IP addresses of worker nodes"
  value       = [for worker in hcloud_server.k3s_worker : one([for net in worker.network : net.ip])]
}

output "k3s_token" {
  description = "K3s cluster token (sensitive)"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig from master node"
  value       = "ssh root@${hcloud_server.k3s_master.ipv4_address} 'cat /etc/rancher/k3s/k3s.yaml' > kubeconfig.yaml"
}

output "network_id" {
  description = "ID of the private network"
  value       = hcloud_network.k3s.id
}

output "network_name" {
  description = "Name of the private network"
  value       = hcloud_network.k3s.name
}

output "load_balancer_info" {
  description = "Information about LoadBalancer provisioning"
  value       = "LoadBalancer will be created automatically by Hetzner Cloud Controller Manager when Nginx Ingress Controller is deployed. Check with: kubectl get svc -n ingress-nginx ingress-nginx-controller"
}

output "ssh_commands" {
  description = "SSH commands to access nodes"
  value = {
    master  = "ssh root@${hcloud_server.k3s_master.ipv4_address}"
    workers = [for worker in hcloud_server.k3s_worker : "ssh root@${worker.ipv4_address}"]
  }
}

output "cuby_url" {
  description = "URL to access Cuby operator"
  value       = fileexists("${path.module}/cuby_domain.txt") ? "https://${trimspace(file("${path.module}/cuby_domain.txt"))}" : "Run 'terraform apply' to deploy the cluster first"
}
