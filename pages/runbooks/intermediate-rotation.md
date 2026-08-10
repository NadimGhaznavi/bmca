# Intermediate CA rotation

Rotate the online intermediate as a planned renewal before expiry. This
procedure does not activate the offline root as a network service. It transfers
a CSR to the offline root and returns only a signed certificate.

Do not use this procedure as the sole response to intermediate-key compromise.
With revocation deferred, clients would continue trusting the compromised
intermediate. That incident requires a new root hierarchy and trust-anchor
rollout, which is not automated in the current release.

## 1. Create the key and CSR on the CA host

For development on Sally:

```sh
cd /opt/bmca
sudo scripts/validate-ca.sh --environment dev
sudo scripts/rotate-intermediate.sh request --environment dev
```

The command prints the CSR path under the configured rotation directory. The
new encrypted private key remains on the CA host. Transfer only
`intermediate_ca.csr` and `intermediate_ca.csr.manifest` to the offline system.

## 2. Sign on the offline system

Mount or unlock the original offline ceremony workspace and verify
`/root/.bmca` is present with mode `0600`:

```sh
scripts/rotate-intermediate.sh sign \
  --environment dev \
  --offline-workspace /secure/offline/bmca-dev \
  --request /secure/transfer/intermediate_ca.csr
```

The script checks the CSR checksum and root fingerprint before using the root
key. It creates `intermediate_ca.crt` and `intermediate_ca.crt.manifest`.
Return those two files to Sally. Never transfer `root_ca_key`.

## 3. Install on the CA host

Use the exact private-key path printed by the request stage:

```sh
ROTATION_ID="REPLACE_WITH_TIMESTAMP_PRINTED_BY_REQUEST_STAGE"
sudo scripts/rotate-intermediate.sh install \
  --environment dev \
  --certificate /secure/transfer/intermediate_ca.crt \
  --key "/var/lib/bmca/intermediate-rotation/$ROTATION_ID/intermediate_ca_key"
```

Before confirmation, the script verifies the manifest, root fingerprint,
certificate chain, and public-key match. It then stops `step-ca`, installs the
replacement pair, restarts and validates the service, and automatically rolls
back if validation fails.

After a successful installation:

```sh
sudo scripts/backup-ca.sh --environment dev
openssl x509 -in /var/lib/step-ca/certs/intermediate_ca.crt \
  -noout -subject -issuer -serial -dates -fingerprint -sha256
```

Repeat with `prod` only on Paris and the production offline workspace.
