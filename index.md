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

## XMR Pool Project Support

Quickly spin up a brand new *XMR Pool* project with the [new-xmr-certs.sh](/scripts/new-xmr-certs.sh) script.

Run on the production CA:

```sh
cd /desired/parent/directory
/opt/bmca/scripts/new-xmr-certs.sh
```

It generates 17 certificate/key pairs in `./new-certs`:

- Web, admin, and cluster names use web-server.
- Database names use mariadb-server.
- Every certificate uses `--environment prod`.
