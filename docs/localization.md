# CLI localization

English is the only published language while the application settles. Visible
help, usage, validation errors, and deployment results come from
`bmca/locales/en.json` through stable `DText` keys. The pinned standard-library
`Localizer.py` is copied unchanged. No pip dependency or translation service is
needed.

## Selecting a language

```sh
python3 -B -m bmca --help --lang en
scripts/install.sh --role ca --check --lang en
```

An explicit `--lang` wins over the environment. Otherwise the first nonempty
value from `LC_ALL`, `LC_MESSAGES`, and `LANG` is used. Encoding/modifier suffixes
are removed, underscores normalize to hyphens, and `C`/`POSIX` select English.
Unknown or unpublished preferences fall back to English. Selection is local to
the CLI call; it does not change the process locale or environment.

The Blog's published identifiers are the conventions for future translations:

| Language | Catalogue filename |
| --- | --- |
| English | `en.json` |
| Simplified Chinese (简体中文) | `zh-CN.json` |
| Ukrainian (Українська) | `uk.json` |

Only `en.json` ships now. The Chinese/Ukrainian acceptance cases use temporary,
synthetic fixtures, not production translations. `uk-UA` can match the explicit
parent `uk`; `zh-TW` must not select `zh-CN`. The application does not guess
aliases between different script/region identifiers.

## Adding reviewed translations later

Add a UTF-8 JSON catalogue with the same stable keys as English. Partial
catalogues use per-key English fallback. Named placeholders may be reordered,
but their names must match English. Unknown keys, unsupported placeholders, and
placeholder mismatches fail validation. CLI usage/help are catalogue templates
so their labels and layout can change without global argparse translation state.

Keep command names, flags, actions, roles, JSON fields, paths, CMDB identifiers,
and machine error keys stable. Translate display text only. Application-owned
failures carry an `ApplicationError.key` and `parameters`; CLI rendering chooses
the language. Raw operating-system/subprocess/canonical-checker diagnostic detail
is retained in its original form beneath a localized failure message.

The installer verifies installed catalogue integrity and the `DText` key inventory
before advancing `.deployment-version`. The required Python minimum is 3.11,
matching the pinned `StrEnum` message-key template. Install/upgrade preflight
checks the host interpreter before changing files.
