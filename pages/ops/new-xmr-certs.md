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

# Output

The script generates 22 certificate/key pairs in a temporary, root-only workspace:

- Web, app, admin, and cluster names use `web-server`.
- Database names use `mariadb-server`.
- Every certificate uses `--env prod`.
- Default password files are `/root/.bmca` and `/root/.bmca-leaf`.

The temporary workspace is removed automatically. Loose certificate and key files are not retained after the archives have been created. Static and CLI tests pass.

## Environment Archives

After issuing all certificates successfully, the script creates `./certs` containing only three deployment archives and a SHA-256 checksum for each one:

```text
certs/
├── xmr-certs-dev.tar.gz
├── xmr-certs-dev.tar.gz.sha256
├── xmr-certs-qa.tar.gz
├── xmr-certs-qa.tar.gz.sha256
├── xmr-certs-prod.tar.gz
└── xmr-certs-prod.tar.gz.sha256
```

The DEV archive contains 4 certificate/key pairs. The QA and PROD archives each contain 9 certificate/key pairs. Every archive has this layout:

```text
root_ca.crt
intermediate_ca.crt
certificates/
  <environment-specific certificate and encrypted key files>
```

The archives, checksum files, and private keys are created with mode `0600`. The private keys remain encrypted with the password from `/root/.bmca-leaf`; gzip compression does not provide encryption. All three archives contain the production CA chain because every XMR certificate is issued with `--env prod`.

The output directory is created with mode `0700`, and the script refuses to overwrite an existing output directory. Verify and extract an archive on its target system with commands such as:

```sh
sha256sum -c xmr-certs-qa.tar.gz.sha256
tar -xzf xmr-certs-qa.tar.gz
```

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
