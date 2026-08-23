---
title: Issue Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Issue Certificates

As **root**, set the request values:

```sh
ENVIRONMENT=dev
KIND=web-server
SUBJECT=pool-dev.osoyalce.com
TARGET=pool-dev
OUTPUT="/var/lib/bmca/issued/$TARGET"
```

Create a separate password for the transferred private key:

```sh
umask 077
openssl rand -base64 48 > /root/.bmca-leaf
```

Issue the certificate:

```sh
/opt/bmca/scripts/issue-x509.sh \
  --environment "$ENVIRONMENT" \
  --kind "$KIND" \
  --subject "$SUBJECT" \
  --san "$SUBJECT" \
  --output-dir "$OUTPUT" \
  --provisioner-password-file /root/.bmca \
  --key-password-file /root/.bmca-leaf
```

Valid kinds are:

```text
web-server
mariadb-server
mariadb-replication
mariadb-client
admin-client
```

Client certificates do not require `--san`.

Create the transfer archive:

```sh
install -m 0644 /var/lib/step-ca/certs/root_ca.crt "$OUTPUT/root_ca.crt"
install -m 0644 /var/lib/step-ca/certs/intermediate_ca.crt "$OUTPUT/intermediate_ca.crt"
tar -C "$(dirname "$OUTPUT")" -cf "/var/lib/bmca/issued/$TARGET.tar" "$TARGET"
cd /var/lib/bmca/issued
sha256sum "$TARGET.tar" > "$TARGET.tar.sha256"
```

Transfer these files with SSH:

```text
/var/lib/bmca/issued/REPLACE_WITH_TARGET.tar
/var/lib/bmca/issued/REPLACE_WITH_TARGET.tar.sha256
```

Transfer `/root/.bmca-leaf` separately.

---

[Home](/index.html)