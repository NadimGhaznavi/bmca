"""Verify optional dependency isolation with real local wheels, without network."""

import contextlib
import json
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch
import zipfile

from test_installation import InstallationFixture, snapshot
from bmca.activity.DeployApplication import DeployApplication
from bmca.constants.DInstallation import DInstallation
from bmca.constants.DText import DText
from bmca.entity.ApplicationError import ApplicationError
from bmca.interface.InstallationFiles import InstallationFiles


class DependencyTests(InstallationFixture):
    def quiet_run(self, command, **options):
        options.setdefault("capture_output", True)
        options.setdefault("text", True)
        return subprocess.run(command, **options)

    def execute(self, action, *, check=False, role=None):
        files = InstallationFiles(self.source, destination=self.destination, run=self.quiet_run)
        return DeployApplication(files).execute(action, role=role, check=check)

    def enable_dependencies(self):
        wheels = self.workspace / "wheels"
        wheels.mkdir()
        for version in ("1.0.0", "2.0.0"):
            distribution = f"bmca_fixture_dep-{version}.dist-info"
            contents = {
                "bmca_fixture_dep/__init__.py": f'VERSION = "{version}"\n',
                f"{distribution}/METADATA": f"Metadata-Version: 2.1\nName: bmca-fixture-dep\nVersion: {version}\n",
                f"{distribution}/WHEEL": "Wheel-Version: 1.0\nGenerator: bmca-tests\nRoot-Is-Purelib: true\nTag: py3-none-any\n",
            }
            with zipfile.ZipFile(wheels / f"bmca_fixture_dep-{version}-py3-none-any.whl", "w") as archive:
                for name, content in contents.items():
                    archive.writestr(name, content)
                archive.writestr(f"{distribution}/RECORD",
                                 "".join(f"{name},,\n" for name in (*contents, f"{distribution}/RECORD")))
        self.requirements = self.source / "requirements.txt"
        self.requirements.write_text("bmca-fixture-dep==1.0.0\n")
        # These settings affect only the disposable fixture. Production stays
        # stdlib-only. The copied constants agree with the fixture's settings.
        settings = self.source / "bmca/constants/DInstallation.py"
        settings.write_text(settings.read_text().replace(
            "REQUIREMENTS_FILE: Final[str | None] = None",
            "REQUIREMENTS_FILE: Final[str | None] = 'requirements.txt'"))
        stack = contextlib.ExitStack()
        self.addCleanup(stack.close)
        stack.enter_context(patch.object(DInstallation, "REQUIREMENTS_FILE", "requirements.txt"))
        stack.enter_context(patch.object(DInstallation, "RUNTIME_IMPORTS", (*DInstallation.RUNTIME_IMPORTS, "bmca_fixture_dep")))
        stack.enter_context(patch.dict(os.environ, {
            "PIP_FIND_LINKS": str(wheels), "PIP_NO_INDEX": "1",
            "PIP_DISABLE_PIP_VERSION_CHECK": "1", "PIP_CONFIG_FILE": os.devnull,
            "PIP_CACHE_DIR": str(self.workspace / "pip-cache"),
            "PYTHONPATH": str(self.source),
        }))

    def test_real_dependency_install_failed_upgrade_retry_and_checkout_independence(self):
        self.enable_dependencies()
        (self.source / "bmca/__init__.py").write_text("import bmca_fixture_dep\n")
        before = snapshot(self.workspace)
        self.execute("install", role="ca", check=True)
        self.assertEqual(snapshot(self.workspace), before)
        try:
            self.execute("install", role="ca")
        except subprocess.CalledProcessError as failure:
            self.fail(failure.stderr or str(failure))
        python = self.destination / ".venv/bin/python"
        created = (self.destination / ".venv/pyvenv.cfg").stat().st_mtime_ns
        self.update_source_version()
        self.requirements.write_text("bmca-fixture-dep==99.0.0\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.execute("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.1\n")
        self.requirements.write_text("bmca-fixture-dep==2.0.0\n")
        self.execute("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.2\n")
        self.assertEqual((self.destination / ".venv/pyvenv.cfg").stat().st_mtime_ns, created)
        self.source.rename(self.workspace / "hidden-source")
        environment = InstallationFiles.python_environment()
        result = subprocess.run([str(python), "-B", "-c",
                                 "import bmca_fixture_dep; from bmca.BMCA import BMCA; "
                                 "print(bmca_fixture_dep.__file__); print(bmca_fixture_dep.VERSION)"],
                                cwd=self.destination, env=environment, capture_output=True,
                                text=True, check=True, timeout=30)
        installed_path, version = result.stdout.strip().splitlines()
        self.assertTrue(Path(installed_path).is_relative_to(self.destination / ".venv"))
        self.assertEqual(version, "2.0.0")
        subprocess.run([str(python), "-B", "-m", "bmca", "--help"], cwd=self.destination,
                       env=environment, capture_output=True, check=True, timeout=30)
        self.source = self.workspace / "hidden-source"
        self.execute("uninstall")
        self.assertFalse((self.destination / ".venv").exists())

    def test_failed_first_dependency_install_remains_uninstallable(self):
        self.enable_dependencies()
        self.requirements.write_text("bmca-fixture-dep==99.0.0\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.execute("install", role="target")
        self.assertFalse((self.destination / DInstallation.VERSION_MARKER).exists())
        self.assertTrue(json.loads((self.destination / DInstallation.MANIFEST).read_text())["venv_owned"])
        self.assertTrue((self.destination / ".venv").is_dir())
        self.execute("uninstall")
        self.assertFalse((self.destination / ".venv").exists())

    def test_missing_venv_support_rejects_check_and_real_install_before_writes(self):
        self.enable_dependencies()

        def missing_support(command, **options):
            if command[-1] == "import venv, ensurepip":
                raise subprocess.CalledProcessError(1, command, stderr="fixture missing venv support")
            return self.quiet_run(command, **options)

        before = snapshot(self.workspace)
        for check in (True, False):
            files = InstallationFiles(self.source, destination=self.destination, run=missing_support)
            with self.assertRaises(subprocess.CalledProcessError):
                DeployApplication(files).execute("install", role="ca", check=check)
            self.assertEqual(snapshot(self.workspace), before)

    def test_unowned_venv_is_neither_adopted_nor_removed(self):
        self.deploy("install", role="ca")
        venv = self.destination / ".venv"
        venv.mkdir()
        important = venv / "unowned.txt"
        important.write_text("retain unowned environment\n")
        self.enable_dependencies()
        before = snapshot(self.workspace)
        for check in (True, False):
            with self.assertRaises(ApplicationError) as failure:
                self.execute("upgrade", check=check)
            self.assertEqual(failure.exception.key, DText.ERROR_VENV_UNOWNED)
            self.assertEqual(snapshot(self.workspace), before)
        self.execute("uninstall")
        self.assertEqual(important.read_text(), "retain unowned environment\n")

    def test_broken_owned_venv_is_rejected_before_upgrade_writes(self):
        self.deploy("install", role="ca")
        self.enable_dependencies()
        (self.destination / ".venv").mkdir()
        manifest = self.destination / DInstallation.MANIFEST
        ownership = json.loads(manifest.read_text())
        ownership["venv_owned"] = True
        manifest.write_text(json.dumps(ownership))
        before = snapshot(self.workspace)
        for check in (True, False):
            with self.assertRaises(ApplicationError) as failure:
                self.execute("upgrade", check=check)
            self.assertEqual(failure.exception.key, DText.ERROR_VENV_INVALID)
            self.assertEqual(snapshot(self.workspace), before)

    def test_non_runnable_owned_interpreter_is_rejected_by_preflight(self):
        self.deploy("install", role="ca")
        self.enable_dependencies()
        venv = self.destination / ".venv"
        (venv / "bin").mkdir(parents=True)
        binary = venv / "bin/python"
        binary.write_text("fixture: this is not an executable Python interpreter\n")
        binary.chmod(0o755)
        (venv / "pyvenv.cfg").write_text("home = /usr/bin\n")
        manifest = self.destination / DInstallation.MANIFEST
        ownership = json.loads(manifest.read_text())
        ownership["venv_owned"] = True
        manifest.write_text(json.dumps(ownership))
        before = snapshot(self.workspace)
        for check in (True, False):
            with self.subTest(check=check):
                with self.assertRaises(ApplicationError) as failure:
                    self.execute("upgrade", check=check)
                self.assertEqual(failure.exception.key, DText.ERROR_VENV_INVALID)
                self.assertEqual(snapshot(self.workspace), before)


if __name__ == "__main__":
    unittest.main(buffer=True)
