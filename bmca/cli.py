"""Deploy BMCA's identity package using the pinned BMForge file installer.

At this checkpoint the payload is the Python identity package and lifecycle
tools. CA services and the planned MariaDB database are not provisioned here.
"""

import argparse
import os
from pathlib import Path
import subprocess

from bmca.BMCA import BMCA
from bmca.constants.DInstallation import DInstallation


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=DInstallation.ACTIONS)
    parser.add_argument("--check", action="store_true", help="Validate the operation without changing files")
    parser.add_argument("--role", choices=DInstallation.ROLES,
                        help="Required for first installation; retained thereafter")
    args = parser.parse_args(argv)
    if not args.check and os.geteuid() != 0:
        parser.error("Run deployment as root; --check and --help do not require root")
    try:
        app = BMCA(Path(__file__).resolve().parents[1])
        plan = app.deploy(args.action, role=args.role, check=args.check)
    except subprocess.CalledProcessError as error:
        parser.exit(1, f"Deployment failed: {error.stderr or error}\n")
    except (OSError, ValueError, TypeError, SyntaxError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Deployment failed: {error}\n")
    if args.check:
        print(f"{plan.action}: checks passed for {plan.destination}; no files changed.")
    elif args.action == DInstallation.UNINSTALL:
        print(f"Removed managed {DInstallation.PROJECT_NAME} files; unowned files and persistent data are retained.")
    else:
        print(f"{plan.action}: {DInstallation.PROJECT_NAME} {plan.version} deployed to {plan.destination}.")
    return 0
