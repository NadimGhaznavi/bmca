---
title: Install MariaDB Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Install MariaDB Certificates

Verify and extract the transferred MariaDB server archive:

```sh
root@db01:~ # cd /root/bmca-transfer
root@db01:/root/bmca-transfer # sha256sum -c db01.tar.sha256
root@db01:/root/bmca-transfer # tar -xf db01.tar
root@db01:/root/bmca-transfer # cd db01
```

Install the certificate and decrypt the key:

```sh
root@db01:/root/bmca-transfer/db01 # install -d -o mysql -g mysql -m 0750 /etc/mysql/tls
root@db01:/root/bmca-transfer/db01 # install -o mysql -g mysql -m 0644 *.crt /etc/mysql/tls/
root@db01:/root/bmca-transfer/db01 # openssl pkey -in REPLACE_WITH_SUBJECT.key \
  -passin file:/root/.bmca-leaf -out /etc/mysql/tls/server.key
root@db01:/root/bmca-transfer/db01 # chown mysql:mysql /etc/mysql/tls/server.key
root@db01:/root/bmca-transfer/db01 # chmod 0600 /etc/mysql/tls/server.key
```

Configure MariaDB:

```ini
[mariadb]
ssl_ca=/etc/mysql/tls/root_ca.crt
ssl_cert=/etc/mysql/tls/REPLACE_WITH_SUBJECT.crt
ssl_key=/etc/mysql/tls/server.key
require_secure_transport=ON
```

Restart and verify:

```sh
root@db01:~ # systemctl restart mariadb
root@db01:~ # mariadb -e "SHOW VARIABLES WHERE Variable_name IN ('have_ssl','ssl_ca','ssl_cert','ssl_key','require_secure_transport');"
```
