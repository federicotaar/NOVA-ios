#!/usr/bin/env python3
"""Client/server contract check for the NOVA backend.

Compares the profile/backup field lists hard-coded in the Swift client against
the live worker contract at https://api.federicotaranu.site/contract and fails
CI when the client would send a key the worker rejects. This guards the bug
class where a new client field ships before the worker allowlist knows it
(e.g. 'accent'/'saved' breaking backups, 'stato' breaking profile sync).

No secrets involved: /contract is a public endpoint that lists accepted keys.
"""
import json
import re
import sys
import urllib.request

CONTRACT_URL = "https://api.federicotaranu.site/contract"
BACKUP_SWIFT = "Sources/NOVA/NOVASwiftBackup.swift"
CORE_SWIFT = "Sources/NOVA/NOVASwiftCore.swift"


def swift_string_list(source: str, decl: str) -> list[str]:
    m = re.search(re.escape(decl) + r"\s*=\s*\[([^\]]*)\]", source)
    if not m:
        raise SystemExit(f"could not find {decl} in the Swift source")
    return re.findall(r'"([^"]+)"', m.group(1))


def editor_put_keys(core: str) -> list[str]:
    """Keys the profile editor PUTs to /profile (NOVASwiftProfileEditor.save)."""
    start = core.find("func save() async")
    if start < 0:
        raise SystemExit("could not find the profile editor save() in NOVASwiftCore.swift")
    region = core[start : start + 2500]
    keys = set(re.findall(r'body\["(\w+)"\]\s*=', region))
    m = re.search(r'for key in \[([^\]]*)\]\s*\{\s*body\[key\]', region)
    if m:
        keys.update(re.findall(r'"([^"]+)"', m.group(1)))
    return sorted(keys)


def main() -> int:
    backup_src = open(BACKUP_SWIFT, encoding="utf-8").read()
    core_src = open(CORE_SWIFT, encoding="utf-8").read()

    client_backup = swift_string_list(backup_src, "static let fields")
    client_profile = swift_string_list(backup_src, "static let profileFields")
    put_keys = editor_put_keys(core_src)
    snapshot_keys = sorted(set(client_backup) | {"prof"})  # snapshot() adds prof

    req = urllib.request.Request(CONTRACT_URL, headers={"User-Agent": "nova-contract-check/1.0 (GitHub Actions)"})
    with urllib.request.urlopen(req, timeout=20) as r:
        contract = json.loads(r.read().decode())
    server_backup = set(contract["backup_fields"])
    server_profile = set(contract["profile_fields"])
    server_put = set(contract["profile_put_fields"])

    failures = []
    for label, client_keys, server_keys in (
        ("backup snapshot", snapshot_keys, server_backup),
        ("backup prof subkeys", client_profile, server_profile),
        ("editor PUT /profile", put_keys, server_put),
    ):
        extra = sorted(set(client_keys) - server_keys)
        if extra:
            failures.append(f"{label}: client sends keys the worker rejects: {extra}")

    if failures:
        print("CONTRACT MISMATCH - the client would be rejected by the live worker:")
        for f in failures:
            print(" -", f)
        print("Fix: update the worker allowlists (BACKUP_FIELDS / PROFILE_FIELDS / "
              "PROFILE_PUT_FIELDS) or remove the key from the client before release.")
        return 1

    print(f"contract OK: {len(snapshot_keys)} backup keys, {len(client_profile)} prof keys, "
          f"{len(put_keys)} editor keys all accepted by {CONTRACT_URL}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
