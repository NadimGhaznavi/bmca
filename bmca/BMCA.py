"""Compose the application activities with their concrete interfaces."""

from pathlib import Path

from bmca.activity.DeployApplication import DeployApplication
from bmca.entity.InstallationPlan import InstallationPlan
from bmca.interface.InstallationFiles import InstallationFiles


class BMCA:
    def __init__(self, checkout: Path, *, destination: Path | None = None) -> None:
        self.deployment = DeployApplication(InstallationFiles(checkout, destination=destination))

    def deploy(self, action: str, *, role: str | None = None,
               check: bool = False) -> InstallationPlan:
        return self.deployment.execute(action, role=role, check=check)
