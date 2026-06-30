# ProcessCube K3s Cluster on Hetzner Cloud

Terraform + Ansible configuration for deploying a production-ready K3s Kubernetes cluster on Hetzner Cloud.

## Architecture

- **1 Master Node**: K3s server with control plane
- **2 Worker Nodes**: K3s agents for workload execution (scalable)
- **Hetzner Cloud Controller Manager**: Native cloud integration for LoadBalancers and persistent volumes
- **Hetzner CSI Driver**: Dynamic volume provisioning
- **Nginx Ingress Controller**: DaemonSet configuration for high availability
- **cert-manager**: Automatic TLS certificate management with Let's Encrypt
- **Tailscale**: Secure mesh VPN for remote access to cluster nodes
- **Private Network**: Internal 10.0.0.0/16 network for cluster communication
- **Firewall**: Configured security rules for SSH, K8s API, HTTP/HTTPS

## Prerequisites

1. **Hetzner Cloud Account**: Sign up at https://www.hetzner.com/cloud
2. **Hetzner API Token**: Create one in the Hetzner Cloud Console under "Security" → "API Tokens"
3. **Terraform**: Install from https://www.terraform.io/downloads
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```
4. **Ansible**: Install from https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
   ```bash
   # macOS
   brew install ansible

   # Linux (Ubuntu/Debian)
   sudo apt update
   sudo apt install ansible

   # Python pip (all platforms)
   pip3 install ansible
   # or use the requirements file:
   cd ansible && pip3 install -r requirements.txt
   ```
5. **SSH Key**: Generate if you don't have one:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
   ```
6. **Tailscale Account** (optional): Sign up at https://tailscale.com for secure remote access

## Configuration

### 1. Create terraform.tfvars

Create a `terraform.tfvars` file in this directory:

```hcl
# Hetzner Cloud Configuration
hcloud_token = "YOUR_HETZNER_API_TOKEN"

# Cluster Configuration
cluster_name = "processcube-k3s"
location     = "fsn1"  # Options: nbg1, fsn1, hel1
server_type  = "cx43"  # Options: cx11, cx21, cx31, cx41, cx51
worker_count = 2

# K3s Version
k3s_version = "v1.34.2+k3s1"

# Hetzner Cloud Integrations
hcloud_csi_version = "v2.18.1"  # CSI Driver for persistent volumes
hcloud_ccm_version = "v1.20.0"  # Cloud Controller Manager

# SSH Key Paths
ssh_public_key_path  = "~/.ssh/id_rsa.pub"
ssh_private_key_path = "~/.ssh/id_rsa"

# Let's Encrypt (for automatic HTTPS certificates)
letsencrypt_email = "your-email@example.com"

# Tailscale (optional - for secure remote access)
tailscale_auth_key = "YOUR_TAILSCALE_AUTH_KEY"  # See "Tailscale Setup" below
# tailscale_tags   = "tag:k3s"  # Optional: Uncomment to use tags
```

### 2. Tailscale Setup (Optional but Recommended)

Tailscale provides secure remote access to your cluster nodes without exposing them to the public internet.

**Create an Auth Key:**

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click **Generate auth key**
3. Configure the key:
   - **Description**: `ProcessCube K3s Cluster`
   - **Reusable**: ✅ Enable (allows multiple devices to use the same key)
   - **Ephemeral**: ❌ Disable (nodes should persist in your network)
   - **Pre-approved**: ✅ Enable (automatically approve devices)
   - **Tags**: Add `tag:k3s` if you want to use ACL rules for this cluster
4. Click **Generate key**
5. Copy the key (starts with `tskey-auth-...`)
6. Add to your `terraform.tfvars`:
   ```hcl
   tailscale_auth_key = "tskey-auth-kXXXXXXXXXXXXXXXXXXXXXXXXX"
   ```

**Benefits:**
- Secure SSH access from anywhere without VPN configuration
- Access cluster services via Tailscale IPs
- No need to expose SSH on public IPs
- Automatic encryption and authentication

