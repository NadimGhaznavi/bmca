"""Coordinate installation, upgrade, and removal through an injected interface."""

from bmca.constants.DInstallation import DInstallation
from bmca.entity.InstallationPlan import InstallationPlan
from bmca.interface.InstallationFiles import InstallationFiles


class DeployApplication:
    def __init__(self, files: InstallationFiles) -> None:
        self.files = files

    def plan(self, action: str, role: str | None = None) -> InstallationPlan:
        if action not in DInstallation.ACTIONS:
            raise ValueError(f"Unknown deployment action: {action}")
        if not DInstallation.DEPLOYMENT_READY:
            raise ValueError("Deployment is not configured: implement provisioning, lifecycle, and health checks before enabling it")
        previous = self.files.installed_files()
        stored_role = self.files.installed_role()
        if stored_role and role and stored_role != role:
            raise ValueError("Cannot change the installed role")
        selected_role = stored_role or role
        if selected_role is not None and selected_role not in DInstallation.ROLES:
            raise ValueError("Installation role must be ca or target")
        if action != DInstallation.UNINSTALL and selected_role is None:
            raise ValueError("First installation requires --role ca or --role target")
        if action == DInstallation.UPGRADE and not previous:
            raise ValueError("No installation found; run install.sh first")
        current = [] if action == DInstallation.UNINSTALL else self.files.source_files()
        self.files.preflight_payload(previous, current)
        self.files.preflight_python(action)
        return InstallationPlan(action=action, role=selected_role,
                                previous_files=None if previous is None else tuple(previous),
                                files=tuple(current), destination=self.files.destination,
                                version=self.files.metadata["VERSION"])

    def execute(self, action: str, *, role: str | None = None,
                check: bool = False) -> InstallationPlan:
        plan = self.plan(action, role)
        if check:
            return plan
        if action == DInstallation.UNINSTALL:
            self.files.remove_installation(plan)
            return plan
        self.files.begin_installation(plan)
        self.files.copy_payload(plan.files)
        self.files.prepare_python()
        self.files.remove_files(sorted(set(plan.previous_files or ()) - set(plan.files)))
        self.files.install_metadata(plan.role)
        self.files.verify_payload(plan.files, plan.role)
        self.files.complete_installation(plan)
        return plan
