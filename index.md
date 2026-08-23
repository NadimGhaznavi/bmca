---
title: Bear & Moose Certificate Authority
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

---

The **Bear and Moose Certificate Authority** project aims to provide the basic functions of a Certificate Authority. Certificates are generated and can be installed on target systems to support SSL/TLS encryption. 

Use cases for **BMCA** include certificate management for active development teams, QA teams, and production environments.

---

# Deployment

Deployment occurs in development, QA, and production environments.

---

## Development Environment

The development environment consists of a single machine.

### Development Server

The following DNS names identify the development environment’s services.

| Component       | Record type | DNS name                     |
|-----------------|-------------|------------------------------|
| Bare-metal host | Hostname    | `sally.osoyalce.com`         |
| Web service     | CNAME       | `xmr-dev.osoyalce.com`       |
| Admin service   | CNAME       | `xmr-admin-dev.osoyalce.com` |
| DB server       | CNAME       | `xmr-db-dev.osoyalce.com`    |

---

## QA Environment

The QA environment has a pair of machines that are a hot/cold cluster.

The cluster uses a DNS name to route traffic.

| Component       | Record type | DNS name               |
|-----------------|-------------|------------------------|
| Cluster Service | CNAME       | `xmr-qa.osoyalce.com`  |

### QA Server 1

| Component       | Record type | DNS name                     |
|-----------------|-------------|------------------------------|
| Bare-metal host | Hostname    | `islands.osoyalce.com`       |
| Web service     | CNAME       | `xmr1-qa.osoyalce.com`       |
| Admin service   | CNAME       | `xmr-admin1-qa.osoyalce.com` |
| DB server       | CNAME       | `xmr-db1-qa.osoyalce.com`    |

### QA Server 2

| Component       | Record type | DNS name                     |
|-----------------|-------------|------------------------------|
| Bare-metal host | Hostname    | `kermit.osoyalce.com`        |
| Web service     | CNAME       | `xmr2-qa.osoyalce.com`       |
| Admin service   | CNAME       | `xmr-admin2-qa.osoyalce.com` |
| DB server       | CNAME       | `xmr-db2-qa.osoyalce.com`    |

---

## Production Environment

The production environment has a pair of machines that are a active/passive cluster.

The cluster uses a DNS name to route traffic.

| Component   | Record type | DNS name            |
|-------------|-------------|---------------------|
| Cluster VIP | CNAME       | `xmr.osoyalce.com`  |


### Production Server 1

| Component       | Record type | DNS name                  |
|-----------------|-------------|---------------------------|
| Bare-metal host | Hostname    | `bama.osoyalce.com`       |
| Web service     | CNAME       | `xmr1.osoyalce.com`       |
| Admin service   | CNAME       | `xmr-admin1.osoyalce.com` |
| DB server       | CNAME       | `xmr-db1.osoyalce.com`    |

### Production Server 2

| Component       | Record type | DNS name                     |
|-----------------|-------------|------------------------------|
| Bare-metal host | Hostname    | `wintermute.osoyalce.com`    |
| Web service     | CNAME       | `xmr2.osoyalce.com`          |
| Admin service   | CNAME       | `xmr-admin2.osoyalce.com`    |
| DB server       | CNAME       | `xmr-db2.osoyalce.com`       |

---

# Operations

## CA host

1. [Install BMCA](/pages/ops/install-bmca)
2. [Set Up CA](/pages/ops/setup-ca)
3. [Back Up CA](/pages/ops/backup-ca)
4. [Restore CA](/pages/ops/restore-ca)
5. [Issue Certificates](/pages/ops/issue-certificates)
6. [Issue SSH Certificates](/pages/ops/issue-ssh-certificates)
7. [Rotate the Intermediate CA](/pages/ops/rotate-intermediate)
8. [Uninstall BMCA](/pages/ops/uninstall-bmca)

## Target host

1. [Install MariaDB Certificates](/pages/ops/install-mariadb-certificates)
2. [Install Python Database Certificate](/pages/ops/install-python-db-certificate)
3. [Install Caddy Certificates](/pages/ops/install-caddy-certificates)