**Skip Tailscale:** If you don't want to use Tailscale, you can skip this step and access nodes via their public IPs.

### 3. Server Types

Choose your server type based on workload requirements:

| Type | vCPUs | RAM | Price/month* |
|------|-------|-----|--------------|
| cx11 | 1 | 2GB | ~€4.15 |
| cx21 | 2 | 4GB | ~€6.40 |
| cx31 | 2 | 8GB | ~€12.40 |
| cx41 | 4 | 16GB | ~€23.40 |
| cx51 | 8 | 32GB | ~€44.40 |

*Prices are approximate. Check current pricing at https://www.hetzner.com/cloud

### 4. Locations

- `nbg1` - Nuremberg, Germany
- `fsn1` - Falkenstein, Germany
- `hel1` - Helsinki, Finland

## Deployment

The deployment process uses Terraform to provision infrastructure and Ansible to configure K3s.

### Initialize Terraform

```bash
cd infrastructure/ProcessCube.Cloud
terraform init
```

### Plan Deployment

```bash
terraform plan
```

### Deploy Cluster

```bash
terraform apply
```

Type `yes` when prompted to confirm.

**What happens during deployment:**
1. Terraform creates Hetzner Cloud resources (servers, network, firewall)
2. Terraform generates Ansible inventory with all configuration
3. Ansible installs Tailscale on all nodes (if configured)
4. Ansible installs and configures K3s master node
5. Ansible installs Hetzner Cloud Controller Manager (CCM)
6. Ansible joins worker nodes to the cluster
7. Ansible installs cluster addons:
   - Hetzner CSI Driver (for persistent volumes)
   - Nginx Ingress Controller (DaemonSet on all nodes)
   - cert-manager (for automatic TLS certificates)
   - Hetzner LoadBalancer (automatically created by CCM)
8. Ansible verifies all nodes are ready

Deployment takes approximately 10-15 minutes.

## Manual Ansible Execution

If you need to re-run Ansible without recreating infrastructure:

```bash
cd ansible
ansible-playbook -i inventory/hosts site.yml
```

Check connectivity first:
```bash
ansible all -i inventory/hosts -m ping
```

## Access the Cluster

### Get Cluster Information

```bash
terraform output
```

### Download kubeconfig

```bash
terraform output -raw kubeconfig_command | bash
```

Or manually:

```bash
ssh root@$(terraform output -raw master_ip) 'cat /etc/rancher/k3s/k3s.yaml' | \
  sed "s/127.0.0.1/$(terraform output -raw master_ip)/g" > kubeconfig.yaml
```

### Use kubectl

```bash
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
kubectl get pods -A
```

Expected output:
```
NAME                     STATUS   ROLES                  AGE   VERSION
processcube-k3s-master   Ready    control-plane,master   5m    v1.28.5+k3s1
processcube-k3s-worker-1 Ready    <none>                 4m    v1.28.5+k3s1
processcube-k3s-worker-2 Ready    <none>                 4m    v1.28.5+k3s1
```

### SSH to Nodes

```bash
# Master node
ssh root@$(terraform output -raw master_ip)

# Worker nodes
ssh root@<worker-ip>
```

## Cluster Features

### What's Included

- ✅ **K3s v1.34.2+k3s1** - Lightweight Kubernetes distribution
- ✅ **Hetzner Cloud Controller Manager** - Native cloud integration
- ✅ **Hetzner CSI Driver** - Dynamic persistent volume provisioning
- ✅ **Nginx Ingress Controller** - DaemonSet configuration for HA
- ✅ **cert-manager** - Automatic TLS certificates with Let's Encrypt
- ✅ **Hetzner LoadBalancer** - Automatically provisioned for Ingress
- ✅ **Tailscale VPN** - Secure mesh networking (optional)
- ✅ **Private networking** - 10.0.0.0/16 internal network
- ✅ **Firewall configuration** - UFW rules on all nodes
- ✅ **Helm 3** - Installed on master node
- ✅ **Idempotent Ansible playbooks** - Safe to re-run

