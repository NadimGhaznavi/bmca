---
title: Set Up the CA
author_profile: true
layout: single
---

![BMCA Logo](/pages/images/bmca-logo.png)

# Set Up the CA

As **root**, install BMCA first. Then create its password and initialize it directly on the
host that will issue certificates:

```sh
umask 077
openssl rand -base64 48 > /root/.bmca
/opt/bmca/scripts/initialize-bmca.sh --env prod
```

This one command creates and configures the CA, installs `ca.json` and the
intermediate password as `/etc/step-ca/ca.json` and
`/etc/step-ca/intermediate-password`, installs the runtime state in
`/var/lib/step-ca`, enables and starts `step-ca.service`, and validates its
health. Local root CA material is retained under
`/var/lib/bmca/root-ca`; it is deliberately not copied into the step-ca
runtime secrets. BMCA's encrypted backup includes it.

Use `--env dev` on Sally.

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

Perform a validation check:

```sh
/opt/bmca/scripts/validate-ca.sh --env prod
```

Example output:

```
[PASS] test paris = paris
[PASS] test -x /usr/bin/step
[PASS] test -x /usr/bin/step-ca
[PASS] test -f /etc/step-ca/ca.json
[PASS] test ! -e /var/lib/step-ca/secrets/root_ca_key
[PASS] test -f /var/lib/step-ca/certs/root_ca.crt
[PASS] test -f /var/lib/step-ca/certs/intermediate_ca.crt
[PASS] test -f /var/lib/step-ca/secrets/ssh_host_ca_key
[PASS] test -f /var/lib/step-ca/secrets/ssh_user_ca_key
/var/lib/step-ca/certs/intermediate_ca.crt: OK
[PASS] openssl verify -CAfile /var/lib/step-ca/certs/root_ca.crt /var/lib/step-ca/certs/intermediate_ca.crt
[PASS] systemctl is-active --quiet step-ca.service
{"status":"ok"}
[PASS] curl --fail --silent --show-error --retry 10 --retry-delay 1 --retry-connrefused --cacert /var/lib/step-ca/certs/root_ca.crt https://ca.osoyalce.com:9000/health
[SUCCESS] prod CA validation passed.
```

The command refuses to overwrite an existing root CA directory or installed
CA. To start over, run the clean installer again and then repeat initialization.

---

[Home](/index.html)
