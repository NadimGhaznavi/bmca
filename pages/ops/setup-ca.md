---
title: Set Up CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Set Up CA

As **root**, install BMCA first. Then create its password and initialize it directly on the
host that will issue certificates:

```sh
umask 077
openssl rand -base64 48 > /root/.bmca
/opt/bmca/scripts/initialize-bmca.sh --environment prod
```

This one command creates and configures the CA, installs `ca.json` and the
intermediate password as `/etc/step-ca/ca.json` and
`/etc/step-ca/intermediate-password`, installs the runtime state in
`/var/lib/step-ca`, enables and starts `step-ca.service`, and validates its
health. Local root CA material is retained under
`/var/lib/bmca/root-ca`; it is deliberately not copied into the step-ca
runtime secrets. BMCA's encrypted backup includes it.

Use `--environment dev` on Sally.

Verify the resulting installation:

```sh
test -f /etc/step-ca/ca.json
test -f /etc/step-ca/intermediate-password
systemctl is-enabled step-ca.service
```

Output: 

```sh
enabled
```

```sh
/opt/bmca/scripts/validate-ca.sh --environment prod
[SUCCESS] prod CA validation passed.
```

The command refuses to overwrite an existing root CA directory or installed
CA. To start over, uninstall BMCA, remove the preserved `/etc/step-ca` and
`/var/lib/step-ca` directories, reinstall BMCA, and run initialization again.
