# Quick Nomad Stack (AWS)

This is Terraform configuration for setting up a simple Nomad cluster on AWS.

This sets up:
* Nomad server autoscaling group (between 1-5 nodes)
* Nomad client autoscaling group
* Nomad Server load balancer
* Nomad Client load balancer for an ingress proxy
* Nomad Client load balancer for an ingress proxy admin UI
* Related Subnets & Security groups

### Dependencies

- Terraform 12+
- An AWS Account Key and Secret
- An AWS KeyPair (default name "nomad-stack")

### After Terraform Apply

After applying the Terraform, the Nomad Servers and
Clients are configured to automatically find one another.

In order to connect to your Nomad cluster, you must first
create a Management ACL Token:
* Copy "nomad_server_url" from `terraform output`
* Set environment variable to connect to Nomad servers via CLI `export NOMAD_ADDR=<nomad_server_url>`
* Create a management token `nomad acl boostrap`
* `export NOMAD_TOKEN=<secret_token_from_response>`
* Input the token via the UI

You can now run jobs on your Nomad cluster!

### Default Values

* us-east-1 is the default region
* Client load balancers point to ports 80 and 8080 (Traefik defaults)
* All IPs are whitelisted ("0.0.0.0/0")
* Ubuntu 20.04 LTS AMD 64 is the base AMI used
* t2.small is used for the client and server nodes
* A KeyPair named "nomad-stack" is assumed to exist
* A single Nomad server and two Nomad clients are provisioned
* A public IP is exposed for to demonstrate ingress

### Tradeoffs & Decisions

This is meant to be a simple repository for getting Nomad spun up quickly.
As such, some decisions were made to keep things simple:
* TLS is not set up
* An upgrade strategy for new Nomad Server nodes isn't included in the TF
* Machine Images are not used and instead dependencies are installed on boot.
This was done to remove a tool like Packer from the dependency list, and to
make understanding setup easier.
