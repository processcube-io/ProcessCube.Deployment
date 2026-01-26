[k3s_master]
${master_public_ip} ansible_user=root ansible_ssh_private_key_file=${ssh_private_key_path}

[k3s_workers]
%{ for ip in worker_public_ips ~}
${ip} ansible_user=root ansible_ssh_private_key_file=${ssh_private_key_path}
%{ endfor ~}

[k3s_cluster:children]
k3s_master
k3s_workers

[k3s_cluster:vars]
k3s_version=${k3s_version}
k3s_token=${k3s_token}
master_ip=${master_private_ip}
cluster_name=${cluster_name}
hcloud_token=${hcloud_token}
hcloud_csi_version=${hcloud_csi_version}
hcloud_ccm_version=${hcloud_ccm_version}
network_id=${network_id}
location=${location}
letsencrypt_email=${letsencrypt_email}
%{ if tailscale_auth_key != "" ~}
tailscale_auth_key=${tailscale_auth_key}
tailscale_tags=${tailscale_tags}
%{ endif ~}
%{ if onepassword_credentials_json != "" ~}
onepassword_credentials_json=${onepassword_credentials_json}
%{ endif ~}
ansible_python_interpreter=/usr/bin/python3
