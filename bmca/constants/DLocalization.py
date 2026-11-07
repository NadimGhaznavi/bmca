"""Application catalogue location and CLI locale preference order."""

from typing import Final


class DLocalization:
    DIRECTORY: Final[str] = "locales"
    DEFAULT_LANGUAGE: Final[str] = "en"
    OPTION: Final[str] = "--lang"
    ENVIRONMENT: Final[tuple[str, ...]] = ("LC_ALL", "LC_MESSAGES", "LANG")
    DEFAULT_LOCALES: Final[tuple[str, ...]] = ("C", "POSIX")
