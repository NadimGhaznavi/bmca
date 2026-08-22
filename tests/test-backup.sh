#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then printf 'Backup integration test skipped (requires root).\n'; exit 0; fi

work=$(mktemp -d /tmp/bmca-backup-test.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/etc/step-ca" "$work/state/certs" "$work/state/secrets" \
    "$work/state/db" "$work/root-ca/certs" "$work/root-ca/secrets" \
    "$work/install/conf" "$work/target" "$work/backup-work"
printf '#!/usr/bin/env bash\nexit 1\n' >"$work/bin/systemctl"; chmod 0755 "$work/bin/systemctl"
printf '{}\n' >"$work/etc/step-ca/ca.json"
printf 'test root certificate\n' >"$work/state/certs/root_ca.crt"
printf 'test intermediate certificate\n' >"$work/state/certs/intermediate_ca.crt"
printf 'encrypted intermediate key\n' >"$work/state/secrets/intermediate_ca_key"
printf 'test root certificate\n' >"$work/root-ca/certs/root_ca.crt"
printf 'encrypted root key\n' >"$work/root-ca/secrets/root_ca_key"
printf 'dev\n' >"$work/install/conf/environment"
printf 'disposable-backup-test-passphrase\n' >"$work/backup-password"; chmod 0600 "$work/backup-password"
cp "$ROOT/conf/settings.cfg" "$work/settings.cfg"
printf '%s\n' \
    "DEV_CA_HOST=\"$(hostname -s)\"" \
    "STEP_CA_CONFIG_DIR=\"$work/etc/step-ca\"" \
    "STEP_CA_CONFIG_FILE=\"$work/etc/step-ca/ca.json\"" \
    "STEP_CA_STATE_DIR=\"$work/state\"" \
    "STEP_CA_CERTS_DIR=\"$work/state/certs\"" \
    "STEP_CA_SECRETS_DIR=\"$work/state/secrets\"" \
    "STEP_CA_DB_DIR=\"$work/state/db\"" \
    "BMCA_ROOT_CA_DIR=\"$work/root-ca\"" \
    "INSTALL_CONF_DIR=\"$work/install/conf\"" \
    "DEV_BACKUP_TARGET_DIR=\"$work/target\"" \
    "BACKUP_PASSPHRASE_FILE=\"$work/backup-password\"" \
    "BACKUP_WORK_DIR=\"$work/backup-work\"" >>"$work/settings.cfg"

PATH="$work/bin:$PATH" BMCA_SETTINGS="$work/settings.cfg" \
    "$ROOT/scripts/backup-ca.sh" --environment dev >/dev/null
archive=$(find "$work/target" -maxdepth 1 -name '*.tar.gpg' -type f -print -quit)
[[ -n $archive && -f $archive.sha256 ]]
sha256sum -c "$archive.sha256" >/dev/null
listing=$(gpg --batch --quiet --pinentry-mode loopback --passphrase-file "$work/backup-password" \
    --decrypt "$archive" | tar -tf -)
[[ $listing == *"${work#/}/etc/step-ca/ca.json"* ]]
[[ $listing == *"${work#/}/state/secrets/intermediate_ca_key"* ]]
[[ $listing == *"${work#/}/root-ca/secrets/root_ca_key"* ]]
[[ $listing != *"${work#/}/state/secrets/root_ca_key"* ]]
[[ -z $(find "$work/target" -maxdepth 1 -type f ! -name '*.gpg' ! -name '*.sha256' -print -quit) ]]
printf 'Encrypted backup integration test passed.\n'
