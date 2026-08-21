# Initialization ceremony

The cryptographic procedure is implemented by `scripts/initialize-ca.sh`.
This document is the operator runbook for invoking it and completing the
physical and two-person controls that software cannot perform.

Perform production initialization on a clean, offline Debian system. Prepare
two independent secure copies of the resulting workspace before concluding the
ceremony. Record operators, timestamps, Smallstep versions, root fingerprint,
and transfer-bundle checksum on paper or in an approved audit record.

1. Create `/root/.bmca` as the Smallstep CA/provisioner password file and set
   its mode to `0600`. It must remain outside Git and outside the workspace.
2. Run `initialize-ca.sh offline` with the selected environment and a new
   absolute workspace path.
3. Verify the displayed root fingerprint through a second operator.
4. Inspect the online tar file. It must not contain `root_ca_key`.
5. Move the full workspace, including the root key, to offline encrypted media.
6. Transfer only the online bundle to the CA host. Transfer `/root/.bmca`
   through a separate secure channel and verify its mode is still `0600`.
7. Run `install.sh`, followed by `initialize-ca.sh import`. The import starts
   `step-ca` and validates the running CA before it succeeds.
8. Configure the separate backup passphrase as described
   in [backup and restoration](backup-restore.md), and create the first backup.

The offline command automatically creates and checks the filtered online
bundle, writes its SHA-256 file, and records the CA identity, tool versions,
timestamp, root fingerprint, and bundle digest in a `.manifest` file. It aborts
if the transfer bundle contains `root_ca_key`.

### Offline system

```sh
scripts/initialize-ca.sh offline \
  --environment prod \
  --workspace /secure/offline/bmca-prod
```

### Production CA host

```sh
sudo scripts/install.sh --environment prod
sudo scripts/initialize-ca.sh import \
  --environment prod \
  --bundle /secure/transfer/bmca-prod-online-prod.tar
sudo install -d -m 0700 /etc/bmca
sudo sh -c 'umask 077; openssl rand -base64 48 > /etc/bmca/backup-passphrase'
sudo scripts/backup-ca.sh --environment prod
```

Never run the production ceremony on Sally or store its workspace on NFS.

## Password file example

`/root/.bmca` is a plain-text file containing exactly one strong password on
one line. It has no variable name, quotes, or surrounding whitespace:

```text
<one long, randomly generated password; do not use this placeholder>
```

Create it without exposing the password in shell history:

```sh
umask 077
openssl rand -base64 48 > /root/.bmca
chmod 0600 /root/.bmca
test "$(stat -c '%a' /root/.bmca)" = 600
```

Generate independent files for development and production. During a ceremony,
transfer the applicable file to the CA host through a channel separate from
the online bundle. Do not print it, place it on NFS, or commit it to Git.
