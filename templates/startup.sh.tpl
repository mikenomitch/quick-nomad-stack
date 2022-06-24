#!/bin/bash

set -ex

// prevent waiting for human input
export DEBIAN_FRONTEND=noninteractive

echo "========================================="
echo "=== Setting up Nomad and Dependencies ==="
echo "========================================="

sudo apt-get -yqq update
sudo apt-get -yqq install apt-transport-https ca-certificates curl gnupg-agent software-properties-common unzip jq

echo "=== Finished Installing Apt Deps ==="

echo "=== Getting Docker ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get -yqq update
sudo apt-get -yqq install docker-ce

echo "=== Nomad ==="
${nomad_config}

sudo systemctl daemon-reload

echo "=== Starting Nomad ==="
sudo systemctl enable nomad.service
sudo systemctl start nomad.service
