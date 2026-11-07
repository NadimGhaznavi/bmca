"""Filesystem, metadata, and interpreter operations for BMCA deployment.

File ownership and atomic-write mechanics derive from the pinned BMForge
installation template. Use-case ordering belongs to DeployApplication.
"""

import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile

from bmca.constants.DInstallation import DInstallation
from bmca.constants.DText import DText
from bmca.entity.ApplicationError import ApplicationError
from bmca.entity.InstallationPlan import InstallationPlan


BMFORGE_COMPONENT = {"id": "bmforge.installation", "spec_version": "0.1.3"}


def relative_path(name: str) -> str:
    if not isinstance(name, str):
        raise ApplicationError(DText.ERROR_PATH_TYPE)
    path = PurePosixPath(name)
    if not name or path.is_absolute() or '..' in path.parts or path.as_posix() != name or name == '.':
        raise ApplicationError(DText.ERROR_PATH_INVALID, name=name)
    if name in (DInstallation.MANIFEST, DInstallation.VERSION_MARKER):
        raise ApplicationError(DText.ERROR_PATH_RESERVED, name=name)
    return name


def reject_symlinks(path: Path) -> None:
    for candidate in (path, *path.parents):
        if candidate.is_symlink():
            raise ApplicationError(DText.ERROR_PATH_SYMLINK, candidate=candidate)


