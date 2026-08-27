#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

[[ -f "$ROOT/scripts/lib/common.sh" ]] || {
    printf 'Required shell library is missing: scripts/lib/common.sh\n' >&2
    exit 1
}
shopt -s nullglob
scripts=("$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh)
((${#scripts[@]} > 0)) || { printf 'No shell scripts found.\n' >&2; exit 1; }
for script in "${scripts[@]}"; do bash -n "$script"; done
bash -n "$ROOT/conf/settings.cfg"
bash -n "$ROOT/conf/target-settings.cfg"
# shellcheck source=/dev/null
source "$ROOT/conf/settings.cfg"
[[ $PROJECT_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]
[[ $STEP_CLI_VERSION == 0.30.6 && $STEP_CA_VERSION == 0.30.2 && $DEBIAN_VERSION == 13 ]]
[[ $DEV_CA_NAME != "$PROD_CA_NAME" ]]
[[ $DEV_CA_HOST != "$PROD_CA_HOST" && $DEV_CA_ADDRESS != "$PROD_CA_ADDRESS" ]]
[[ $DEV_BACKUP_TARGET_DIR != "$PROD_BACKUP_TARGET_DIR" ]]
[[ $STEP_CA_STATE_DIR != "$BACKUP_NFS_MOUNT"/* ]]
[[ $BMCA_STATE_DIR != "$STEP_CA_STATE_DIR" && $BMCA_CONFIG_DIR != "$STEP_CA_CONFIG_DIR" ]]
[[ $STEP_CA_SECRETS_DIR == "$STEP_CA_STATE_DIR"/* ]]
[[ $CA_PASSWORD_FILE != "$BACKUP_PASSPHRASE_FILE" ]]
[[ $STEP_CA_HEALTH_RETRIES =~ ^[1-9][0-9]*$ && $STEP_CA_HEALTH_RETRY_DELAY =~ ^[0-9]+$ ]]
# shellcheck source=/dev/null
source "$ROOT/conf/target-settings.cfg"
[[ -n $XMR_CERT_SOURCE_HOST && $XMR_CERT_SOURCE_DIR == /* ]]
for path in "$TARGET_LEAF_KEY_PASSWORD_FILE" "$MARIADB_CA_FILE" "$MARIADB_CERT_FILE" \
    "$MARIADB_KEY_FILE" "$MARIADB_CERT_BACKUP_DIR"; do [[ $path == /* ]]; done
for path in "$SOURCE_DIR" "$INSTALL_DIR" "$STEP_CA_CONFIG_DIR" "$STEP_CA_STATE_DIR" \
    "$DEV_BACKUP_TARGET_DIR" "$PROD_BACKUP_TARGET_DIR"; do [[ $path == /* ]]; done
for script in "$ROOT"/scripts/*.sh "$ROOT"/scripts/lib/*.sh "$ROOT"/tests/*.sh; do [[ -x $script ]]; done
grep -Fq "ExecStart=$STEP_CA_BIN $STEP_CA_CONFIG_FILE --password-file $STEP_CA_PASSWORD_FILE" \
    "$ROOT/systemd/step-ca.service"
grep -Fq "User=$STEP_CA_USER" "$ROOT/systemd/step-ca.service"
grep -Fq "ConditionPathExists=$STEP_CA_CONFIG_FILE" "$ROOT/systemd/step-ca.service"
grep -Fq "ConditionPathExists=$STEP_CA_PASSWORD_FILE" "$ROOT/systemd/step-ca.service"
grep -Fq 'rm -rf -- "$STEP_CA_CONFIG_DIR"' "$ROOT/scripts/install-ca.sh"
grep -Fq 'rm -rf -- "$STEP_CA_STATE_DIR"' "$ROOT/scripts/install-ca.sh"
grep -Fq 'Run initialize-bmca.sh to create the CA.' "$ROOT/scripts/install-ca.sh"
grep -Fq 'systemctl enable --now step-ca.service' "$ROOT/scripts/restore-ca.sh"
grep -Fq 'chmod 0640 "$STEP_CA_CONFIG_FILE" "$STEP_CA_PASSWORD_FILE"' "$ROOT/scripts/restore-ca.sh"
grep -Fq 'conf/target-settings.cfg' "$ROOT/scripts/install-ca-target.sh"
grep -Fq 'scripts/install-db-cert.sh' "$ROOT/scripts/install-ca-target.sh"
! grep -Eq 'step-ca|issue-x509|initialize-bmca|systemd/' "$ROOT/scripts/install-ca-target.sh"
for script in issue-x509.sh issue-ssh.sh; do
    grep -Fq 'require_root; assert_host_matches_environment' "$ROOT/scripts/$script"
done
! grep -RIE --exclude-dir=.git -- '-----BEGIN (ENCRYPTED |RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' "$ROOT"
printf 'Static checks passed.\n'
