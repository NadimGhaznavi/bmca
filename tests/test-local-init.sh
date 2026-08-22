#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    printf 'Local initialization test skipped (requires root).\n'
    exit 0
fi

work=$(mktemp -d /tmp/bmca-local-init-test.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/etc/step-ca" "$work/state/certs" "$work/state/secrets" \
    "$work/state/db" "$work/install/conf"
printf '#!/usr/bin/env bash\nexit 0\n' >"$work/bin/systemctl"
printf '#!/usr/bin/env bash\nprintf '\''{"status":"ok"}\\n'\''\n' >"$work/bin/curl"
chmod 0755 "$work/bin/systemctl" "$work/bin/curl"
printf 'dev\n' >"$work/install/conf/environment"
printf 'bmca-disposable-local-password\n' >"$work/password"
chmod 0600 "$work/password"

cp "$ROOT/conf/settings.cfg" "$work/settings.cfg"
printf '%s\n' \
    "DEV_CA_HOST=\"$(hostname -s)\"" \
    'DEV_CA_NAME="bmca-local-test.invalid"' \
    "STEP_CA_CONFIG_DIR=\"$work/etc/step-ca\"" \
    "STEP_CA_CONFIG_FILE=\"$work/etc/step-ca/ca.json\"" \
    "STEP_CA_PASSWORD_FILE=\"$work/etc/step-ca/intermediate-password\"" \
    "STEP_CA_STATE_DIR=\"$work/state\"" \
    "STEP_CA_CERTS_DIR=\"$work/state/certs\"" \
    "STEP_CA_SECRETS_DIR=\"$work/state/secrets\"" \
    "STEP_CA_DB_DIR=\"$work/state/db\"" \
    'STEP_CA_USER="root"' \
    'STEP_CA_GROUP="root"' \
    "INSTALL_CONF_DIR=\"$work/install/conf\"" >>"$work/settings.cfg"

PATH="$work/bin:$PATH" BMCA_SETTINGS="$work/settings.cfg" \
    "$ROOT/scripts/initialize-ca.sh" local --environment dev \
    --workspace "$work/root-workspace" --password-file "$work/password" >/dev/null

[[ -f $work/etc/step-ca/ca.json ]]
[[ -f $work/etc/step-ca/intermediate-password ]]
[[ -f $work/state/certs/root_ca.crt ]]
[[ -f $work/state/certs/intermediate_ca.crt ]]
[[ -f $work/state/secrets/intermediate_ca_key ]]
[[ -f $work/state/templates/certs/x509/web-server.tpl ]]
[[ -f $work/root-workspace/secrets/root_ca_key ]]
[[ ! -e $work/state/secrets/root_ca_key ]]
cmp -s "$work/password" "$work/etc/step-ca/intermediate-password"
printf 'Single-host local initialization test passed.\n'