class InstallationFiles:
    """Own deployment I/O; receive the chosen action and role from the activity."""

    def __init__(self, checkout: Path, *, destination: Path | None = None,
                 run=None) -> None:
        self.checkout = checkout.resolve()
        self.run = run or subprocess.run
        self.version_file = f"{DInstallation.PROJECT_NAME.lower()}/constants/D{DInstallation.PROJECT_NAME}.py"
        spec = importlib.util.spec_from_file_location('cmdb_checker', self.checkout / 'scripts/check-cmdb.py')
        checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(checker)
        self.metadata = checker.validate((self.checkout / self.version_file).read_text(),
                                         DInstallation.PROJECT_NAME, self.version_file)
        self.destination = Path(destination if destination is not None else self.metadata['BASE_DIR']).absolute()
        reject_symlinks(self.destination)
        if (self.checkout.is_relative_to(self.destination)
                or self.destination.is_relative_to(self.checkout)):
            raise ApplicationError(DText.ERROR_CHECKOUT_OVERLAP)

    def installed_role(self) -> str | None:
        path = self.destination / DInstallation.ROLE_FILE
        reject_symlinks(path)
        if not path.exists():
            return None
        record = json.loads(path.read_text())
        if not isinstance(record, dict) or record.get('role') not in DInstallation.ROLES:
            raise ApplicationError(DText.ERROR_STORED_ROLE_INVALID)
        return record['role']

    def constants_content(self, role: str) -> bytes:
        if role == DInstallation.CA:
            return (self.checkout / self.version_file).read_bytes()
        # A target owns none of the CA's persistent paths, listener, or database.
        fields = dict(self.metadata, CMDB_SUBTYPE='Certificate Target',
                      CONFIG_DIR=f"{self.metadata['BASE_DIR']}/conf",
                      DATA_DIR=f"{self.metadata['BASE_DIR']}/data")
        lines = ['from typing import Final\n\n\nclass DBMCA:\n']
        lines.extend(f'    {key}: Final[str] = {value!r}\n' for key, value in fields.items())
        lines.extend(f'    {key} = ()\n' for key in ('CMDB_COMPONENTS', 'CMDB_DATABASES', 'CMDB_NETWORK'))
        return ''.join(lines).encode()

    def installed_files(self) -> list[str] | None:
        manifest = self.destination / DInstallation.MANIFEST
        reject_symlinks(manifest)
        if not manifest.exists():
            if self.destination.exists():
                raise ApplicationError(DText.ERROR_OWNERSHIP_MISSING)
            return None
        data = json.loads(manifest.read_text())
        if (not isinstance(data, dict) or data.get('project') != DInstallation.PROJECT_NAME
                or not isinstance(data.get('files'), list)):
            raise ApplicationError(DText.ERROR_OWNERSHIP_PROJECT)
        if data.get('role') != self.installed_role():
            raise ApplicationError(DText.ERROR_OWNERSHIP_ROLE)
        if type(data.get('venv_owned', False)) is not bool:
            raise ApplicationError(DText.ERROR_OWNERSHIP_VENV)
        names = [relative_path(name) for name in data['files']]
        if (len(names) != len(set(names))
                or self.version_file not in names and not (not names and data.get('removed') is True)):
            raise ApplicationError(DText.ERROR_OWNERSHIP_FILES)
        for name in [*names, DInstallation.VERSION_MARKER]:
            path = self.destination / name
            reject_symlinks(path)
            if path.exists() and not path.is_file():
                raise ApplicationError(DText.ERROR_MANAGED_FILE_INVALID, path=path)
        return names

    def source_files(self) -> list[str]:
        names = {relative_path(name) for name in DInstallation.COPY_FILES}
        if DInstallation.REQUIREMENTS_FILE is not None:
            names.add(relative_path(DInstallation.REQUIREMENTS_FILE))
        for name in DInstallation.COPY_TREES:
            folder = self.checkout / relative_path(name)
            reject_symlinks(folder)
            if not folder.is_dir():
                raise ApplicationError(DText.ERROR_SOURCE_DIRECTORY_MISSING, name=name)
            for path in folder.rglob('*'):
                if '__pycache__' in path.parts or DInstallation.VENV_DIR in path.parts or path.suffix in ('.pyc', '.pyo'):
                    continue
                reject_symlinks(path)
                if path.is_file():
                    names.add(relative_path(path.relative_to(self.checkout).as_posix()))
        if self.version_file not in names:
            raise ApplicationError(DText.ERROR_METADATA_REQUIRED)
        for name in names:
            source = self.checkout / name
            reject_symlinks(source)
            if not source.is_file():
                raise ApplicationError(DText.ERROR_SOURCE_FILE_MISSING, name=name)
            target = self.destination / name
            reject_symlinks(target)
            if target.exists() and not target.is_file():
                raise ApplicationError(DText.ERROR_TARGET_FILE_INVALID, target=target)
        return sorted(names)

    def venv_owned(self) -> bool:
        manifest = self.destination / DInstallation.MANIFEST
        return manifest.is_file() and json.loads(manifest.read_text()).get('venv_owned') is True

    @staticmethod
    def python_environment() -> dict[str, str]:
        environment = os.environ.copy()
        for variable in ('PYTHONPATH', 'PYTHONHOME', 'VIRTUAL_ENV',
                         'PIP_TARGET', 'PIP_PREFIX', 'PIP_USER'):
            environment.pop(variable, None)
        environment['PYTHONNOUSERSITE'] = '1'
        return environment

    def preflight_python(self, action: str) -> None:
        venv = self.destination / DInstallation.VENV_DIR
        reject_symlinks(venv)
        if venv.exists() and not venv.is_dir():
            raise ApplicationError(DText.ERROR_VENV_PATH, venv=venv)
        if action != DInstallation.UNINSTALL and not Path(DInstallation.SYSTEM_PYTHON).is_file():
            raise ApplicationError(DText.ERROR_PYTHON_MISSING, system_python=DInstallation.SYSTEM_PYTHON)
        if action != DInstallation.UNINSTALL:
            minimum = DInstallation.MINIMUM_PYTHON
            result = self.run([DInstallation.SYSTEM_PYTHON, '-B', '-c',
                               f'import sys; sys.exit(0 if sys.version_info >= {minimum!r} else 1)'],
                              env=self.python_environment(), capture_output=True, timeout=30)
            if result.returncode:
                raise ApplicationError(DText.ERROR_PYTHON_VERSION,
                                       version='.'.join(str(value) for value in minimum))
        if action == DInstallation.UNINSTALL or DInstallation.REQUIREMENTS_FILE is None:
            return
        requirements = self.checkout / relative_path(DInstallation.REQUIREMENTS_FILE)
        if not requirements.is_file():
            raise ApplicationError(DText.ERROR_REQUIREMENTS_MISSING, requirements_file=DInstallation.REQUIREMENTS_FILE)
        for entry in requirements.read_text().splitlines():
            entry = entry.strip()
            if (entry.startswith(('-e ', '--editable')) or '/opt/dev/' in entry):
                raise ApplicationError(DText.ERROR_REQUIREMENTS_DEVELOPMENT)
        if venv.exists():
            if not self.venv_owned():
                raise ApplicationError(DText.ERROR_VENV_UNOWNED, venv=venv)
            configuration = venv / 'pyvenv.cfg'
            binary = venv / 'bin/python'
            reject_symlinks(configuration)
            reject_symlinks(binary.parent)
            if (not configuration.is_file() or not binary.is_file()
                    or '/opt/dev/' in configuration.read_text()
                    or '/opt/dev/' in str(binary.resolve())):
                raise ApplicationError(DText.ERROR_VENV_INVALID, venv=venv)
        host_python = Path(DInstallation.SYSTEM_PYTHON)
        if (not host_python.is_absolute() or '/opt/dev/' in DInstallation.SYSTEM_PYTHON
                or host_python.is_relative_to(self.destination)
                or host_python.is_relative_to(self.checkout)
                or host_python.resolve().is_relative_to(self.checkout)
                or host_python.resolve().is_relative_to(self.destination)
                or '/opt/dev/' in str(host_python.resolve())
                or (host_python.parent.parent / 'pyvenv.cfg').exists()):
            raise ApplicationError(DText.ERROR_PYTHON_LOCATION)
        if shutil.which(DInstallation.SYSTEM_PYTHON) is None:
            raise ApplicationError(DText.ERROR_PYTHON_MISSING, system_python=DInstallation.SYSTEM_PYTHON)
        self.run([DInstallation.SYSTEM_PYTHON, '-B', '-c', 'import venv, ensurepip'],
                 check=True, env=self.python_environment(), capture_output=True,
                 text=True, timeout=30)

    def prepare_python(self) -> None:
        if DInstallation.REQUIREMENTS_FILE is None:
            return
        venv = self.destination / DInstallation.VENV_DIR
        python = venv / 'bin/python'
        environment = self.python_environment()
        if not venv.exists():
            self.run([DInstallation.SYSTEM_PYTHON, '-m', 'venv', str(venv)],
                     check=True, env=environment, timeout=120)
        self.run([str(python), '-m', 'pip', 'install', '--upgrade',
                  '-r', str(self.destination / DInstallation.REQUIREMENTS_FILE)],
                 check=True, cwd=self.destination, env=environment, timeout=300)
        self.run([str(python), '-m', 'pip', 'check'],
                 check=True, cwd=self.destination, env=environment, timeout=30)
        if DInstallation.RUNTIME_IMPORTS:
            # Imports run from deployed files, without a checkout or PYTHONPATH.
            self.run([str(python), '-B', '-c',
                      'from importlib import import_module; from sys import argv; '
                      '[import_module(name) for name in argv[1:]]',
                      *DInstallation.RUNTIME_IMPORTS],
                     check=True, cwd=self.destination, env=environment, timeout=30)

    def atomic_write(self, path: Path, content: bytes, mode: int = 0o644) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        for directory in (path.parent, *path.parent.parents):
            if directory == self.destination.parent:
                break
            directory.chmod(0o755)
        descriptor, name = tempfile.mkstemp(prefix='.bmforge-install-', dir=path.parent)
        temporary = Path(name)
        try:
            with os.fdopen(descriptor, 'wb') as stream:
                stream.write(content)
                os.fchmod(stream.fileno(), mode)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)

    def remove_files(self, names: list[str] | tuple[str, ...]) -> None:
        for name in names:
            path = self.destination / name
            path.unlink(missing_ok=True)
            for directory in path.parents:
                if directory == self.destination:
                    break
                try:
                    directory.rmdir()
                except OSError:
                    break

    def verify_payload(self, names: tuple[str, ...], role: str) -> None:
        for name in names:
            path = self.destination / name
            expected = (self.constants_content(role) if name == self.version_file
                        else (self.checkout / name).read_bytes())
            if path.read_bytes() != expected:
                raise ApplicationError(DText.ERROR_PAYLOAD_INVALID, name=name)
            source_mode = (self.checkout / name).stat().st_mode
            if source_mode & 0o111 and not path.stat().st_mode & 0o111:
                raise ApplicationError(DText.ERROR_EXECUTABLE_INVALID, name=name)
        environment = self.python_environment()
        self.run([DInstallation.SYSTEM_PYTHON, '-B', '-c',
                  'import json, sys; from pathlib import Path; '
                  'from bmca.BMCA import BMCA; from bmca.constants.DBMCA import DBMCA; '
                  'from bmca.constants.DText import DText; from bmca.interface.Localizer import Localizer; '
                  'directory = Path("bmca/locales"); Localizer(directory); '
                  'assert set(json.loads((directory / "en.json").read_text(encoding="utf-8"))) '
                  '== {key.value for key in DText}; '
                  'assert DBMCA.VERSION == sys.argv[1]',
                  self.metadata['VERSION']], cwd=self.destination,
                 env=environment, check=True, timeout=30, capture_output=True, text=True)

    def preflight_payload(self, previous: list[str] | None, current: list[str]) -> None:
        if previous is not None:
            for name in set(current) - set(previous):
                if (self.destination / name).exists():
                    raise ApplicationError(DText.ERROR_UNOWNED_COLLISION, name=name)

    def begin_installation(self, plan: InstallationPlan) -> None:
        self.destination.mkdir(parents=True, exist_ok=True)
        self.destination.chmod(0o755)
        owned = sorted(set(plan.previous_files or ()) | set(plan.files))
        previous_venv = self.venv_owned() if plan.previous_files is not None else False
        ownership = {"project": DInstallation.PROJECT_NAME, "role": plan.role,
                     "files": owned,
                     "venv_owned": DInstallation.REQUIREMENTS_FILE is not None or previous_venv}
        if self.installed_role() is None:
            self.atomic_write(self.destination / DInstallation.ROLE_FILE,
                              (json.dumps({"role": plan.role}) + "\n").encode())
        self.atomic_write(self.destination / DInstallation.MANIFEST,
                          (json.dumps(ownership, indent=2) + "\n").encode())

    def copy_payload(self, names: tuple[str, ...]) -> None:
        for name in names:
            if name == self.version_file:
                continue
            source = self.checkout / name
            mode = 0o755 if source.stat().st_mode & 0o111 else 0o644
            self.atomic_write(self.destination / name, source.read_bytes(), mode)

    def install_metadata(self, role: str) -> None:
        self.atomic_write(self.destination / self.version_file, self.constants_content(role))

    def complete_installation(self, plan: InstallationPlan) -> None:
        ownership = {"project": DInstallation.PROJECT_NAME, "role": plan.role,
                     "files": list(plan.files), "venv_owned": self.venv_owned()}
        self.atomic_write(self.destination / DInstallation.MANIFEST,
                          (json.dumps(ownership, indent=2) + "\n").encode())
        self.atomic_write(self.destination / DInstallation.VERSION_MARKER,
                          (self.metadata["VERSION"] + "\n").encode())

    def remove_installation(self, plan: InstallationPlan) -> None:
        if plan.previous_files is None:
            return
        self.remove_files(plan.previous_files)
        venv = self.destination / DInstallation.VENV_DIR
        reject_symlinks(venv)
        if venv.is_dir() and self.venv_owned():
            shutil.rmtree(venv)
        (self.destination / DInstallation.VERSION_MARKER).unlink(missing_ok=True)
        (self.destination / DInstallation.MANIFEST).unlink()
        try:
            self.destination.rmdir()
        except OSError:
            removed = {"project": DInstallation.PROJECT_NAME, "role": plan.role,
                       "files": [], "removed": True}
            self.atomic_write(self.destination / DInstallation.MANIFEST,
                              (json.dumps(removed, indent=2) + "\n").encode())

