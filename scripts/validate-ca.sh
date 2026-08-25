#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"; source "$SCRIPT_DIR/lib/common.sh"

main() {
    if [[ ${1:-} == -h || ${1:-} == --help ]]; then
        printf 'Usage: %s --env dev|prod\n' "$(basename "$0")"; exit 0
    fi
    [[ ${1:-} == --env && $# -eq 2 ]] || die "Usage: $(basename "$0") --env dev|prod"
    load_settings; select_environment "$2"; require_command openssl; require_command curl
    local failures=0
    check() { if "$@"; then printf '[PASS] %s\n' "$*"; else printf '[FAIL] %s\n' "$*" >&2; failures=$((failures+1)); fi; }
    check test "$(hostname -s)" = "$CA_HOST"
    check test -x "$STEP_CLI_BIN"; check test -x "$STEP_CA_BIN"
    check test -f "$STEP_CA_CONFIG_FILE"; check test ! -e "$STEP_CA_SECRETS_DIR/root_ca_key"
    check test -f "$STEP_CA_CERTS_DIR/root_ca.crt"; check test -f "$STEP_CA_CERTS_DIR/intermediate_ca.crt"
    check test -f "$STEP_CA_SECRETS_DIR/ssh_host_ca_key"; check test -f "$STEP_CA_SECRETS_DIR/ssh_user_ca_key"
    if [[ -f $STEP_CA_CERTS_DIR/root_ca.crt && -f $STEP_CA_CERTS_DIR/intermediate_ca.crt ]]; then
        check openssl verify -CAfile "$STEP_CA_CERTS_DIR/root_ca.crt" "$STEP_CA_CERTS_DIR/intermediate_ca.crt"
    fi
    check systemctl is-active --quiet step-ca.service
    check curl --fail --silent --show-error --retry "$STEP_CA_HEALTH_RETRIES" \
        --retry-delay "$STEP_CA_HEALTH_RETRY_DELAY" --retry-connrefused \
        --cacert "$STEP_CA_CERTS_DIR/root_ca.crt" "https://$CA_NAME:$STEP_CA_PORT$STEP_CA_HEALTH_PATH"
    ((failures == 0)) || die "$failures validation check(s) failed."
    success "$BMCA_ENV CA validation passed."
}
main "$@"
