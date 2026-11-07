#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for name in install upgrade uninstall; do
    bash -n "$ROOT/scripts/$name.sh"
    "$ROOT/scripts/$name.sh" --help >/dev/null
done
bash -n "$ROOT/scripts/new-release.sh"
"$ROOT/scripts/new-release.sh" --help >/dev/null
python3 -B "$ROOT/scripts/check-cmdb.py" --root "$ROOT" --name BMCA bmca/constants/DBMCA.py
python3 -B "$ROOT/tests/test_installation.py"
python3 -B "$ROOT/tests/test_lifecycle_failures.py"
python3 -B "$ROOT/tests/test_dependencies.py"
python3 -B "$ROOT/tests/test_localization.py"
python3 -B "$ROOT/tests/test_release.py"
printf 'All applicable tests passed.\n'
