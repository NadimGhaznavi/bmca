"""The data describing one requested deployment, without filesystem behavior."""

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class InstallationPlan:
    action: str
    role: str | None
    previous_files: tuple[str, ...] | None
    files: tuple[str, ...]
    destination: Path
    version: str
