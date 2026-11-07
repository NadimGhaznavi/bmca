"""Acceptance checks for the greenfield identity/installation foundation."""

import ast
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("bmca_install", PROJECT / "scripts/install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


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
        for name in installer.COPY_FILES:
            shutil.copy2(PROJECT / name, self.source / name)
        # Legacy files in a source checkout must never become runtime payload.
        (self.source / "scripts/new-xmr-certs.sh").write_text("legacy XMR workflow\n")
        (self.source / "conf").mkdir()
        (self.source / "conf/settings.cfg").write_text('PROJECT_VERSION="legacy"\n')
        (self.source / "conf/target-settings.cfg").write_text('XMR_CERT_SOURCE_HOST="legacy"\n')

    def installation(self, role=None):
        return installer.Installation(self.source, destination=self.destination, role=role)

    def update_source_version(self):
        path = self.source / "bmca/constants/DBMCA.py"
        path.write_text(path.read_text().replace('VERSION: Final[str] = "1.0.1"',
                                                'VERSION: Final[str] = "1.0.2"'))

    def test_ca_identity_manifest_and_verified_version(self):
        self.installation("ca").apply("install")
        values = literals(self.destination / "bmca/constants/DBMCA.py")
        self.assertEqual(values["BASE_DIR"], "/opt/prod/bmca")
        self.assertEqual(values["CMDB_DATABASES"], (("BMCA", "bmca"),))
        self.assertEqual(values["CMDB_NETWORK"], ())
        self.assertEqual(values["CMDB_COMPONENTS"], (("BMCA configuration", "conf"), ("BMCA data", "data")))
        self.assertEqual((self.destination / installer.VERSION_MARKER).read_text(), "1.0.1\n")
        ownership = json.loads((self.destination / installer.MANIFEST).read_text())
        self.assertEqual(ownership["project"], "BMCA")
        self.assertEqual(ownership["role"], "ca")
        self.assertFalse(ownership["venv_owned"])
        self.assertIn("bmca/constants/DBMCA.py", ownership["files"])
        self.assertEqual(json.loads((self.destination / installer.ROLE_FILE).read_text()), {"role": "ca"})
        self.assertEqual((self.destination / "bmca/constants/DBMCA.py").stat().st_mode & 0o777, 0o644)
        self.assertFalse((self.destination / "scripts/new-xmr-certs.sh").exists())
        self.assertFalse((self.destination / "conf/settings.cfg").exists())
        self.assertFalse((self.destination / "conf/target-settings.cfg").exists())
        self.assertFalse((self.destination / ".venv").exists())

    def test_target_metadata_describes_only_target_resources(self):
        before = (self.source / "bmca/constants/DBMCA.py").read_bytes()
        self.installation("target").apply("install")
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
        with self.assertRaisesRegex(ValueError, "requires --role"):
            self.installation().apply("install", check=True)
        self.installation("ca").apply("install", check=True)
        self.assertEqual(snapshot(self.workspace), before)
        self.assertFalse(self.destination.exists())

    def test_upgrade_preserves_role_configuration_and_updates_version(self):
        self.installation("target").apply("install")
        configuration = self.destination / "conf/local.json"
        configuration.write_text('{"preserve": true}\n')
        role_before = (self.destination / installer.ROLE_FILE).read_bytes()
        self.update_source_version()
        before = snapshot(self.workspace)
        self.installation().apply("upgrade", check=True)
        self.assertEqual(snapshot(self.workspace), before)
        self.installation().apply("upgrade")
        self.assertEqual((self.destination / installer.VERSION_MARKER).read_text(), "1.0.2\n")
        self.assertEqual((self.destination / installer.ROLE_FILE).read_bytes(), role_before)
        self.assertEqual(configuration.read_text(), '{"preserve": true}\n')
        self.assertEqual(literals(self.destination / "bmca/constants/DBMCA.py")["CMDB_NETWORK"], ())

    def test_role_change_is_rejected_before_mutation(self):
        self.installation("target").apply("install")
        before = snapshot(self.workspace)
        with self.assertRaisesRegex(ValueError, "Cannot change"):
            self.installation("ca").apply("install")
        self.assertEqual(snapshot(self.workspace), before)

    def test_failed_deployed_import_does_not_advance_version(self):
        self.installation("ca").apply("install")
        self.update_source_version()
        (self.source / "bmca/__init__.py").write_text("raise RuntimeError('fixture activation failed')\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.installation().apply("upgrade")
        self.assertEqual((self.destination / installer.VERSION_MARKER).read_text(), "1.0.1\n")

    def test_failed_first_install_leaves_ownership_without_success_marker(self):
        (self.source / "bmca/__init__.py").write_text("raise RuntimeError('fixture import failed')\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.installation("ca").apply("install")
        self.assertTrue((self.destination / installer.MANIFEST).is_file())
        self.assertFalse((self.destination / installer.VERSION_MARKER).exists())
        self.installation().apply("uninstall")

    def test_uninstall_retains_configuration_and_data_and_is_repeatable(self):
        self.installation("ca").apply("install")
        (self.destination / "data").mkdir()
        data = self.destination / "data/retained.txt"
        data.write_text("retained application data\n")
        configuration = self.destination / "conf/local.json"
        configuration.write_text('{"preserve": true}\n')
        self.installation().apply("uninstall")
        self.assertFalse((self.destination / installer.VERSION_MARKER).exists())
        self.assertFalse((self.destination / "bmca/constants/DBMCA.py").exists())
        self.assertEqual(data.read_text(), "retained application data\n")
        self.assertEqual(configuration.read_text(), '{"preserve": true}\n')
        self.assertTrue(json.loads((self.destination / installer.MANIFEST).read_text())["removed"])
        self.installation().apply("uninstall")
        self.installation().apply("install")
        self.assertEqual(data.read_text(), "retained application data\n")

    def test_installed_package_works_without_checkout(self):
        self.installation("ca").apply("install")
        self.source.rename(self.workspace / "hidden-source")
        subprocess.run([sys.executable, "-B", "-c",
                        "from bmca.constants.DBMCA import DBMCA; assert DBMCA.VERSION == '1.0.1'"],
                       cwd=self.destination, env=installer.Installation.python_environment(), check=True)

    def test_unowned_and_symlinked_destinations_are_rejected(self):
        self.destination.mkdir()
        (self.destination / "unowned.txt").write_text("do not claim this\n")
        with self.assertRaisesRegex(ValueError, "without an ownership manifest"):
            self.installation("ca").apply("install", check=True)
        other = self.workspace / "other"
        other.mkdir()
        linked = self.workspace / "linked"
        linked.symlink_to(other, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symbolic link"):
            installer.Installation(self.source, destination=linked, role="ca")


if __name__ == "__main__":
    unittest.main(buffer=True)
