# Quick Nomad Stack (AWS)

This is terraform code for setting up Nomad on AWS.

This sets up Nomad servers, a Nomad client autoscaling group, load balancers
for servers and client workloads, and subnets + security groups.

### Dependencies

- Terraform 12+
- AWS Account Key and Secret
