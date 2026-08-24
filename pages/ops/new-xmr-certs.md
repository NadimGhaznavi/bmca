---
title: Generate XMR Pool Certificates
author_profile: true
layout: single
---

# Generate XMR Pool Certifcates

Quickly spin up a set of brand new certificates for the [XMR Pool Project](https://xmrdocs) project certificates with the [new-xmr-certs.sh](/scripts/new-xmr-certs.sh) script.

---

# Usage

Run on the production CA:

```sh
cd /desired/parent/directory
/opt/bmca/scripts/new-xmr-certs.sh
```

---

# Output is 17 New Certificates

The script generates 17 certificate/key pairs in `./new-certs`:

- Web, admin, and cluster names use web-server.
- Database names use mariadb-server.
- Every certificate uses `--environment prod`.
- Default password files are `/root/.bmca` and `/root/.bmca-leaf`.

The output directory must not already exist. Static and CLI tests pass.
