#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
INSTALL_ROOT='/opt/bmca'

usage() {
    printf 'Usage: %s\n' "$(basename "$0")"
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

main() {
    while (($#)); do
        case $1 in
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done

    [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this command as root."

    local command_name
    for command_name in install scp ssh sha256sum tar openssl systemctl; do
        command -v "$command_name" >/dev/null 2>&1 || die "Required command not found: $command_name"
    done

    local -a source_files=(
        "$SOURCE_ROOT/conf/target-settings.cfg"
        "$SOURCE_ROOT/scripts/install-ca-target.sh"
        "$SOURCE_ROOT/scripts/install-db-cert.sh"
        "$SOURCE_ROOT/scripts/lib/common.sh"
    )
    local source_file
    for source_file in "${source_files[@]}"; do
        [[ -f $source_file ]] || die "Required source file not found: $source_file"
    done

    install -d -o root -g root -m 0755 \
        "$INSTALL_ROOT" \
        "$INSTALL_ROOT/conf" \
        "$INSTALL_ROOT/scripts" \
        "$INSTALL_ROOT/scripts/lib"
    install -o root -g root -m 0644 \
        "$SOURCE_ROOT/conf/target-settings.cfg" \
        "$INSTALL_ROOT/conf/target-settings.cfg"
    install -o root -g root -m 0755 \
        "$SOURCE_ROOT/scripts/install-ca-target.sh" \
        "$SOURCE_ROOT/scripts/install-db-cert.sh" \
        "$INSTALL_ROOT/scripts/"
    install -o root -g root -m 0755 \
        "$SOURCE_ROOT/scripts/lib/common.sh" \
        "$INSTALL_ROOT/scripts/lib/common.sh"

    printf '[SUCCESS] Installed BMCA certificate-target tools in %s\n' "$INSTALL_ROOT"
}

main "$@"
