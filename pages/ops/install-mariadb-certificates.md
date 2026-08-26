---
title: Install MariaDB Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Introduction

This page provides a procedure for installing an SSL certificate into MariaDb.

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

# Install the certificates

**TBD** Make sure the targets match what's in the INI (see below).

---

# Configure MariaDB

Edit the `/etc/mysql/mariadb.conf.d/50-server.cnf` and make sure the following lines 

```ini
[mariadb]
ssl_ca=/etc/mysql/tls/root_ca.crt
ssl_cert=/etc/mysql/tls/REPLACE_WITH_SUBJECT.crt
ssl_key=/etc/mysql/tls/server.key
require_secure_transport=ON
```

---

# Restart and verify

```sh
systemctl restart mariadb
mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('have_ssl','ssl_ca','ssl_cert','ssl_key','require_secure_transport');"
```
