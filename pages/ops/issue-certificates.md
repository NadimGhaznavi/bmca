---
title: Issue Certificates
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Issue Certificates

Set the request values:

```sh
root@sally:~ # ENVIRONMENT=dev
root@sally:~ # KIND=web-server
root@sally:~ # SUBJECT=pool-dev.osoyalce.com
root@sally:~ # TARGET=pool-dev
root@sally:~ # OUTPUT="/var/lib/bmca/issued/$TARGET"
```

Create a separate password for the transferred private key:

```sh
root@sally:~ # umask 077
root@sally:~ # openssl rand -base64 48 > /root/.bmca-leaf
```

Issue the certificate:

```sh
root@sally:~ # /opt/bmca/scripts/issue-x509.sh \
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
root@sally:~ # install -m 0644 /var/lib/step-ca/certs/root_ca.crt "$OUTPUT/root_ca.crt"
root@sally:~ # install -m 0644 /var/lib/step-ca/certs/intermediate_ca.crt "$OUTPUT/intermediate_ca.crt"
root@sally:~ # tar -C "$(dirname "$OUTPUT")" -cf "/var/lib/bmca/issued/$TARGET.tar" "$TARGET"
root@sally:~ # cd /var/lib/bmca/issued
root@sally:/var/lib/bmca/issued # sha256sum "$TARGET.tar" > "$TARGET.tar.sha256"
```

Transfer these files with SSH:

```text
/var/lib/bmca/issued/REPLACE_WITH_TARGET.tar
/var/lib/bmca/issued/REPLACE_WITH_TARGET.tar.sha256
```

Transfer `/root/.bmca-leaf` separately.
