"""Exercise partial operations and invalid external state in disposable paths."""

import json
from pathlib import Path
import unittest
from unittest.mock import patch

from test_installation import InstallationFixture, snapshot
from bmca.activity.DeployApplication import DeployApplication
from bmca.constants.DInstallation import DInstallation
from bmca.constants.DText import DText
from bmca.entity.ApplicationError import ApplicationError
from bmca.interface.InstallationFiles import InstallationFiles


class LifecycleFailureTests(InstallationFixture):
    def assert_refused_without_writes(self, action, key=None, **options):
        before = snapshot(self.workspace)
        for check in (True, False):
            with self.subTest(check=check):
                with self.assertRaises(ValueError) as failure:
                    self.deploy(action, check=check, **options)
                if key is not None:
                    self.assertEqual(failure.exception.key, key)
                self.assertEqual(snapshot(self.workspace), before)

    def test_both_roles_support_repeat_lifecycle_and_read_only_checks(self):
        for role in DInstallation.ROLES:
            with self.subTest(role=role):
                self.destination = self.workspace / role
                self.deploy("install", role=role)
                config = self.destination / "conf/local.json"
                config.write_text('{"retain":true}\n')
                data = self.destination / "data/retained.txt"
                data.parent.mkdir()
                data.write_text("retained data\n")
                for action in DInstallation.ACTIONS:
                    before = snapshot(self.workspace)
                    self.deploy(action, check=True)
                    self.assertEqual(snapshot(self.workspace), before)
                self.deploy("install")
                self.deploy("upgrade")
                self.assertEqual(config.read_text(), '{"retain":true}\n')
                self.assertEqual(json.loads((self.destination / DInstallation.ROLE_FILE).read_text()), {"role": role})
                self.deploy("uninstall")
                self.deploy("uninstall")
                self.assertFalse((self.destination / DInstallation.VERSION_MARKER).exists())
                self.assertEqual(data.read_text(), "retained data\n")
                self.assertEqual(config.read_text(), '{"retain":true}\n')
                self.assert_refused_without_writes("upgrade", DText.ERROR_INSTALLATION_REQUIRED)
                self.deploy("install")
                self.assertEqual(data.read_text(), "retained data\n")

    def test_missing_source_file_is_rejected_before_upgrade_mutation(self):
        self.deploy("install", role="ca")
        (self.source / "scripts/install.sh").unlink()
        self.assert_refused_without_writes("upgrade", DText.ERROR_SOURCE_FILE_MISSING)

    def test_missing_host_interpreter_is_rejected_before_changes(self):
        with patch.object(DInstallation, "SYSTEM_PYTHON", str(self.workspace / "missing-python")):
            self.assert_refused_without_writes("install", DText.ERROR_PYTHON_MISSING, role="ca")

    def test_upgrade_without_installation_is_rejected(self):
        self.assert_refused_without_writes("upgrade", DText.ERROR_INSTALLATION_REQUIRED, role="target")

    def test_new_source_file_does_not_overwrite_unowned_content(self):
        self.deploy("install", role="ca")
        local = self.destination / "bmca/local.txt"
        local.write_text("user-owned\n")
        (self.source / "bmca/local.txt").write_text("source-owned\n")
        self.assert_refused_without_writes("upgrade", DText.ERROR_UNOWNED_COLLISION)
        self.assertEqual(local.read_text(), "user-owned\n")

    def test_obsolete_owned_files_are_removed_without_removing_user_files(self):
        (self.source / "bmca/obsolete.txt").write_text("obsolete\n")
        self.deploy("install", role="target")
        local = self.destination / "bmca/user.txt"
        local.write_text("retain\n")
        (self.source / "bmca/obsolete.txt").unlink()
        self.deploy("upgrade")
        self.assertFalse((self.destination / "bmca/obsolete.txt").exists())
        self.assertEqual(local.read_text(), "retain\n")

    def test_interrupted_upgrade_retains_marker_and_can_be_retried(self):
        self.deploy("install", role="ca")
        self.update_source_version()
        (self.source / "bmca/new-payload.txt").write_text("new payload\n")
        files = InstallationFiles(self.source, destination=self.destination)
        write = files.atomic_write

        def interrupt(path, content, mode=0o644):
            if path == self.destination / "bmca/new-payload.txt":
                raise OSError("fixture copy interruption")
            return write(path, content, mode)

        with patch.object(files, "atomic_write", side_effect=interrupt):
            with self.assertRaisesRegex(OSError, "fixture copy interruption"):
                DeployApplication(files).execute("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.1\n")
        ownership = json.loads((self.destination / DInstallation.MANIFEST).read_text())
        self.assertIn("bmca/new-payload.txt", ownership["files"])
        self.deploy("upgrade")
        self.assertEqual((self.destination / DInstallation.VERSION_MARKER).read_text(), "1.0.2\n")
        self.assertEqual((self.destination / "bmca/new-payload.txt").read_text(), "new payload\n")

    def test_failed_atomic_replacement_cleans_temporary_file(self):
        self.deploy("install", role="ca")
        target = self.destination / "bmca/__init__.py"
        before = target.read_bytes()
        files = InstallationFiles(self.source, destination=self.destination)
        with patch.object(Path, "replace", side_effect=OSError("fixture replacement failure")):
            with self.assertRaisesRegex(OSError, "fixture replacement failure"):
                files.atomic_write(target, b"must not replace original\n")
        self.assertEqual(target.read_bytes(), before)
        self.assertEqual(list(self.destination.rglob(".bmforge-install-*")), [])

    def test_managed_symlink_cannot_redirect_uninstall(self):
        self.deploy("install", role="ca")
        outside = self.workspace / "outside.txt"
        outside.write_text("keep outside\n")
        owned = self.destination / "scripts/install.sh"
        owned.unlink()
        owned.symlink_to(outside)
        self.assert_refused_without_writes("uninstall", DText.ERROR_PATH_SYMLINK)
        self.assertEqual(outside.read_text(), "keep outside\n")

    def test_manifest_cannot_claim_retained_role_record(self):
        self.deploy("install", role="ca")
        manifest = self.destination / DInstallation.MANIFEST
        ownership = json.loads(manifest.read_text())
        ownership["files"].append(DInstallation.ROLE_FILE)
        manifest.write_text(json.dumps(ownership))
        self.assert_refused_without_writes("uninstall", DText.ERROR_PATH_RESERVED)

    def test_manifest_requires_a_valid_recorded_role(self):
        self.deploy("install", role="ca")
        (self.destination / DInstallation.ROLE_FILE).unlink()
        (self.destination / DInstallation.MANIFEST).write_text(json.dumps(
            {"project": "BMCA", "files": [], "removed": True}))
        self.assert_refused_without_writes("uninstall", DText.ERROR_OWNERSHIP_ROLE)

    def test_malformed_and_traversal_manifests_are_rejected(self):
        self.deploy("install", role="ca")
        manifest = self.destination / DInstallation.MANIFEST
        valid = json.loads(manifest.read_text())
        for content in ("{bad json", json.dumps(dict(valid, project="Other")),
                        json.dumps(dict(valid, files=valid["files"] + ["../outside.txt"]))):
            with self.subTest(content=content):
                manifest.write_text(content)
                self.assert_refused_without_writes("uninstall")

    def test_source_symlink_and_overlapping_checkout_are_rejected(self):
        outside = self.workspace / "outside.txt"
        outside.write_text("keep\n")
        (self.source / "bmca/linked.txt").symlink_to(outside)
        self.assert_refused_without_writes("install", DText.ERROR_PATH_SYMLINK, role="ca")
        with self.assertRaises(ApplicationError) as failure:
            InstallationFiles(self.source, destination=self.source / "installed")
        self.assertEqual(failure.exception.key, DText.ERROR_CHECKOUT_OVERLAP)


if __name__ == "__main__":
    unittest.main(buffer=True)
