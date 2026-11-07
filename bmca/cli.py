"""Parse CLI input and render application messages in the selected locale."""

import argparse
import os
from pathlib import Path
import subprocess
import sys

from bmca.BMCA import BMCA
from bmca.constants.DInstallation import DInstallation
from bmca.constants.DLocalization import DLocalization
from bmca.constants.DText import DText
from bmca.entity.ApplicationError import ApplicationError
from bmca.interface.Localizer import Localizer


def select_locale(localizer: Localizer, explicit: str | None, environment) -> str:
    """Use an explicit choice, then the standard CLI locale environment."""
    if explicit is not None:
        return localizer.select(explicit=explicit)
    for name in DLocalization.ENVIRONMENT:
        value = environment.get(name)
        if value:
            tag = value.split(".", 1)[0].split("@", 1)[0]
            if tag in DLocalization.DEFAULT_LOCALES:
                tag = DLocalization.DEFAULT_LANGUAGE
            return localizer.select(explicit=tag)
    return localizer.default_language


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    localizer = Localizer(Path(__file__).resolve().parent / DLocalization.DIRECTORY)
    # Select language before handling help and argument errors. This parser has
    # no positional requirements and makes no changes to process locale state.
    language_parser = argparse.ArgumentParser(add_help=False, exit_on_error=False)
    language_parser.add_argument(DLocalization.OPTION)
    try:
        language, _ = language_parser.parse_known_args(arguments)
        explicit = language.lang
    except argparse.ArgumentError:
        explicit = None
    locale = select_locale(localizer, explicit, os.environ)

    def text(key, **values):
        return localizer.text(key, locale=locale, **values)

    # argparse owns tokenization; this boundary owns all visible help/errors.
    # Optional positional/choice validation below avoids argparse's global
    # gettext state and keeps every current CLI diagnostic catalogue-backed.
    parser = argparse.ArgumentParser(add_help=False, exit_on_error=False)
    parser.add_argument("action", nargs="?")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--role")
    parser.add_argument(DLocalization.OPTION)
    parser.add_argument("-h", "--help", action="store_true")
    usage_values = {"prog": parser.prog, "actions": ",".join(DInstallation.ACTIONS),
                    "roles": ",".join(DInstallation.ROLES)}

    def error(key, **values):
        sys.stderr.write(text(DText.CLI_USAGE, **usage_values))
        sys.stderr.write(text(DText.CLI_ERROR, prog=parser.prog, message=text(key, **values)))
        raise SystemExit(2)

    try:
        args, unknown = parser.parse_known_args(arguments)
    except argparse.ArgumentError as failure:
        key = (DText.CLI_ARGUMENT_VALUE if failure.argument_name in ("--role", DLocalization.OPTION)
               else DText.CLI_FLAG_VALUE)
        error(key, argument=failure.argument_name)
    if args.help:
        print(text(DText.CLI_USAGE, **usage_values))
        print(text(DText.CLI_HELP, actions=usage_values["actions"], roles=usage_values["roles"]), end="")
        return 0
    if unknown:
        error(DText.CLI_UNRECOGNIZED, arguments=" ".join(unknown))
    if args.action is None:
        error(DText.CLI_ACTION_REQUIRED)
    for name, value, choices in (("action", args.action, DInstallation.ACTIONS),
                                 ("--role", args.role, DInstallation.ROLES)):
        if value is not None and value not in choices:
            error(DText.CLI_CHOICE, argument=name, value=repr(value),
                  choices=", ".join(repr(choice) for choice in choices))
    if not args.check and os.geteuid() != 0:
        error(DText.CLI_ROOT_REQUIRED)
    try:
        app = BMCA(Path(__file__).resolve().parents[1])
        plan = app.deploy(args.action, role=args.role, check=args.check)
    except ApplicationError as failure:
        sys.stderr.write(text(DText.DEPLOYMENT_FAILED,
                              detail=text(failure.key, **failure.parameters)))
        return 1
    except subprocess.CalledProcessError as failure:
        sys.stderr.write(text(DText.DEPLOYMENT_FAILED, detail=failure.stderr or str(failure)))
        return 1
    except (OSError, ValueError, TypeError, SyntaxError, subprocess.SubprocessError) as failure:
        sys.stderr.write(text(DText.DEPLOYMENT_FAILED, detail=str(failure)))
        return 1
    if args.check:
        print(text(DText.DEPLOYMENT_CHECKED, action=plan.action, destination=plan.destination))
    elif args.action == DInstallation.UNINSTALL:
        print(text(DText.DEPLOYMENT_REMOVED, project=DInstallation.PROJECT_NAME))
    else:
        print(text(DText.DEPLOYMENT_COMPLETED, action=plan.action, project=DInstallation.PROJECT_NAME,
                   version=plan.version, destination=plan.destination))
    return 0
