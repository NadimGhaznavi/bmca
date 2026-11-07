"""Acceptance checks for the greenfield identity/installation foundation."""

import ast
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))

from bmca.BMCA import BMCA
from bmca.constants.DInstallation import DInstallation
from bmca.constants.DText import DText
from bmca.entity.ApplicationError import ApplicationError
from bmca.entity.InstallationPlan import InstallationPlan
from bmca.interface.InstallationFiles import InstallationFiles


def literals(path):
    result = {}
    for node in ast.walk(ast.parse(path.read_text())):
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            result[node.target.id] = ast.literal_eval(node.value)
        elif isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name):
            result[node.targets[0].id] = ast.literal_eval(node.value)
    return result


def snapshot(root):
    return {path.relative_to(root).as_posix(): (path.stat().st_mode, path.stat().st_mtime_ns,
                                             path.read_bytes() if path.is_file() else None)
            for path in root.rglob("*")}


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bmca-install-")
        self.addCleanup(self.temporary.cleanup)
        self.workspace = Path(self.temporary.name)
        self.source = self.workspace / "source"
        self.destination = self.workspace / "installed"
        shutil.copytree(PROJECT / "bmca", self.source / "bmca",
                        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        (self.source / "scripts").mkdir()
        for name in DInstallation.COPY_FILES:
            shutil.copy2(PROJECT / name, self.source / name)
        # Legacy files in a source checkout must never become runtime payload.
        (self.source / "scripts/new-xmr-certs.sh").write_text("legacy XMR workflow\n")
        (self.source / "conf").mkdir()
        (self.source / "conf/settings.cfg").write_text('PROJECT_VERSION="legacy"\n')
        (self.source / "conf/target-settings.cfg").write_text('XMR_CERT_SOURCE_HOST="legacy"\n')

    def deploy(self, action, *, role=None, check=False):
        return BMCA(self.source, destination=self.destination).deploy(action, role=role, check=check)

    def update_source_version(self):
        path = self.source / "bmca/constants/DBMCA.py"
        path.write_text(path.read_text().replace('VERSION: Final[str] = "1.0.1"',
                                                'VERSION: Final[str] = "1.0.2"'))

    def test_ca_identity_manifest_and_verified_version(self):
        self.deploy("install", role="ca")
        values = literals(self.destination / "bmca/constants/DBMCA.py")
        self.assertEqual(values["BASE_DIR"], "/opt/prod/bmca")
        self.assertEqual(values["CMDB_DATABASES"], (("BMCA", "bmca"),))
        self.assertEqual(values["CMDB_NETWORK"], ())
        self.assertEqual(values["CMDB_COMPONENTS"], (("BMCA configuration", "conf"), ("BMCA data", "data")))
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.1\n")
        ownership = json.loads((self.destination / DInstallation.MANIFEST).read_text())
        self.assertEqual(ownership["project"], "BMCA")
        self.assertEqual(ownership["role"], "ca")
        self.assertFalse(ownership["venv_owned"])
        self.assertIn("bmca/constants/DBMCA.py", ownership["files"])
        self.assertEqual(json.loads((self.destination / DInstallation.ROLE_FILE).read_text()), {"role": "ca"})
        self.assertEqual((self.destination / "bmca/constants/DBMCA.py").stat().st_mode & 0o777, 0o644)
        self.assertFalse((self.destination / "scripts/new-xmr-certs.sh").exists())
        self.assertFalse((self.destination / "conf/settings.cfg").exists())
        self.assertFalse((self.destination / "conf/target-settings.cfg").exists())
        self.assertFalse((self.destination / ".venv").exists())

    def test_target_metadata_describes_only_target_resources(self):
        before = (self.source / "bmca/constants/DBMCA.py").read_bytes()
        self.deploy("install", role="target")
        values = literals(self.destination / "bmca/constants/DBMCA.py")
        for field in ("CMDB_COMPONENTS", "CMDB_DATABASES", "CMDB_NETWORK"):
            self.assertEqual(values[field], ())
        self.assertEqual(values["CMDB_SUBTYPE"], "Certificate Target")
        self.assertEqual(values["VERSION"], "1.0.1")
        self.assertEqual(values["CMDB_CODENAME"], "Thulium")
        self.assertEqual((self.source / "bmca/constants/DBMCA.py").read_bytes(), before)
        subprocess.run([sys.executable, "-B", str(self.destination / "scripts/check-cmdb.py"),
                        "--name", "BMCA", "--root", str(self.destination),
                        "bmca/constants/DBMCA.py"], check=True, capture_output=True)

    def test_install_check_has_no_writes_and_requires_explicit_role(self):
        before = snapshot(self.workspace)
        with self.assertRaises(ApplicationError) as failure:
            self.deploy("install", check=True)
        self.assertEqual(failure.exception.key, DText.ERROR_ROLE_REQUIRED)
        plan = self.deploy("install", role="ca", check=True)
        self.assertIsInstance(plan, InstallationPlan)
        self.assertEqual(plan.role, "ca")
        self.assertEqual(plan.destination, self.destination)
        self.assertEqual(plan.version, "1.0.1")
        self.assertEqual(snapshot(self.workspace), before)
        self.assertFalse(self.destination.exists())

    def test_upgrade_preserves_role_configuration_and_updates_version(self):
        self.deploy("install", role="target")
        configuration = self.destination / "conf/local.json"
        configuration.write_text('{"preserve": true}\n')
        role_before = (self.destination / DInstallation.ROLE_FILE).read_bytes()
        self.update_source_version()
        before = snapshot(self.workspace)
        self.deploy("upgrade", check=True)
        self.assertEqual(snapshot(self.workspace), before)
        self.deploy("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.2\n")
        self.assertEqual((self.destination / DInstallation.ROLE_FILE).read_bytes(), role_before)
        self.assertEqual(configuration.read_text(), '{"preserve": true}\n')
        self.assertEqual(literals(self.destination / "bmca/constants/DBMCA.py")["CMDB_NETWORK"], ())

    def test_role_change_is_rejected_before_mutation(self):
        self.deploy("install", role="target")
        before = snapshot(self.workspace)
        with self.assertRaises(ApplicationError) as failure:
            self.deploy("install", role="ca")
        self.assertEqual(failure.exception.key, DText.ERROR_ROLE_CHANGE)
        self.assertEqual(snapshot(self.workspace), before)

    def test_failed_deployed_import_does_not_advance_version(self):
        self.deploy("install", role="ca")
        self.update_source_version()
        (self.source / "bmca/__init__.py").write_text("raise RuntimeError('fixture activation failed')\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.deploy("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.1\n")

    def test_failed_first_install_leaves_ownership_without_success_marker(self):
        (self.source / "bmca/__init__.py").write_text("raise RuntimeError('fixture import failed')\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.deploy("install", role="ca")
        self.assertTrue((self.destination / DInstallation.MANIFEST).is_file())
        self.assertFalse((self.destination / DInstallation.VERSION_MARKER).exists())
        self.deploy("uninstall")

    def test_invalid_installed_catalogue_does_not_advance_version(self):
        self.deploy("install", role="ca")
        self.update_source_version()
        catalogue = self.source / "bmca/locales/en.json"
        values = json.loads(catalogue.read_text(encoding="utf-8"))
        values.pop(DText.DEPLOYMENT_COMPLETED)
        catalogue.write_text(json.dumps(values), encoding="utf-8")
        with self.assertRaises(subprocess.CalledProcessError):
            self.deploy("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.1\n")

    def test_uninstall_retains_configuration_and_data_and_is_repeatable(self):
        self.deploy("install", role="ca")
        (self.destination / "data").mkdir()
        data = self.destination / "data/retained.txt"
        data.write_text("retained application data\n")
        configuration = self.destination / "conf/local.json"
        configuration.write_text('{"preserve": true}\n')
        self.deploy("uninstall")
        self.assertFalse((self.destination / DInstallation.VERSION_MARKER).exists())
        self.assertFalse((self.destination / "bmca/constants/DBMCA.py").exists())
        self.assertEqual(data.read_text(), "retained application data\n")
        self.assertEqual(configuration.read_text(), '{"preserve": true}\n')
        self.assertTrue(json.loads((self.destination / DInstallation.MANIFEST).read_text())["removed"])
        self.deploy("uninstall")
        self.deploy("install")
        self.assertEqual(data.read_text(), "retained application data\n")

    def test_installed_package_works_without_checkout(self):
        self.deploy("install", role="ca")
        self.source.rename(self.workspace / "hidden-source")
        subprocess.run([sys.executable, "-B", "-c",
                        "from bmca.constants.DBMCA import DBMCA; assert DBMCA.VERSION == '1.0.1'"],
                       cwd=self.destination, env=InstallationFiles.python_environment(), check=True)
        for arguments in (("-m", "bmca"), (str(self.destination / "scripts/install.py"),)):
            result = subprocess.run([sys.executable, "-B", *arguments, "--help"],
                                    cwd=self.destination,
                                    env=InstallationFiles.python_environment(),
                                    capture_output=True, text=True, check=True)
            self.assertIn("install,upgrade,uninstall", result.stdout)

    def test_cli_rejects_invalid_actions_and_roles_without_writes(self):
        before = snapshot(self.workspace)
        for arguments in (("unknown",), ("install", "--role", "unknown", "--check")):
            result = subprocess.run([sys.executable, "-B", "-m", "bmca", *arguments],
                                    cwd=self.source, env=InstallationFiles.python_environment(),
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn("invalid choice", result.stderr)
        self.assertEqual(snapshot(self.workspace), before)

    def test_application_rejects_invalid_action_without_writes(self):
        before = snapshot(self.workspace)
        with self.assertRaises(ApplicationError) as failure:
            self.deploy("unknown", role="ca", check=True)
        self.assertEqual(failure.exception.key, DText.ERROR_UNKNOWN_ACTION)
        self.assertEqual(failure.exception.parameters, {"action": "unknown"})
        self.assertEqual(snapshot(self.workspace), before)

    def test_unowned_and_symlinked_destinations_are_rejected(self):
        self.destination.mkdir()
        (self.destination / "unowned.txt").write_text("do not claim this\n")
        with self.assertRaises(ApplicationError) as failure:
            self.deploy("install", role="ca", check=True)
        self.assertEqual(failure.exception.key, DText.ERROR_OWNERSHIP_MISSING)
        other = self.workspace / "other"
        other.mkdir()
        linked = self.workspace / "linked"
        linked.symlink_to(other, target_is_directory=True)
        with self.assertRaises(ApplicationError) as failure:
            BMCA(self.source, destination=linked).deploy("install", role="ca")
        self.assertEqual(failure.exception.key, DText.ERROR_PATH_SYMLINK)


if __name__ == "__main__":
    unittest.main(buffer=True)
