---
title: Rotate the Intermediate CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Rotate the Intermediate CA

The local root under `/var/lib/bmca/root-ca` signs replacement intermediates.
First create the request and locate its timestamped directory:

```sh
root@sally:~ # /opt/bmca/scripts/rotate-intermediate.sh request --environment dev
root@sally:~ # ROTATION=$(find /var/lib/bmca/intermediate-rotation -mindepth 1 \
  -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
root@sally:~ # test -n "$ROTATION"
```

Sign it with the retained root, then install the replacement:

```sh
root@sally:~ # /opt/bmca/scripts/rotate-intermediate.sh sign \
  --environment dev \
  --request "$ROTATION/intermediate_ca.csr"
root@sally:~ # /opt/bmca/scripts/rotate-intermediate.sh install \
  --environment dev \
  --certificate "$ROTATION/intermediate_ca.crt" \
  --key "$ROTATION/intermediate_ca_key"
Install the replacement dev intermediate and restart step-ca? [y/N] y
```

The install step verifies the manifest, certificate chain, and key match. It
restores the previous intermediate automatically if service validation fails.
Create a fresh encrypted CA backup after a successful rotation.
