#!/bin/bash

set -e

echo "========================================="
echo "=== Setting up Nomad and Dependencies ==="
echo "========================================="

sudo apt-get -yqq update
sudo apt-get -yqq install apt-transport-https ca-certificates curl gnupg-agent software-properties-common unzip jq

echo "=== Finished Installing Apt Deps ==="

echo "=== Sleeping ==="
// TODO: Figure out why this is necessary
sleep 30
echo "=== Finished Sleeping ==="

if [ ${use_docker} == true ] || [ ${use_docker} == 1 ]; then
  echo "=============="
  echo "=== Docker ==="
  echo "=============="
  ${docker_config}
fi

echo "============="
echo "=== Nomad ==="
echo "============="
${nomad_config}

sudo systemctl daemon-reload

echo "=== Starting Nomad ==="
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
