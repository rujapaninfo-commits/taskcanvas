#!/usr/bin/env python3

import re
import subprocess
import sys
from pathlib import Path


BLOCKED_PATHS = [
    re.compile(r"(^|/)TaskCanvasShared/AppConfiguration\.swift$"),
    re.compile(r"(^|/)\.env(?:\.|$)"),
    re.compile(r"(^|/)AuthKey_[^/]+\.p8$"),
    re.compile(r"\.(?:p8|p12|pem|key|mobileprovision|provisionprofile)$", re.I),
    re.compile(r"(^|/)(?:GoogleService-Info\.plist|client_secret[^/]*\.json|credentials[^/]*\.json|service-account[^/]*\.json)$", re.I),
]

SECRET_PATTERNS = {
    "Google API key": re.compile(rb"AIza[0-9A-Za-z_-]{30,}"),
    "Google OAuth client secret": re.compile(rb"GOCSPX-[0-9A-Za-z_-]{10,}"),
    "GitHub token": re.compile(rb"gh[pousr]_[0-9A-Za-z]{20,}"),
    "AWS access key": re.compile(rb"AKIA[0-9A-Z]{16}"),
    "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "JWT": re.compile(rb"eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}"),
}


def candidate_files() -> list[str]:
    output = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
    )
    return [path.decode() for path in output.split(b"\0") if path]


def main() -> int:
    findings: list[str] = []

    for relative_path in candidate_files():
        if any(pattern.search(relative_path) for pattern in BLOCKED_PATHS):
            findings.append(f"blocked credential filename: {relative_path}")
            continue

        path = Path(relative_path)
        try:
            data = path.read_bytes()
        except OSError:
            continue

        if b"\0" in data or len(data) > 5_000_000:
            continue

        for label, pattern in SECRET_PATTERNS.items():
            if pattern.search(data):
                findings.append(f"{label}: {relative_path}")

    if findings:
        print("Potential secrets found:")
        for finding in sorted(set(findings)):
            print(f"  - {finding}")
        return 1

    print("Secret scan passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
