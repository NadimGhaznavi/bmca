#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/conf/settings.cfg"
work=$(mktemp -d /tmp/bmca-offline-test.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
printf '%s\n' 'bmca-disposable-test-password' >"$work/password"
chmod 0600 "$work/password"

"$ROOT/scripts/initialize-ca.sh" offline --environment dev \
    --workspace "$work/pki" --password-file "$work/password" >/dev/null
bundle="$work/pki-online-dev.tar"
[[ -f $bundle && -f $bundle.sha256 ]]
[[ -f $bundle.manifest ]]
! tar -tf "$bundle" | grep -q root_ca_key
tar -tf "$bundle" | grep -qx config/ca.json
! tar -tf "$bundle" | grep -qx config/defaults.json
tar -tf "$bundle" | grep -qx secrets/ssh_host_ca_key
tar -tf "$bundle" | grep -qx secrets/ssh_user_ca_key
[[ -f $work/pki/secrets/root_ca_key ]]
[[ $(sha256sum "$work/pki/secrets/ssh_host_ca_key" | awk '{print $1}') != \
   $(sha256sum "$work/pki/secrets/ssh_user_ca_key" | awk '{print $1}') ]]
grep -Fq '"root": "/var/lib/step-ca/certs/root_ca.crt"' "$work/pki/config/ca.json"
grep -Fq '"key": "/var/lib/step-ca/secrets/intermediate_ca_key"' "$work/pki/config/ca.json"
grep -Fq '"dataSource": "/var/lib/step-ca/db"' "$work/pki/config/ca.json"
! grep -Fq "$work" "$work/pki/config/ca.json"
grep -Eq '^root_fingerprint=[0-9a-f]{64}$' "$bundle.manifest"
grep -Eq '^online_bundle_sha256=[0-9a-f]{64}$' "$bundle.manifest"
(cd "$work" && sha256sum -c "$(basename "$bundle").sha256")

# Exercise the offline half of intermediate rotation.
"$STEP_CLI_BIN" certificate create 'BMCA replacement intermediate' \
    "$work/intermediate_ca.csr" "$work/intermediate_ca_key" --csr \
    --password-file "$work/password" >/dev/null
root_fingerprint=$("$STEP_CLI_BIN" certificate fingerprint "$work/pki/certs/root_ca.crt")
printf '%s\n' 'environment=dev' 'ca_name=devca.osoyalce.com' \
    "root_fingerprint=$root_fingerprint" \
    "csr_sha256=$(sha256sum "$work/intermediate_ca.csr" | awk '{print $1}')" \
    >"$work/intermediate_ca.csr.manifest"
"$ROOT/scripts/rotate-intermediate.sh" sign --environment dev \
    --offline-workspace "$work/pki" --request "$work/intermediate_ca.csr" \
    --password-file "$work/password" >/dev/null
openssl verify -CAfile "$work/pki/certs/root_ca.crt" "$work/intermediate_ca.crt"
grep -Eq '^certificate_sha256=[0-9a-f]{64}$' "$work/intermediate_ca.crt.manifest"

# Reject a modified CSR and an environment mismatch before signing.
cp "$work/intermediate_ca.csr" "$work/tampered.csr"
cp "$work/intermediate_ca.csr.manifest" "$work/tampered.csr.manifest"
printf '\n' >>"$work/tampered.csr"
if "$ROOT/scripts/rotate-intermediate.sh" sign --environment dev \
    --offline-workspace "$work/pki" --request "$work/tampered.csr" \
    --password-file "$work/password" >/dev/null 2>&1; then
    printf 'Tampered CSR was accepted.\n' >&2; exit 1
fi
if "$ROOT/scripts/rotate-intermediate.sh" sign --environment prod \
    --offline-workspace "$work/pki" --request "$work/intermediate_ca.csr" \
    --password-file "$work/password" >/dev/null 2>&1; then
    printf 'Mismatched environment was accepted.\n' >&2; exit 1
fi
printf 'Offline initialization test passed.\n'
