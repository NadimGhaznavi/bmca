#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/tests/test-static.sh"
"$ROOT/tests/test-cli.sh"
"$ROOT/tests/test-offline-init.sh"
"$ROOT/tests/test-backup.sh"
printf 'All applicable tests passed.\n'
