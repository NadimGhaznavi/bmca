---
title: Install MariaDB Certificate
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Introduction

This page describes how to install an XMR Pool TLS certificate on a MariaDB server with the [install-db-cert.sh](/scripts/install-db-cert.sh) script. The script retrieves the correct environment archive, validates its contents, installs the certificate files, and restarts MariaDB.

---

# Prerequisites

Run the script as `root` on the target database server. The server must have:

- The [BMCA certificate-target tools](/pages/ops/install-ca-target) installed under `/opt/bmca` with `install-ca-target.sh`.
- MariaDB installed with a `mysql` group.
- Password-free root SSH access to the certificate source host.
- `/root/.bmca-leaf`, containing the password used to encrypt the certificate's private key, with mode `0600`.

The database server does not need `step-ca`, the `step` CLI, CA keys, or CA state. It only needs the installed BMCA scripts and settings plus the standard utilities checked by the installer.

From a BMCA source checkout, install the target-safe tools with:

```sh
./scripts/install-ca-target.sh
```

This copies only the target installer, database certificate installer, shared shell library, and target settings into `/opt/bmca`.

If `/root/.bmca-leaf` is missing, retrieve it separately from the production CA:

```sh
scp root@paris:/root/.bmca-leaf /root/.bmca-leaf
chmod 0600 /root/.bmca-leaf
```

The certificate source and deployment paths are configured in `/opt/bmca/conf/target-settings.cfg`:

```sh
XMR_CERT_SOURCE_HOST="paris"
XMR_CERT_SOURCE_DIR="/root/certs"
```

The script uses non-interactive SSH and exits immediately if authentication is unavailable.

---

# Configure MariaDB

Before installing a certificate, ensure `/etc/mysql/mariadb.conf.d/50-server.cnf` contains these settings in a server option group:

```ini
[mariadb]
ssl-ca = /etc/mysql/cacert.pem
ssl-cert = /etc/mysql/server-cert.pem
ssl-key = /etc/mysql/server-key.pem
require-secure-transport = ON
```

The installer deploys files using these generic names, regardless of the environment-specific certificate subject.

---

# Install the Certificate

Supply the environment and the database server's certificate subject. For the DEV database server, run:

```sh
/opt/bmca/scripts/install-db-cert.sh \
  --env dev \
  --subject xmr-db-dev.osoyalce.com
```

Other supported subject formats are:

```text
QA:    xmr-db1-qa.osoyalce.com, xmr-db2-qa.osoyalce.com
PROD:  xmr-db1.osoyalce.com,    xmr-db2.osoyalce.com
```

Use `--key-password-file FILE` only when the leaf-key password is stored somewhere other than `/root/.bmca-leaf`:

```sh
/opt/bmca/scripts/install-db-cert.sh \
  --env qa \
  --subject xmr-db1-qa.osoyalce.com \
  --key-password-file /root/alternate-leaf-password
```

The password file must have mode `0600`.

The script performs the following operations:

1. Downloads the environment archive and its SHA-256 checksum over non-interactive SCP.
2. Verifies the archive checksum.
3. Extracts only the root CA, intermediate CA, and requested database certificate/key pair.
4. Validates the certificate chain and DNS subject.
5. Decrypts the private key and confirms that it matches the certificate.
6. Backs up any existing MariaDB certificate files.
7. Installs the following files with `root:mysql` ownership:

   ```text
   /etc/mysql/cacert.pem       0644
   /etc/mysql/server-cert.pem  0644
   /etc/mysql/server-key.pem   0640
   ```

8. Installs `/etc/mysql/mariadb.conf.d/60-bmca-client.cnf` so local MariaDB command-line clients trust `/etc/mysql/cacert.pem`.
9. Restarts MariaDB.

Temporary archives, extracted certificates, and decrypted staging keys are removed automatically when the script exits.

---

# Verify the Installation

Confirm that MariaDB restarted successfully:

```sh
systemctl --no-pager --full status mariadb
```

Use the local Unix socket to inspect the server's TLS configuration without invoking client-side certificate verification:

```sh
mariadb --no-defaults --protocol=socket --skip-ssl \
  -e "SHOW VARIABLES WHERE Variable_name IN ('have_ssl','ssl_ca','ssl_cert','ssl_key','require_secure_transport');"
```

`have_ssl` must be `YES`, and the configured paths must match the three files under `/etc/mysql`.

Finally, verify an actual TLS connection using the certificate's DNS name and the installed private CA root. For DEV:

```sh
mariadb \
  --host=xmr-db-dev.osoyalce.com \
  --ssl-ca=/etc/mysql/cacert.pem \
  --ssl-verify-server-cert \
  -e "SHOW SESSION STATUS WHERE Variable_name IN ('Ssl_version','Ssl_cipher');"
```

Both status values must be non-empty. Connecting as `sally` would fail hostname verification because the certificate is issued to `xmr-db-dev.osoyalce.com`.

---

# Backups

Before replacing the deployed files, the script copies any existing certificates and key into a timestamped, root-only directory:

```text
/var/backups/bmca/mariadb-certificates-YYYYMMDDTHHMMSSZ.XXXXXX/
```

The success message reports the exact backup directory. Retain that directory until the new certificate has been verified.

---

# Verification

```sh
root@sally:~/bmca # mysql -u root
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 32
Server version: 11.8.6-MariaDB-0+deb13u1 from Debian -- Please help get to 10k stars at https://github.com/MariaDB/Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> status;
--------------
mysql from 11.8.6-MariaDB, client 15.2 for debian-linux-gnu (x86_64) using  EditLine wrapper

Connection id:		32
Current database:	
Current user:		root@localhost
SSL:			Cipher in use is TLS_AES_256_GCM_SHA384, cert is OK
Current pager:		stdout
Using outfile:		''
Using delimiter:	;
Server:			MariaDB
Server version:		11.8.6-MariaDB-0+deb13u1 from Debian -- Please help get to 10k stars at https://github.com/MariaDB/Server
Protocol version:	10
Connection:		Localhost via UNIX socket
Server characterset:	utf8mb4
Db     characterset:	utf8mb4
Client characterset:	utf8mb4
Conn.  characterset:	utf8mb4
UNIX socket:		/run/mysqld/mysqld.sock
Uptime:			1 min 47 sec

Threads: 1  Questions: 63  Slow queries: 0  Opens: 33  Open tables: 26  Queries per second avg: 0.588
--------------

MariaDB [(none)]> 
```