#!/usr/bin/env python3
"""Merge the repository's redacted copy of a JSONC file into the live one.

redact_jsonc.py replaces machine-local values -- API tokens, database
connection profiles -- with a placeholder before the file is committed, because
this repository is public. Copying that file back over the live one would
overwrite the real values with the placeholder string and change their JSON
type, so the extension that reads them fails schema validation and behaves as
if the setting were never configured.

So the repository copy is merged rather than installed: its values win, except
for placeholder keys, which keep whatever the machine already has. Settings the
machine has and the repository does not are left in place -- applying a config
snapshot should not silently delete settings that postdate it.

Usage: merge_jsonc.py <repo-file> <live-file> > merged.json
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from redact_jsonc import REDACTED, strip_jsonc  # noqa: E402


def merge(repo, live):
    if isinstance(repo, dict) and isinstance(live, dict):
        merged = dict(live)  # keep machine-only settings
        for key, value in repo.items():
            if value == REDACTED:
                # Nothing to install: keep the live value if there is one, and
                # otherwise leave the key out entirely.
                continue
            merged[key] = merge(value, live.get(key))
        return merged
    if isinstance(repo, dict):
        return {k: merge(v, None) for k, v in repo.items() if v != REDACTED}
    return repo


def load(path, required):
    """Parse a JSONC file. A missing or corrupt live file merges as empty."""
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except OSError as exc:
        if required:
            print(f"merge_jsonc: cannot read {path}: {exc}", file=sys.stderr)
            raise
        return None
    try:
        return json.loads(strip_jsonc(raw))
    except json.JSONDecodeError as exc:
        if required:
            print(f"merge_jsonc: cannot parse {path}: {exc}", file=sys.stderr)
            raise
        print(f"merge_jsonc: ignoring unparseable {path}: {exc}", file=sys.stderr)
        return None


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2

    repo_path, live_path = sys.argv[1], sys.argv[2]
    try:
        repo = load(repo_path, required=True)
    except (OSError, json.JSONDecodeError):
        return 1
    live = load(live_path, required=False)

    print(json.dumps(merge(repo, live), indent=4, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
