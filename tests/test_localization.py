"""English CLI coverage and synthetic future-language acceptance fixtures."""

import contextlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT))

from bmca import cli
from bmca.constants.DText import DText
from bmca.entity.ApplicationError import ApplicationError
from bmca.interface.Localizer import Localizer
from bmca.interface.InstallationFiles import InstallationFiles


class LocalizationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bmca-locales-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.english = json.loads((PROJECT / "bmca/locales/en.json").read_text(encoding="utf-8"))
        self.catalogue("en", self.english)

    def catalogue(self, tag, values):
        (self.directory / f"{tag}.json").write_text(
            json.dumps(values, ensure_ascii=False), encoding="utf-8")

    def test_shipped_catalogue_is_english_only_and_matches_keys(self):
        self.assertEqual(set(self.english), {key.value for key in DText})
        self.assertEqual({path.stem for path in (PROJECT / "bmca/locales").glob("*.json")}, {"en"})
        self.assertEqual((PROJECT / "bmca/interface/Localizer.py").read_bytes(),
                         (PROJECT / ".agents/skills/bmforge-localization/assets/Localizer.py").read_bytes())

    def test_installer_rejects_unsupported_python_before_changes(self):
        from bmca.activity.DeployApplication import DeployApplication
        destination = self.directory / "not-created"
        files = InstallationFiles(PROJECT, destination=destination)
        with patch.object(files, "run", return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaises(ApplicationError) as failure:
                DeployApplication(files).execute("install", role="ca", check=True)
        self.assertEqual(failure.exception.key, DText.ERROR_PYTHON_VERSION)
        self.assertFalse(destination.exists())

    def test_blog_locale_identifiers_utf8_and_placeholder_reordering(self):
        # Synthetic test text only: no production translation is published here.
        self.catalogue("zh-CN", {DText.DEPLOYMENT_COMPLETED: "测试 {destination} {version} {project} {action}"})
        self.catalogue("uk", {DText.DEPLOYMENT_COMPLETED: "Тест {action} {project} {destination} {version}"})
        localizer = Localizer(self.directory)
        values = {"action": "install", "project": "BMCA", "version": "1.0.1", "destination": "/tmp/路径"}
        self.assertEqual(localizer.select(explicit="zh_cn"), "zh-CN")
        self.assertEqual(localizer.select(explicit="uk-UA"), "uk")
        self.assertEqual(localizer.text(DText.DEPLOYMENT_COMPLETED, locale="zh-CN", **values),
                         "测试 /tmp/路径 1.0.1 BMCA install")
        self.assertEqual(localizer.text(DText.DEPLOYMENT_COMPLETED, locale="uk", **values),
                         "Тест install BMCA /tmp/路径 1.0.1")
        self.assertEqual(localizer.select(explicit="zh-TW"), "en")
        self.assertEqual(localizer.select(explicit="zh-Hans"), "en")
        self.assertEqual(localizer.select(explicit="ua"), "en")
        self.assertEqual(localizer.text(DText.ERROR_ROLE_CHANGE, locale="zh-CN"), "Cannot change the installed role")

    def test_explicit_and_environment_precedence(self):
        self.catalogue("zh-CN", {})
        self.catalogue("uk", {})
        localizer = Localizer(self.directory)
        environment = {"LC_ALL": "zh_CN.UTF-8", "LC_MESSAGES": "uk_UA.UTF-8", "LANG": "en_US.UTF-8"}
        self.assertEqual(cli.select_locale(localizer, "uk", environment), "uk")
        self.assertEqual(cli.select_locale(localizer, None, environment), "zh-CN")
        self.assertEqual(cli.select_locale(localizer, "unsupported", environment), "en")
        self.assertEqual(cli.select_locale(localizer, None, {"LC_MESSAGES": "uk_UA.UTF-8"}), "uk")
        self.assertEqual(cli.select_locale(localizer, None, {"LANG": "uk_UA.UTF-8@modifier"}), "uk")
        self.assertEqual(cli.select_locale(localizer, None, {"LC_ALL": "C.UTF-8", "LANG": "uk_UA.UTF-8"}), "en")
        self.assertEqual(cli.select_locale(localizer, None, {}), "en")

    def test_missing_source_keys_unknown_keys_and_bad_placeholders_fail(self):
        localizer = Localizer(self.directory)
        with self.assertRaises(KeyError):
            localizer.text("missing.key")
        for values in ({"unknown.key": "fixture"},
                       {DText.DEPLOYMENT_COMPLETED: "{wrong}"},
                       {DText.DEPLOYMENT_COMPLETED: "{project.attr}"}):
            with self.subTest(values=values):
                self.catalogue("uk", values)
                with self.assertRaises(ValueError):
                    Localizer(self.directory)

    def test_cli_help_and_errors_use_per_call_locale(self):
        # Prefix existing English templates to prove the whole current CLI
        # surface is routed through the catalogue, without claiming translation.
        self.catalogue("uk", {key: "Тест: " + value for key, value in self.english.items()})
        localizer = Localizer(self.directory)
        before = dict(os.environ)
        with patch.object(cli, "Localizer", return_value=localizer):
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                self.assertEqual(cli.main(["--help", "--lang", "uk"]), 0)
            self.assertIn("Тест: ", output.getvalue())
            for arguments in (["unknown", "--lang", "uk"], ["--lang", "uk"],
                              ["install", "--role", "--lang", "uk"],
                              ["install", "--check=value", "--lang", "uk"],
                              ["install", "--unknown", "--lang", "uk"]):
                with self.subTest(arguments=arguments):
                    errors = io.StringIO()
                    with contextlib.redirect_stderr(errors), self.assertRaises(SystemExit) as failure:
                        cli.main(arguments)
                    self.assertEqual(failure.exception.code, 2)
                    self.assertIn("Тест: ", errors.getvalue())
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                cli.main(["--help", "--lang", "en"])
            self.assertNotIn("Тест: ", output.getvalue())
        self.assertEqual(dict(os.environ), before)

    def test_cli_renders_structured_application_failure(self):
        self.catalogue("zh-CN", {DText.ERROR_ROLE_CHANGE: "测试", DText.DEPLOYMENT_FAILED: "测试 {detail}\n"})
        errors = io.StringIO()
        with patch.object(cli, "Localizer", return_value=Localizer(self.directory)), \
                patch.object(cli, "BMCA") as application, contextlib.redirect_stderr(errors):
            application.return_value.deploy.side_effect = ApplicationError(DText.ERROR_ROLE_CHANGE)
            result = cli.main(["install", "--check", "--role", "ca", "--lang", "zh-CN"])
        self.assertEqual(result, 1)
        self.assertEqual(errors.getvalue(), "测试 测试\n")

    def test_external_failures_return_failure_without_success_output(self):
        failures = (OSError("fixture filesystem failure"),
                    subprocess.CalledProcessError(1, ["fixture"], stderr="fixture subprocess failure"),
                    subprocess.TimeoutExpired(["fixture"], 1))
        for failure in failures:
            with self.subTest(failure=failure):
                output, errors = io.StringIO(), io.StringIO()
                with patch.object(cli, "BMCA") as application, \
                        contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                    application.return_value.deploy.side_effect = failure
                    result = cli.main(["install", "--check", "--role", "ca", "--lang", "en"])
                self.assertEqual(result, 1)
                self.assertEqual(output.getvalue(), "")
                self.assertIn("Deployment failed:", errors.getvalue())

    def test_privilege_failure_happens_before_application_construction(self):
        errors = io.StringIO()
        with patch.object(cli.os, "geteuid", return_value=1000), \
                patch.object(cli, "BMCA") as application, contextlib.redirect_stderr(errors):
            with self.assertRaises(SystemExit) as failure:
                cli.main(["install", "--role", "ca", "--lang", "en"])
        self.assertEqual(failure.exception.code, 2)
        self.assertIn("Run deployment as root", errors.getvalue())
        application.assert_not_called()

    def test_browser_negotiation_remains_ready_for_future_front_end(self):
        self.catalogue("zh-CN", {})
        self.catalogue("uk", {})
        localizer = Localizer(self.directory)
        self.assertEqual(localizer.select(accept_language="uk-UA;q=0.9,zh-CN;q=0.8"), "uk")
        self.assertEqual(localizer.select(explicit="zh-CN", accept_language="uk"), "zh-CN")
        self.assertEqual(localizer.select(accept_language="zh-TW"), "en")

    def test_installed_cli_can_load_unicode_catalogues_without_checkout(self):
        source = self.directory / "source"
        destination = self.directory / "installed"
        shutil.copytree(PROJECT / "bmca", source / "bmca", ignore=shutil.ignore_patterns("__pycache__"))
        (source / "scripts").mkdir()
        from bmca.BMCA import BMCA
        from bmca.constants.DInstallation import DInstallation
        for name in DInstallation.COPY_FILES:
            shutil.copy2(PROJECT / name, source / name)
        values = {key: "测试: " + value for key, value in self.english.items()}
        (source / "bmca/locales/zh-CN.json").write_text(json.dumps(values, ensure_ascii=False), encoding="utf-8")
        BMCA(source, destination=destination).deploy("install", role="ca")
        source.rename(self.directory / "hidden-source")
        result = subprocess.run([sys.executable, "-B", "-m", "bmca", "--help", "--lang", "zh-CN"],
                                cwd=destination, capture_output=True, check=True)
        self.assertIn("测试: ", result.stdout.decode("utf-8"))


if __name__ == "__main__":
    unittest.main(buffer=True)
