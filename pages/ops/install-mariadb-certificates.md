---
title: Install MariaDB Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Introduction

This page provides a procedure for installing an SSL certificate into MariaDb.

---

# Pre-Requisites

Ensure that the `/root/.bmca-leaf` file exists. If it does not then, as **root**:

```sh
cd /root
scp root@paris:/root/.bmca .
```

---

# Transfer the Certificate Files

Run these commands on the database server. This example retrieves the DEV archive and its checksum from the production Certificate Authority on `paris`:

```sh
install -d -m 0700 /root/bmca-transfer
cd /root/bmca-transfer
scp root@paris:/root/certs/xmr-certs-dev.tar.gz .
scp root@paris:/root/certs/xmr-certs-dev.tar.gz.sha256 .
```

Verify the tarball against the transferred SHA-256 checksum file:

```sh
sha256sum -c xmr-certs-dev.tar.gz.sha256
```

The command must report `xmr-certs-dev.tar.gz: OK`. Do not extract or install files from the archive if verification fails.

---

# Extract the Files

Create a root-only staging directory and extract only the CA certificates and the DEV MariaDB server certificate/key pair:

```sh
install -d -m 0700 /root/bmca-transfer/xmr-db-dev
tar -xzf xmr-certs-dev.tar.gz \
  -C /root/bmca-transfer/xmr-db-dev \
  --no-same-owner \
  root_ca.crt \
  intermediate_ca.crt \
  certificates/xmr-db-dev.osoyalce.com.crt \
  certificates/xmr-db-dev.osoyalce.com.key
```

Only these four files are extracted; the certificates and private keys for the other DEV services remain in the archive.

---

# Install the Files

Install the root CA using MariaDB's existing generic filename. Create `server-cert.pem` as a full server certificate chain containing the leaf certificate followed by the intermediate certificate:

```sh
cd /root/bmca-transfer/xmr-db-dev
install -o root -g mysql -m 0644 root_ca.crt /etc/mysql/cacert.pem
install -o root -g mysql -m 0644 /dev/null /etc/mysql/server-cert.pem
cat certificates/xmr-db-dev.osoyalce.com.crt \
  intermediate_ca.crt > /etc/mysql/server-cert.pem
```

Decrypt and install the MariaDB runtime key using the separately transferred key-password file. MariaDB must be able to start without prompting for this password:

```sh
umask 077
openssl pkey \
  -in certificates/xmr-db-dev.osoyalce.com.key \
  -passin file:/root/.bmca-leaf \
  -out /etc/mysql/server-key.pem
chown root:mysql /etc/mysql/server-key.pem
chmod 0640 /etc/mysql/server-key.pem
```

---

# Configure MariaDB

Edit `/etc/mysql/mariadb.conf.d/50-server.cnf` and make sure it contains these settings:

```ini
[mariadb]
ssl-ca = /etc/mysql/cacert.pem
ssl-cert = /etc/mysql/server-cert.pem
ssl-key = /etc/mysql/server-key.pem
require-secure-transport = ON
```

---

# Restart and verify

```sh
systemctl restart mariadb
mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('have_ssl','ssl_ca','ssl_cert','ssl_key','require_secure_transport');"
```
