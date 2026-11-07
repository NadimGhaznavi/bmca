"""Run BMCA's command-line boundary."""

import sys

sys.dont_write_bytecode = True

from bmca.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
