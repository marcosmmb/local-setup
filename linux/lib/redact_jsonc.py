#!/usr/bin/env python3
"""Strip secret-bearing keys out of a JSONC file before it is committed.

VS Code's settings.json accumulates API tokens, database connection profiles and
internal hostnames from every extension that has ever been installed. This
repository is public, so those keys are removed rather than published.

Reads JSONC (JSON with // comments and trailing commas) on stdin or from a path,
writes plain JSON to stdout. Comments are not preserved.

Usage: redact_jsonc.py <file> > <file>.redacted
"""

import json
import re
import sys

# A key is dropped if its name contains any of these, case-insensitively.
SECRET_SUBSTRINGS = (
    "token",
    "secret",
    "password",
    "passwd",
    "apikey",
    "api_key",
    "credential",
    "cookie",
    "auth",
    "license",
)

# Dropped by exact name: not secret-shaped, but leaks infrastructure.
SECRET_KEYS = {
    "pgsql.connections",      # production DB hostnames and usernames
    "pgsql.serverGroups",
    "database-client.connections",
    "inference.endpoint",     # private LAN address
    "inference.custom.endpoint",
}

REDACTED = "<redacted by redact_jsonc.py -- restore by hand>"


def strip_jsonc(text: str) -> str:
    """Remove // and /* */ comments and trailing commas, ignoring string bodies."""
    out = []
    i, n = 0, len(text)
    in_string = False
    while i < n:
        ch = text[i]
        if in_string:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if text.startswith("//", i):
            i = text.find("\n", i)
            if i == -1:
                break
            continue
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end == -1 else end + 2
            continue
        out.append(ch)
        i += 1
    # Trailing commas before } or ] are legal in JSONC but not JSON.
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def is_secret(key: str) -> bool:
    if key in SECRET_KEYS:
        return True
    lowered = key.lower()
    return any(s in lowered for s in SECRET_SUBSTRINGS)


def redact(node):
    """Walk the tree, replacing secret-keyed values and reporting what changed."""
    removed = []

    def walk(value, path):
        if isinstance(value, dict):
            result = {}
            for k, v in value.items():
                here = f"{path}.{k}" if path else k
                if is_secret(k):
                    # Keep booleans and empty strings: they are settings, not secrets.
                    if isinstance(v, bool) or v == "" or v is None:
                        result[k] = v
                    else:
                        result[k] = REDACTED
                        removed.append(here)
                else:
                    result[k] = walk(v, here)
            return result
        if isinstance(value, list):
            return [walk(v, f"{path}[{i}]") for i, v in enumerate(value)]
        return value

    return walk(node, ""), removed


def main() -> int:
    if len(sys.argv) > 1:
        with open(sys.argv[1], encoding="utf-8") as fh:
            raw = fh.read()
    else:
        raw = sys.stdin.read()

    try:
        data = json.loads(strip_jsonc(raw))
    except json.JSONDecodeError as exc:
        print(f"redact_jsonc: could not parse input: {exc}", file=sys.stderr)
        return 1

    cleaned, removed = redact(data)
    print(json.dumps(cleaned, indent=4, ensure_ascii=False))

    for key in removed:
        print(f"    redacted: {key}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
