PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl http://169.254.169.254/latest/meta-data/public-ipv4)

echo "=== Fetching Nomad ==="
cd /tmp
curl -sLo nomad.zip https://releases.hashicorp.com/nomad/${nomad_version}/nomad_${nomad_version}_linux_amd64.zip

echo "=== Installing Nomad ==="
unzip nomad.zip >/dev/null
sudo chmod +x nomad
sudo mv nomad /usr/local/bin/nomad

sudo mkdir -p /mnt/nomad
sudo mkdir -p /etc/nomad.d

if [ ${is_server} == true ] || [ ${is_server} == 1 ]; then
  echo "=== Setting up Nomad as Server ==="
  echo "=== Writing Server Config ==="

  sudo tee /etc/nomad.d/config.hcl > /dev/null <<EOF
datacenter = "${datacenter}"
region     = "${region}"
data_dir   = "/mnt/nomad"

bind_addr = "0.0.0.0"

server {
  enabled = true,
  bootstrap_expect = ${desired_servers}
  authoritative_region = "${authoritative_region}"

  server_join {
    retry_join = [ "provider=aws tag_key=${retry_tag_key} tag_value=${retry_tag_value}" ]
  }

  default_scheduler_config {
    memory_oversubscription_enabled = true

    preemption_config {
      batch_scheduler_enabled   = true
      system_scheduler_enabled  = true
      service_scheduler_enabled = true
    }
  }
}

acl {
  enabled = true
  replication_token = "${replication_token}"
}

advertise {
  http = "$PUBLIC_IP"
  rpc  = "$PUBLIC_IP"
  serf = "$PUBLIC_IP"
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

EOF
else
  echo "=== Setting up Nomad as Client ==="
  sudo mkdir -p /opt/nomad/plugins
  sudo mkdir -p /opt/cni/bin
  # sudo mkdir -p /tmp/cni
  # curl https://github.com/containernetworking/plugins/releases/download/v1.0.1/cni-plugins-linux-amd64-v1.0.1.tgz --output /tmp/cni/cni-plugins-linux-amd64-v1.0.1.tgz
  # tar -xf /tmp/cni/cni-plugins-linux-amd64-v1.0.1.tgz -C /tmp/cni
  # mv "/tmp/cni/*" "/opt/cni/bin"
  # tar -xf /tmp/cni-plugin

  echo "=== Writing Client Config ==="

  sudo tee /etc/nomad.d/config.hcl > /dev/null <<EOF
datacenter = "${datacenter}"
region     = "${region}"
data_dir   = "/mnt/nomad"
plugin_dir = "/opt/nomad/plugins"

bind_addr = "0.0.0.0"

client {
  enabled = true

  server_join {
    retry_join = [ "provider=aws tag_key=${retry_tag_key} tag_value=${retry_tag_value}" ]
  }
}

acl {
  enabled = true
}

plugin "raw_exec" {
  enabled = true
}

plugin "docker" {
  config {
    allow_privileged = true

    volumes {
      enabled = true
    }
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}

EOF

fi

sudo tee /etc/systemd/system/nomad.service > /dev/null <<"EOF"
${nomad_service_config}
EOF
