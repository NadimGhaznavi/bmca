from typing import Final


class DBMCA:
    VERSION: Final[str] = "1.0.1"
    CMDB_TYPE: Final[str] = "application"
    CMDB_SUBTYPE: Final[str] = "Certificate Authority"
    CMDB_SUPPLIER: Final[str] = "Nadim-Daniel"
    CMDB_CODENAME: Final[str] = "Thulium"
    CMDB_COMPONENTS = (
        ("BMCA configuration", "conf"),
        ("BMCA data", "data"),
    )
    # Planned application database; this declaration does not provision it.
    CMDB_DATABASES = (("BMCA", "bmca"),)
    # Declare listeners when the new application's services are implemented.
    CMDB_NETWORK: Final[tuple[tuple[str, str, int], ...]] = ()
    BASE_DIR: Final[str] = "/opt/prod/bmca"
    CONFIG_DIR: Final[str] = "/opt/prod/bmca/conf"
    DATA_DIR: Final[str] = "/opt/prod/bmca/data"
