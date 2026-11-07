"""An application failure with a stable message key and substitution values."""

from bmca.constants.DText import DText


class ApplicationError(ValueError):
    def __init__(self, key: DText, **parameters) -> None:
        self.key = key
        self.parameters = parameters
        super().__init__(key.value)