### What's Disabled

- ❌ **Traefik ingress controller** - Using Nginx instead
- ❌ **ServiceLB** - Using Hetzner LoadBalancer via CCM
- ❌ **K3s cloud provider** - Using external cloud-provider via CCM

## Ansible Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── site.yml                 # Main playbook orchestration
├── requirements.txt         # Python dependencies
├── inventory/
│   ├── hosts.tpl           # Terraform template for inventory
│   └── hosts               # Generated inventory (by Terraform)
└── roles/
    ├── tailscale/          # Tailscale VPN installation
    │   └── tasks/main.yml
    ├── k3s_master/         # K3s master node setup
    │   └── tasks/main.yml
    ├── k3s_ccm/            # Hetzner Cloud Controller Manager
    │   └── tasks/main.yml
    ├── k3s_worker/         # K3s worker node setup
    │   └── tasks/main.yml
    └── k3s_addons/         # Cluster addons (CSI, Ingress, cert-manager)
        └── tasks/main.yml
```

## Customizing Ansible Playbooks

### Modify K3s Installation

Edit [ansible/roles/k3s_master/tasks/main.yml](ansible/roles/k3s_master/tasks/main.yml) or [ansible/roles/k3s_worker/tasks/main.yml](ansible/roles/k3s_worker/tasks/main.yml)

### Add Additional Software

Create new Ansible roles:

```bash
cd ansible/roles
ansible-galaxy init my_custom_role
```

Then add it to `site.yml`:

```yaml
- name: Install custom software
  hosts: all
  roles:
    - my_custom_role
```

## Working with the Cluster

### Using Tailscale for Remote Access

If you configured Tailscale, your nodes are accessible via their Tailscale IPs:

```bash
# View Tailscale machines
tailscale status

# SSH via Tailscale
ssh root@<tailscale-ip>

# You can also set up Tailscale on your local machine to access the cluster
```

### LoadBalancer and Ingress

The Hetzner LoadBalancer is automatically created and configured:

```bash
# Get LoadBalancer IP
kubectl get svc ingress-nginx-controller -n ingress-nginx

# The LoadBalancer distributes traffic to all nodes (port 80/443)
```

### Deploy Your Applications with Ingress

Example Ingress with automatic TLS:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - myapp.example.com
    secretName: myapp-tls
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app
            port:
              number: 80
```

Apply it:
```bash
kubectl apply -f my-app-ingress.yaml
```

cert-manager will automatically request and configure TLS certificates from Let's Encrypt.

## Monitoring

### View Cluster Status

```bash
kubectl get nodes
kubectl top nodes
kubectl get pods -A
```

### Check K3s Service

```bash
# On master
ssh root@$(terraform output -raw master_ip)
systemctl status k3s
journalctl -u k3s -f

# On workers
ssh root@<worker-ip>
systemctl status k3s-agent
journalctl -u k3s-agent -f
```

### Ansible Logs

Check Ansible output during `terraform apply` for any errors.

## Cost Estimation

**Monthly costs** (approximate):
- 1x Master (cx21): €6.40
- 2x Workers (cx21): €12.80
- 1x Load Balancer (lb11): €5.39
- **Total: ~€24.59/month**

Additional costs:
- Traffic: 20TB included (€1.19/TB after)
- Volumes: €0.0476/GB/month (if used)

## Scaling

### Add More Workers

Edit `terraform.tfvars`:

```hcl
worker_count = 3  # or more
```

Then apply:

```bash
terraform apply
```

Terraform will:
1. Create new worker servers
2. Update Ansible inventory
3. Run Ansible to join new workers to cluster

### Upgrade Server Type

Edit `terraform.tfvars`:

```hcl
server_type = "cx31"  # upgrade from cx21
```

