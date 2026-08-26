---
title: Install MariaDB Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Introduction

This page provides a procedure for installing an SSL certificate for MariaDb.

---


# Retrieve the Certificate and Key Files

Issue the commands below on the database server. In this example, the Certificate Authority is running on `paris`.

```sh
scp paris:/var/lib/step-ca/certs/root_ca.crt .
scp paris:/root/new-certs/xmr-db-dev.osoyalce.com.crt .
scp paris:/root/new-certs/xmr-db-dev.osoyalce.com.key .
```

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
