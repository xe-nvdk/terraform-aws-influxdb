# Terraform InfluxDB Module

Terraform module for deploying InfluxDB Enterprise 1.x family to AWS EC2.

This module creates and manages the following resources:

* Meta and Data node instances including associated EBS volumes.
* Security groups for cluster communications.
* Route53 Records for instances in a specified zone.
* Optional tagging of all resources for easy identification of resources. Useful with third-party configuration management tooling.

For the sake of deployment flexibility, this module intentionally leaves host level provisioning up to the user. For example, users may prefer to use Ansible, Puppet, or Chef to complete the installation procedure. A default AMI is not specified and must be provided by the user.

Optional tags can be specified, making this module easy to use with third-party configuration management systems as outlined in this [Ansible guide](http://docs.ansible.com/ansible/latest/intro_dynamic_inventory.html#example-aws-ec2-external-inventory-script).

Additionally, the module includes default initialization scripts (`init/data-nodes.sh` and `init/meta-nodes.sh`) to simplify the setup of data and meta nodes, including disk formatting, mounting, and basic InfluxDB installation. Users can customize these scripts or replace them with their own.

## Key Features

- Supports the latest AWS EC2 instance types, such as `r6i` for memory-intensive workloads.
- Automatically configures disks for data and meta nodes with `io2` volumes for higher durability.
- Adds support for dynamic tagging to enhance resource organization and visibility.
- Includes automated meta node cluster setup with customizable configurations.
- Provides Terraform outputs for easy integration with external tools like load balancers or monitoring systems.

## Usage Example

The following example demonstrates deploying a single Influx Enterprise cluster to production. This configuration will deploy 2 data nodes and 3 meta nodes, tagging all resources with an "Environment" tag set to _production_.

See the inputs documentation or variable definitions file for more configuration options.

```hcl
provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

module "influxdb" {
  source  = "influxdata/influxdb/aws"
  version = "1.0.7"

  data_instances    = 2
  data_disk_size    = 300
  data_disk_iops    = 4000
  meta_instances    = 3
  ami               = "ami-0f42acddbf04bd1b6"
  subnet_ids        = ["subnet-12345678", "subnet-87654321"] # Updated to support multiple subnets
  vpc_id            = "vpc-b535e44g"
  instance_type     = "r6i.2xlarge"  # Updated to use a newer instance type
  key_name          = "ignacio"
  zone_id           = "Z044144236NI0U6A5435435"
  security_group    = ["sg-0c8dc3456"]

  tags = {
    Environment = "production"
  }
}

## Outputs

This module provides the following outputs:
	•	meta_nodes_ids: A list of all meta node instance IDs.
	•	data_node_ids: A list of all data node instance IDs.
	•	data_node_count: The number of deployed data nodes, dynamically calculated.