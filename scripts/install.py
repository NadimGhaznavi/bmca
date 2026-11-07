#!/usr/bin/env python3
"""Invoke BMCA's deployment CLI from a separate source checkout."""

from pathlib import Path
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from bmca.cli import main


if __name__ == "__main__":
    raise SystemExit(main())
