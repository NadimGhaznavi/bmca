"""Exercise the release script only in disposable repositories/local remotes."""

import ast
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import unittest


PROJECT = Path(__file__).resolve().parents[1]
CONSTANTS = "bmca/constants/DBMCA.py"


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bmca-release-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.repo = self.directory / "source"
        self.repo.mkdir()
        self.remote = self.directory / "origin.git"
        self.environment = dict(os.environ, GIT_CONFIG_NOSYSTEM="1",
                                GIT_CONFIG_GLOBAL=os.devnull, GIT_ALLOW_PROTOCOL="file",
                                GIT_TERMINAL_PROMPT="0", GIT_EDITOR="true",
                                TZ="America/Toronto")
        self.command("git", "init", "--bare", "--initial-branch=main", str(self.remote))
        self.git("init", "--initial-branch=main")
        self.git("config", "user.name", "BMCA Release Fixture")
        self.git("config", "user.email", "release-fixture@example.invalid")
        for name in ("scripts/new-release.sh", "scripts/check-cmdb.py", "scripts/install.sh",
                     "scripts/upgrade.sh", "scripts/uninstall.sh", CONSTANTS):
            destination = self.repo / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(PROJECT / name, destination)
        self.write("CHANGELOG.md", "# Changelog\n\n## [Unreleased]\n\n## [1.0.1] - previous\n\n- Published history.\n")
        self.write("README.md", "Initial fixture content.\n")
        self.commit("Initial fixture")
        self.git("remote", "add", "origin", str(self.remote))
        self.git("push", "origin", "main")
        self.git("switch", "-c", "dev")
        self.git("push", "origin", "dev")
        self.git("switch", "-c", "feat/maint-1.0.2")

    def command(self, *arguments, check=True):
        return subprocess.run(arguments, cwd=self.repo, env=self.environment,
                              text=True, capture_output=True, check=check, timeout=30)

    def git(self, *arguments, check=True):
        return self.command("git", *arguments, check=check).stdout.strip()

    def write(self, name, text):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def commit(self, message):
        self.git("add", "--all")
        self.git("commit", "-m", message)

    def feature(self):
        self.write("README.md", "A real file change.\n")
        path = self.repo / "CHANGELOG.md"
        path.write_text(path.read_text().replace("## [Unreleased]\n", "## [Unreleased]\n\n### Summary\n\nA real improvement.\n"))
        self.commit("Implement fixture feature")

    def state(self):
        return (self.git("symbolic-ref", "HEAD"),
                self.git("for-each-ref", "--format=%(refname) %(objectname)"),
                self.git("status", "--porcelain"),
                self.git("ls-remote", "origin"),
                (self.repo / CONSTANTS).read_bytes(),
                (self.repo / "CHANGELOG.md").read_bytes())

    def release(self, version="1.0.2", message="Fixture release", *, answer="y", terminal=True):
        command = ["bash", "scripts/new-release.sh", version, message]
        if not terminal:
            return subprocess.run(command, cwd=self.repo, env=self.environment,
                                  text=True, input="y\n", capture_output=True, timeout=30)
        master, slave = pty.openpty()
        try:
            process = subprocess.Popen(command, cwd=self.repo, env=self.environment,
                                       stdin=slave, stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            os.close(slave)
            slave = None
            os.write(master, (answer + "\n").encode())
            try:
                output, _ = process.communicate(timeout=30)
            except subprocess.TimeoutExpired:
                process.kill()
                output, _ = process.communicate()
                self.fail("Disposable release timed out:\n" + output)
            return subprocess.CompletedProcess(command, process.returncode, output)
        finally:
            os.close(master)
            if slave is not None:
                os.close(slave)

    def assert_rejected_unchanged(self, reason, **options):
        before = self.state()
        result = self.release(**options)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        output = (result.stdout or "") + (result.stderr or "")
        self.assertIn(reason, output)
        self.assertEqual(self.state(), before)
        return result

    def test_identical_tree_is_rejected_before_fetch_or_metadata_changes(self):
        result = self.assert_rejected_unchanged("No files have changed")
        self.assertNotIn("Fetch refs", result.stdout)
        self.assertNotIn("Create and push", result.stdout)

    def test_empty_commits_do_not_qualify(self):
        self.git("commit", "--allow-empty", "-m", "An empty commit")
        self.assert_rejected_unchanged("No files have changed")

    def test_fully_reverted_file_changes_do_not_qualify(self):
        self.write("README.md", "Temporary change.\n")
        self.commit("Temporary change")
        self.write("README.md", "Initial fixture content.\n")
        self.commit("Restore original tree")
        self.assert_rejected_unchanged("No files have changed")

    def test_real_release_publishes_canonical_metadata_and_matching_refs(self):
        self.feature()
        before = (self.repo / "CHANGELOG.md").read_text()
        result = self.release(message='A release with "quotes" — Україна')
        self.assertEqual(result.returncode, 0, result.stdout)
        assignments = {}
        for node in ast.walk(ast.parse((self.repo / CONSTANTS).read_text())):
            if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
                assignments[node.target.id] = ast.literal_eval(node.value)
        self.assertEqual(assignments["VERSION"], "1.0.2")
        self.assertEqual(assignments["CMDB_CODENAME"], 'A release with "quotes" — Україна')
        self.assertEqual(self.git("cat-file", "-t", "v1.0.2"), "tag")
        tip = self.git("rev-parse", "main")
        for reference in ("dev", "v1.0.2^{commit}", "origin/main", "origin/dev"):
            self.assertEqual(self.git("rev-parse", reference), tip)
        self.assertEqual(self.git("branch", "--show-current"), "feat/maint-1.0.3")
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertNotIn("refs/heads/feat/maint-1.0.3", self.git("ls-remote", "origin"))
        changelog = (self.repo / "CHANGELOG.md").read_text()
        self.assertEqual(changelog.count("## [Unreleased]"), 1)
        self.assertIn("## [1.0.2] - ", changelog)
        self.assertTrue(changelog.endswith(before.split("## [Unreleased]", 1)[1]))
        self.assert_rejected_unchanged("No files have changed", version="1.0.3")

    def assert_changed_file_reaches_confirmation(self):
        self.commit("Change a fixture file")
        before = self.state()
        result = self.release(answer="n")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("Release cancelled", result.stdout)
        self.assertEqual(self.state(), before)

    def test_added_file_qualifies(self):
        self.write("new-file.txt", "A new file.\n")
        self.assert_changed_file_reaches_confirmation()

    def test_deleted_file_qualifies(self):
        (self.repo / "README.md").unlink()
        self.assert_changed_file_reaches_confirmation()

    def test_file_mode_change_qualifies(self):
        (self.repo / "scripts/check-cmdb.py").chmod(0o644)
        self.assert_changed_file_reaches_confirmation()

    def test_package_version_is_synchronized_and_drift_is_rejected(self):
        self.write("pyproject.toml", '[project]\nname = "bmca"\nversion = "1.0.1"\n')
        self.commit("Add package metadata")
        result = self.release()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('version = "1.0.2"', (self.repo / "pyproject.toml").read_text())
        self.write("pyproject.toml", '[project]\nname = "bmca"\nversion = "9.9.9"\n')
        self.commit("Introduce fixture version drift")
        self.assert_rejected_unchanged("differs from application VERSION", version="1.0.3")

    def test_dirty_working_tree_is_rejected(self):
        self.feature()
        self.write("README.md", "Uncommitted fixture change.\n")
        self.assert_rejected_unchanged("Commit or stash")

    def test_duplicate_changelog_heading_is_rejected(self):
        self.feature()
        path = self.repo / "CHANGELOG.md"
        path.write_text(path.read_text() + "\n## [Unreleased]\n")
        self.commit("Introduce fixture duplicate heading")
        self.assert_rejected_unchanged("exactly one ## [Unreleased]")

    def test_noninteractive_invocation_cannot_publish(self):
        self.feature()
        self.assert_rejected_unchanged("Confirmation requires an interactive terminal", terminal=False)


if __name__ == "__main__":
    unittest.main(buffer=True)