Note: This will recreate the servers. Backup your data first!

## Backup & Disaster Recovery

### Backup etcd

```bash
ssh root@$(terraform output -raw master_ip)
k3s etcd-snapshot save
```

Snapshots are stored in `/var/lib/rancher/k3s/server/db/snapshots/`

### Download Backups

```bash
scp root@$(terraform output -raw master_ip):/var/lib/rancher/k3s/server/db/snapshots/* ./backups/
```

### Restore from Snapshot

```bash
k3s server \
  --cluster-reset \
  --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/snapshot-name
```

## Troubleshooting

### Terraform Issues

**Problem**: `Error: Error creating server`
- Check Hetzner API token is valid
- Verify server type is available in chosen location
- Check account limits in Hetzner Console

### Ansible Issues

**Problem**: Ansible cannot connect to servers
```bash
# Test SSH connectivity
ssh root@<server-ip>

# Check Ansible inventory
cat ansible/inventory/hosts

# Test with Ansible ping
cd ansible
ansible all -i inventory/hosts -m ping
```

**Problem**: K3s installation fails
```bash
# SSH to the server and check logs
ssh root@<server-ip>
journalctl -xeu k3s
# or for workers:
journalctl -xeu k3s-agent
```

### Nodes Not Joining

1. Check master node is running:
   ```bash
   ssh root@$(terraform output -raw master_ip) 'systemctl status k3s'
   ```

2. Check worker logs:
   ```bash
   ssh root@<worker-ip> 'journalctl -u k3s-agent -f'
   ```

3. Verify network connectivity:
   ```bash
   ssh root@<worker-ip> 'ping -c 3 10.0.1.2'
   ```

4. Re-run Ansible:
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts site.yml
   ```

### Get K3s Token

```bash
ssh root@$(terraform output -raw master_ip) 'cat /var/lib/rancher/k3s/server/node-token'
```

Or use terraform:

```bash
terraform output -raw k3s_token
```

### Firewall Issues

Check UFW status:

```bash
ssh root@$(terraform output -raw master_ip) 'ufw status'
```

## Cleanup

### Destroy Cluster

```bash
terraform destroy
```

Type `yes` to confirm.

This will delete:
- All servers
- Load balancer
- Network
- Firewall
- SSH keys
- Generated Ansible inventory

**Warning**: This action is irreversible. Backup any important data first!

### Clean Local Files

```bash
rm -f ansible/inventory/hosts
rm -f kubeconfig.yaml
```

## Security Considerations

1. **SSH Access**: Consider restricting SSH access to specific IPs in the firewall rules
2. **API Access**: The Kubernetes API is publicly accessible. Use RBAC and network policies.
3. **Secrets**: Never commit `terraform.tfvars` or `*.tfstate` files to git
4. **API Token**: Keep your Hetzner API token secure
5. **Updates**: Regularly update K3s version for security patches
6. **Ansible**: SSH private key is used by Ansible - ensure it's properly secured

## Advanced Configuration

### Custom K3s Flags

Edit the Ansible role to add custom flags:

```yaml
# In ansible/roles/k3s_master/tasks/main.yml
- name: Install K3s master
  shell: |
    INSTALL_K3S_VERSION="{{ k3s_version }}" /tmp/k3s_install.sh server \
      --cluster-init \
      --your-custom-flag \
      --another-flag=value
```

### Configure Node Labels

Add to Ansible playbook:

```yaml
- name: Label nodes
  shell: kubectl label node {{ inventory_hostname }} custom-label=value
```

## Support

- **Hetzner Cloud Docs**: https://docs.hetzner.com/cloud/
- **K3s Documentation**: https://docs.k3s.io/
- **Terraform Hetzner Provider**: https://registry.terraform.io/providers/hetznercloud/hcloud/
- **Ansible Documentation**: https://docs.ansible.com/

## License

This configuration is part of ProcessCube.UG project.
