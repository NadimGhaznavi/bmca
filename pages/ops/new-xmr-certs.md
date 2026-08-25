---
title: Generate XMR Pool Certificates
author_profile: true
layout: single
---

Quickly generate a new set of certificates for the [XMR Pool Project](https://xmrdocs) with the [new-xmr-certs.sh](/scripts/new-xmr-certs.sh) script.

---

# Usage

Run on the production CA:

```sh
cd /desired/parent/directory
/opt/bmca/scripts/new-xmr-certs.sh
```

---

# Output is 22 New Certificates

The script generates 22 certificate/key pairs in `./new-certs`:

- Web, app, admin, and cluster names use `web-server`.
- Database names use `mariadb-server`.
- Every certificate uses `--env prod`.
- Default password files are `/root/.bmca` and `/root/.bmca-leaf`.

The output directory must not already exist. Static and CLI tests pass.

---

# XMR Pool Project DNS

The certificates that are generated are based on the output of the *XMR Pool Project* `scripts/dns_report.py` script. An example invocation is shown below:

```sh
./scripts/dns_report.py
Environment  Service  DNS name                    Resolves to
---------------------------------------------------------------------------
DEV          Web      xmr-dev.osoyalce.com        sally.osoyalce.com
DEV          App      xmr-app-dev.osoyalce.com    sally.osoyalce.com
DEV          Admin    xmr-admin-dev.osoyalce.com  sally.osoyalce.com
DEV          DB       xmr-db-dev.osoyalce.com     sally.osoyalce.com
QA           Cluster  xmr-qa.osoyalce.com         xmr1-qa.osoyalce.com
QA           Web      xmr1-qa.osoyalce.com        islands.osoyalce.com
QA           App      xmr-app1-qa.osoyalce.com    islands.osoyalce.com
QA           Admin    xmr-admin1-qa.osoyalce.com  islands.osoyalce.com
QA           DB       xmr-db1-qa.osoyalce.com     islands.osoyalce.com
QA           Web      xmr2-qa.osoyalce.com        kermit.osoyalce.com
QA           App      xmr-app2-qa.osoyalce.com    kermit.osoyalce.com
QA           Admin    xmr-admin2-qa.osoyalce.com  kermit.osoyalce.com
QA           DB       xmr-db2-qa.osoyalce.com     kermit.osoyalce.com
PROD         Cluster  xmr.osoyalce.com            xmr1.osoyalce.com
PROD         Web      xmr1.osoyalce.com           bama.osoyalce.com
PROD         App      xmr-app1.osoyalce.com       bama.osoyalce.com
PROD         Admin    xmr-admin1.osoyalce.com     bama.osoyalce.com
PROD         DB       xmr-db1.osoyalce.com        bama.osoyalce.com
PROD         Web      xmr2.osoyalce.com           wintermute.osoyalce.com
PROD         App      xmr-app2.osoyalce.com       wintermute.osoyalce.com
PROD         Admin    xmr-admin2.osoyalce.com     wintermute.osoyalce.com
PROD         DB       xmr-db2.osoyalce.com        wintermute.osoyalce.com
```
