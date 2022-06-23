#!/bin/bash

set -e

echo "========================"
echo "=== Setting up Nomad ==="
echo "========================"

sudo apt-get -yqq update
sudo apt-get -yqq install apt-transport-https ca-certificates curl gnupg-agent software-properties-common unzip jq

PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

if [ ${use_docker} == true ] || [ ${use_docker} == 1 ]; then
  echo "=============="
  echo "=== Docker ==="
  echo "=============="
  ${docker_config}
fi

echo "======================="
echo "=== Consul Template ==="
echo "======================="
${consul_template_config}

echo "============="
echo "=== Nomad ==="
echo "============="
${nomad_config}

sudo systemctl daemon-reload

echo "=== Starting Consul Template ==="
sudo systemctl enable consul-template.service
sudo systemctl start consul-template.service

echo "=== Starting Nomad ==="
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
