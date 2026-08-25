---
title: Issue Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Issue Certificates

Run the command on the CA host that matches the environment: `dev` runs on
Sally and `prod` runs on Paris. Each host has a different root CA, so an
environment/host mismatch cannot authenticate the selected CA endpoint.

As **root**, set the request values. This development example runs on Sally:

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
  --env "$ENVIRONMENT" \
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

If the client reports `certificate signed by unknown authority`, first check
that the hostname and environment match:

```sh
hostname -s
cat /opt/bmca/conf/environment
```

The expected pairs are `sally` / `dev` and `paris` / `prod`. Do not work
around a mismatch by disabling TLS verification; run the request on the
matching CA host with the matching environment instead.

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
