# Askrella Sauron 🚀 👁️
_Production ready monitoring cluster based on Grafana Stack, Hetzner and Cloudflare._

[![Pipeline Status](https://github.com/askrella/sauron/actions/workflows/main.yml/badge.svg)](https://github.com/askrella/sauron/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Production Ready](https://img.shields.io/badge/Production-Ready-brightgreen.svg)](https://github.com/askrella/sauron)
[![Latest Release](https://img.shields.io/github/v/release/askrella/sauron?include_prereleases)](https://github.com/askrella/sauron/releases)


Welcome to the Askrella Sauron project! 🌟 This project is designed to provision a fully functional, production ready cluster that includes essential monitoring and logging tools such as Grafana, Prometheus, Thanos, Loki, Tempo, Node-Exporter, and Promtail. The infrastructure is hosted on Hetzner Cloud, utilizing IPv6 for cost efficiency and enhanced performance.

## Table of Contents 📑
- [Overview 🎯](#overview-)
- [Infrastructure Diagram 🏗️](#infrastructure-diagram-)
- [Components 🧩](#components-)
- [Network and Security 🔒](#network-and-security-)
- [Prerequisites ✅](#prerequisites-)
- [Deployment 🚀](#deployment-)
- [Infrastructure Provisioning Steps 📋](#infrastructure-provisioning-steps-)
- [Example Pricing 💰](#example-pricing-)
- [FAQ ❓](#faq-)
- [TODO 📝](#todo-)
- [Contributing 🤝](#contributing-)
- [License ⚖️](#license-)
- [Maintainers 👥](#maintainers-)

## Overview 🎯

This project is part of the Askrella company and aims to provide a robust and scalable monitoring solution. The cluster may be deployed across multiple Hetzner regions, ensuring high availability and failover capabilities. The infrastructure leverages Hetzner's private subnet and firewall features, with routing managed by Caddy instances on each node. Load balancing and failover are handled by Cloudflare LoadBalancer, and IP addresses are published via Cloudflare DNS records.

## Infrastructure Diagram 🏗️

[![Infrastructure Diagram](./docs/sauron.drawio.svg)](./docs/sauron.drawio.svg)

## Components 🧩

- **[Grafana](https://grafana.com/docs/)** 📊: A powerful visualization and analytics tool.
- **[Prometheus](https://prometheus.io/docs/)** 📈: A monitoring system and time series database.
- **[Grafana Loki](https://grafana.com/docs/loki/latest/)** 📝: A log aggregation system.
- **[Grafana Tempo](https://grafana.com/docs/tempo/latest/)** ⚡: A distributed tracing backend.
- **[Node-Exporter](https://prometheus.io/docs/guides/node-exporter/)** 🖥️: An exporter for hardware and OS metrics.
- **[Promtail](https://grafana.com/docs/loki/latest/clients/promtail/)** 📡: A log collector that ships logs to Loki.
- **[Thanos](https://thanos.io/)** 💾: A highly available system for querying metrics across multiple nodes & clusters.
- **Hetzner Object Store** 💾: An S3-compatible object storage service used as a backend for storing database data.

### Default Dashboards 📊

The following dashboards are included by default in the Grafana setup:

- **cAdvisor Dashboard**: Provides insights into container resource usage and performance metrics.
- **Node Exporter Dashboard**: Displays hardware and OS metrics collected from the node.

These dashboards are pre-configured and can be accessed through the Grafana interface once the cluster is deployed.


## Network & Security 🔒

- **Private Subnet**: All servers are hosted in a private Hetzner subnet, enhancing security and reducing costs.
- **IPv6**: Utilized for cost efficiency and modern networking capabilities.
- **Firewall**: Configured to allow only necessary traffic, ensuring secure communication.
- **Caddy**: Deployed on each node for efficient routing and TLS termination.
- **Load Balancing**: Hetzner LoadBalancer provides load balancing and failover capabilities.
- **DNS**: IP addresses are published via Cloudflare DNS records for easy access.

# Prerequisites ✅

Before you begin deploying the Askrella Sauron cluster, ensure you have the following prerequisites in place:

## Access Requirements 🔑

- **Hetzner Account**: Create an account on Hetzner Cloud and obtain an API token for provisioning resources.
- **Cloudflare Account**: Set up a Cloudflare account to manage DNS records and load balancing.
- **Google OAuth Credentials**: Set up OAuth 2.0 credentials in Google Cloud Console for Grafana authentication.
- **SSH Key**: Generate an SSH key pair for secure access to the servers.
  ```bash
  # Generate SSH key
  ssh-keygen -t ed25519 -C "your_email@example.com"
  ```

## System Requirements 💻

- **Operating System**: A Unix-based system (Linux or macOS) is recommended for running the deployment scripts.
- **Hetzner API Token**: Create an API token on Hetzner Cloud.
- **Cloudflare API Token**: Create an API token on Cloudflare.
- **Google OAuth Client ID and Secret**: Create OAuth credentials for secure authentication.

## Software Requirements 🛠️

- **Git**
- **Terraform v1.10.3 or newer**

## Network Requirements 🌐

- **IPv6 Support**: Ensure your network supports IPv6, as the infrastructure leverages IPv6 for cost efficiency.
- **Firewall Configuration**: Allow necessary ports for SSH, HTTP, and HTTPS traffic.

Once you have all the prerequisites in place, you can proceed with the deployment steps outlined in the [Deployment](#deployment) section.

## Deployment 🚀

To deploy the cluster, follow these steps:

1. **Clone the Repository**: 
   ```bash
   git clone https://github.com/askrella/sauron.git
   cd sauron
   ```

2. **Configure Terraform Variables**: Update the `terraform.tfvars` file with your Hetzner API token and other necessary variables.

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Apply the Terraform Plan**:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

5. **Verify Deployment**: Ensure all services are running and accessible via the configured DNS records.

### Persistent Storage of Terraform State

Please keep in mind to persist the terraform state files contained in the `terraform/cluster` and `terraform` directories.

### How many nodes should I provision?

The number of nodes you should provision depends on your use case. We recommend to start with 3 nodes and scale up if you need more. When running on less than 3 nodes, the replication factor (e.g. Loki)will be set to the number of nodes, which is usually not recommended to reach a quorum.

## Infrastructure Provisioning Steps 📋

The infrastructure setup is a multi-step process that ensures a robust and secure environment for your applications. Below is a detailed breakdown of the steps involved:

1. **Provision Hetzner Infrastructure**
   
   **1.1 SSH Key**: Generate and configure SSH keys for secure access to the servers.
   
   **1.2 Private Network**: Set up a private network within Hetzner to ensure secure communication between nodes.
   
   **1.3 Firewall**: Configure firewall rules to allow only necessary traffic, enhancing security.
   
   **1.4 LoadBalancer**: Deploy a Hetzner LoadBalancer to distribute traffic evenly across the nodes and provide failover capabilities.
   
   **1.5 Servers**: Provision the required number of servers in the specified Hetzner regions.

   **1.6 Object Store**: Set up Hetzner Object Store as an S3-compatible backend for storing database data.

   **1.7 SSH Connection Check**: Verify SSH connectivity to each server to ensure they are accessible and ready for configuration.

2. **Node Setup for Each Server via Terraform Invoke**
   
   **2.1 Docker Install**: Install Docker on each server to facilitate containerized application deployment.
   
   **2.2 Configuration Transfer**: Transfer necessary configuration files to each server.
   
   **2.3 Container Creation & Startup**: Create and start Docker containers for Grafana, Prometheus, Loki, Tempo, Node-Exporter, and Promtail.

3. **Cloudflare DNS**

   **3.1 DNS Records**: Configure Cloudflare DNS records to publish the IP addresses of the servers:
   - Create AAAA records to map hostnames to IPv6 addresses
   - Verify DNS propagation after record creation

## Example Pricing 💰

Here's an example of the monthly costs for running a cluster with three CAX11 nodes and a Cloudflare LoadBalancer:

- **Hetzner CAX11 Nodes**: 
  - 3 nodes x 3.29€ per node = 9.87€ per month

- **Hetzner Object Store**:
  - 1TB Storage & 1TB Traffic = 5€ per month

- **Cloudflare LoadBalancer**:
  - 3 nodes = $10.00 per month ($5 Base Fee + $5 for 3. node)

>**Note:** The pricing is based on the current Hetzner and Cloudflare pricing at the time of writing this README (December 2024). You should also consider traffic costs between the regions since it is treated as outbound traffic. Please refer to the latest pricing information at:
>- Hetzner Cloud Pricing: https://www.hetzner.com/cloud
>- Hetzner Object Storage Pricing: https://www.hetzner.com/storage/object-storage/
>- Cloudflare Load Balancer Pricing: https://www.cloudflare.com/plans/load-balancer-pricing/

**Total Estimated Cost**: ~25€ per month

## FAQ ❓

### Why use managed VMs instead of self-hosted servers? 🤔

We initially hosted the monitoring cluster on our own servers but encountered significant storage wear issues:

- In just 7 days of monitoring ~17 containers + hosts, we experienced:
  - 26% wear on high-grade NVMe SSDs
  - ~1.73PB of data written
  - ~1.22PB of data read

This excessive I/O load led us to switch to managed VMs, which provided several benefits: ✨
- Eliminated concerns about hardware wear and maintenance 🔧
- Improved availability through multi-datacenter deployment 🌐
- Reduced operational overhead 📉
- Cost-effective scaling 💰

### Why use Hetzner and Grafana Stack instead of other providers or full managed solutions? 🤷

#### Previous experience with Elastic Cloud ☁️

We previously used Elastic Cloud and experienced significant issues when running out of storage (due to excessive business growth) and incurring high costs due to the amount of traffic we were generating.

#### Simplicity 🎯

Ensuring SLOs required us to monitor hundreds of services, websites, databases and tools. When simplifying the monitoring setup, we chose to use Elastic Synthetic Monitors and experienced a bill higher than the cost of the cluster. This lead to us setting up dedicated locations for the agents therefore reducing the cost, but also increasing the complexity of the setup.

Sauron now provides a simple way to monitor without the need to setup dedicated locations for the agents, cost and complexity.

#### Cost & Reliability 💎

Sauron decreased our overall costs by 65% and provided a more reliable and scalable solution due to the increased number of nodes.

#### Performance ⚡

While having a large set of features and integrations, our previous Elastic Cloud cluster could not keep up with maintaining our indices and queries. We usually had to wait for 30+ seconds for the results to be returned. With Sauron we are now able to query the data from way more advanced dashboards and get the results in just a few seconds. 🚀

## Troubleshooting 🧰

### Container not starting

You can monitor the creation and startup of the containers by running `docker events --filter event=create --filter event=start --filter event=mount
` on the server.

## Checkout these other tools we love at Askrella ❤️

- [**Autobase**](https://github.com/vitabaks/autobase) allows us to provision a production ready Postgres cluster and provides a simple UI too.

## TODO 📝

- Cloudflare LoadBalancer & DNS
- Caddy TLS termination
- Only re-deploy configs when content changes
- Tests
- Encryption between nodes in internal network
- Uptime monitoring using chromium based agent
- Alerting
- OpenTelemetry support
- Grafana shared database
- OnCall integration

## Limitations 🚧

- We are running all components on each node. This means:
    - the containers may affect each others performance,
    - we don't utilize the scaling effects of scaling each component separately of one another,
    - we cannot scale infinitely since we are limited by the overhead of all the "monolithic" nodes communicating with all other nodes.
    - **However**: The load is distributed since each Prometheus instance only manages a portion of recent metrics. This allows us to scale horizontally up to a reasonable number of instances and gain performance increases inversely proportional to the number of instances while maintaining high availability. Additionally, Thanos provides long-term storage and querying capabilities for historical metrics spanning multiple years. We can also tolerate peaks better than a single instance of e.g. Prometheus, since the data ingestion is distributed across multiple nodes.

## Contributing 🤝

We welcome contributions from the community!

## License ⚖️

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.

## Maintainers 👥

[Askrella - Consulting is more than giving advice](https://askrella.de)

- **Steve** - [steve-hb](https://github.com/steve-hb) - contact@askrella.de

---

For any questions or support, please contact the Askrella team at contact@askrella.de.

Happy Monitoring! 🎉 📊 🚀

