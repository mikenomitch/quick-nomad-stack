echo "=== Setting up Consul Template ==="
sudo mkdir -p /mnt/consul-template
sudo mkdir -p /etc/consul-template.d

sudo tee /etc/consul-template.d/consul-template.hcl > /dev/null <<EOF
syslog {
  enabled = true
  facility = "LOCAL5"
}
EOF

sudo tee /etc/systemd/system/consul-template.service > /dev/null <<"EOF"
${consul_template_service_config}
EOF
