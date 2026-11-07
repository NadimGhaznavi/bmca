"""Installation identity, payload, and lifecycle identifiers."""

from typing import Final


class DInstallation:
    PROJECT_NAME: Final[str] = 'BMCA'
    DEPLOYMENT_READY: Final[bool] = True
    COPY_TREES: Final[tuple[str, ...]] = ('bmca',)
    COPY_FILES: Final[tuple[str, ...]] = (
        'scripts/install.py', 'scripts/install.sh', 'scripts/upgrade.sh',
        'scripts/uninstall.sh', 'scripts/check-cmdb.py',
    )
    REQUIREMENTS_FILE: Final[str | None] = None
    VENV_DIR: Final[str] = '.venv'
    SYSTEM_PYTHON: Final[str] = '/usr/bin/python3'
    RUNTIME_IMPORTS: Final[tuple[str, ...]] = (
        'bmca', 'bmca.BMCA', 'bmca.activity.DeployApplication',
        'bmca.interface.InstallationFiles', 'bmca.entity.InstallationPlan',
    )
    MANIFEST: Final[str] = '.installation-manifest.json'
    VERSION_MARKER: Final[str] = '.deployment-version'
    ROLE_FILE: Final[str] = 'conf/installation.json'
    INSTALL: Final[str] = "install"
    UPGRADE: Final[str] = "upgrade"
    UNINSTALL: Final[str] = "uninstall"
    ACTIONS: Final[tuple[str, ...]] = (INSTALL, UPGRADE, UNINSTALL)
    CA: Final[str] = "ca"
    TARGET: Final[str] = "target"
    ROLES: Final[tuple[str, ...]] = (CA, TARGET)
