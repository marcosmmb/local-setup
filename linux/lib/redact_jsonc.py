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
import os
import re
import sys

# A key is redacted if its normalised name contains any of these. Names are
# normalised by lowercasing and dropping every non-alphanumeric character, so a
# single entry covers apiKey, api_key, api-key and API.KEY alike.
SECRET_SUBSTRINGS = (
    "token",
    "secret",
    "password",
    "passwd",
    "passphrase",
    "apikey",
    "accesskey",
    "privatekey",
    "signingkey",
    "credential",
    "connectionstring",
    "cookie",
    "sessionid",
    "auth",
    "bearer",
    "license",
)

# Redacted by exact name: not secret-shaped, but leaks infrastructure.
SECRET_KEYS = {
    "pgsql.connections",      # production DB hostnames and usernames
    "pgsql.serverGroups",
    "database-client.connections",
    "inference.endpoint",     # private LAN address
    "inference.custom.endpoint",
}

# A string is matched wherever it appears -- as a value, or as a key in a map
# such as yaml.schemas or files.exclude -- against these. Key-name matching
# alone cannot catch a token an extension parked under an innocuous name, nor
# an internal path that arrived as the value of a perfectly ordinary setting.
#
# A *value* that matches is replaced with the placeholder. A *key* that matches
# is dropped along with its value, because the key is itself the disclosure and
# leaving it behind with a redacted value would publish it anyway.
VALUE_PATTERNS = (
    re.compile(r"://[^/\s:@]+:[^/\s@]+@"),                # credentials in a URL
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\b(?:sk|rk)-[A-Za-z0-9_-]{16,}"),        # OpenAI-style keys
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"),          # GitHub tokens
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{10,}"),        # Slack tokens
    re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"),         # AWS access key IDs
    re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b"),             # Google API keys
    re.compile(r"\bglpat-[A-Za-z0-9_-]{16,}"),            # GitLab tokens
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\."),  # JWTs
    # Internal identifiers this machine's editor accumulates: an employer build
    # root, its private extension marketplace, and the extension publishers and
    # internal tool names that go with them.
    re.compile(r"/workplace/"),
    re.compile(r"\b(?:amzn|asbx|isengard|brazil|midway|viceroy)", re.IGNORECASE),
)

# Extra patterns from an uncommitted local file, one regex per line.
#
# Internal project and service names cannot go in the list above: this file is
# public, so naming them here would publish exactly what the rule exists to
# hide. Put those in lib/redact-extra-patterns.txt, which .gitignore excludes;
# see redact-extra-patterns.txt.example.
EXTRA_PATTERNS_FILE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "redact-extra-patterns.txt"
)

REDACTED = "<redacted by redact_jsonc.py -- restore by hand>"


def load_extra_patterns():
    try:
        with open(EXTRA_PATTERNS_FILE, encoding="utf-8") as fh:
            raw = fh.read()
    except OSError:
        return ()
    patterns = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            patterns.append(re.compile(line, re.IGNORECASE))
        except re.error as exc:
            print(f"redact_jsonc: ignoring bad pattern {line!r}: {exc}", file=sys.stderr)
    return tuple(patterns)


VALUE_PATTERNS += load_extra_patterns()


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
        if ch in "}]":
            # Trailing commas before } or ] are legal in JSONC but not JSON.
            # Dropped here, inside the scanner, so that a comma sitting in a
            # string value -- a clang-format style, a regex, a snippet body --
            # is left alone. A regex over the whole document cannot tell the
            # two apart and silently rewrites the string.
            j = len(out) - 1
            while j >= 0 and out[j] in " \t\r\n":
                j -= 1
            if j >= 0 and out[j] == ",":
                del out[j]
        out.append(ch)
        i += 1
    return "".join(out)


def normalise(key: str) -> str:
    return re.sub(r"[^a-z0-9]", "", key.lower())


def is_secret(key: str) -> bool:
    if key in SECRET_KEYS:
        return True
    normalised = normalise(key)
    return any(s in normalised for s in SECRET_SUBSTRINGS)


def looks_secret(value) -> bool:
    """True if a string carries a secret or an internal identifier of its own."""
    return isinstance(value, str) and any(p.search(value) for p in VALUE_PATTERNS)


def redact(node):
    """Walk the tree, replacing secret values and reporting what changed."""
    removed = []

    def walk(value, path):
        if isinstance(value, dict):
            result = {}
            for k, v in value.items():
                here = f"{path}.{k}" if path else k
                if looks_secret(k):
                    # The key is the disclosure, so the entry goes entirely --
                    # including when the value is a bare `true`.
                    removed.append(f"{here} (dropped)")
                elif is_secret(k) or looks_secret(v):
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
            return [
                REDACTED if looks_secret(v) else walk(v, f"{path}[{i}]")
                for i, v in enumerate(value)
            ]
        return REDACTED if looks_secret(value) else value

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
