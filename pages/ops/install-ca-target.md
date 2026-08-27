---
title: Install BMCA on a Certificate Target
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Introduction

Use [install-ca-target.sh](/scripts/install-ca-target.sh) to install BMCA certificate-consumer tools on a database, web, or application host. A certificate target does not operate a Certificate Authority and does not need `step`, `step-ca`, CA keys, provisioner templates, or CA state.

The target installer is also safe to run on a CA host that provides an application service. It updates only target-managed files and does not remove existing CA tooling.

---

# Prerequisites

Run the installer as `root` from a complete BMCA source checkout. The target host must provide these commands:

```text
install
scp
ssh
sha256sum
tar
openssl
systemctl
```

The installer checks every dependency before copying files.

---

# Install the Target Tools

Clone or update BMCA on the target host, then run:

```sh
cd /root/bmca
./scripts/install-ca-target.sh
```

Expected output:

```text
[SUCCESS] Installed BMCA certificate-target tools in /opt/bmca
```

The script installs this minimal runtime:

```text
/opt/bmca/
├── conf/
│   └── target-settings.cfg
└── scripts/
    ├── install-ca-target.sh
    ├── install-db-cert.sh
    └── lib/
        └── common.sh
```

Files are owned by `root:root`. Configuration files use mode `0644`; directories and executable scripts use mode `0755`.

---

# Configure the Target

Review `/opt/bmca/conf/target-settings.cfg` after installation:

```sh
XMR_CERT_SOURCE_HOST="paris"
XMR_CERT_SOURCE_DIR="/root/certs"
TARGET_LEAF_KEY_PASSWORD_FILE="/root/.bmca-leaf"

MARIADB_GROUP="mysql"
MARIADB_SERVICE="mariadb"
MARIADB_CA_FILE="/etc/mysql/cacert.pem"
MARIADB_CERT_FILE="/etc/mysql/server-cert.pem"
MARIADB_KEY_FILE="/etc/mysql/server-key.pem"
MARIADB_CERT_BACKUP_DIR="/var/backups/bmca"
```

The settings file contains public configuration only. Do not store passwords or private keys in it.

The target must have password-free root SSH access to `XMR_CERT_SOURCE_HOST`. The leaf-key password remains a separate root-only file at `TARGET_LEAF_KEY_PASSWORD_FILE` and must use mode `0600`.

---

# Verify the Installation

Confirm that the expected files exist. On a dedicated target that was not already a CA host, also confirm that no CA service was installed:

```sh
test -x /opt/bmca/scripts/install-ca-target.sh
test -x /opt/bmca/scripts/install-db-cert.sh
test -x /opt/bmca/scripts/lib/common.sh
test -f /opt/bmca/conf/target-settings.cfg
test ! -e /opt/bmca/systemd/step-ca.service
```

Display the available database certificate installer options:

```sh
/opt/bmca/scripts/install-db-cert.sh --help
```

Continue with [Install MariaDB Certificate](/pages/ops/install-mariadb-certificate) when preparing a MariaDB target.

---

[Home](/index.html)
