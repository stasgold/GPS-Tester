#!/usr/bin/env python3
"""
Keeps CI from piling up signing certificates.

Each TestFlight run starts on a fresh Mac, so `xcodebuild -allowProvisioningUpdates` creates a new
certificate on the team every time and the account soon hits Apple's limit. This script snapshots the
team's certificates before the build and revokes the ones the build created once it is done.

    python3 ci/ci_certificates.py snapshot   # before archiving
    python3 ci/ci_certificates.py revoke     # after uploading (run even if the build failed)

Only certificates that did not exist at snapshot time AND that Xcode created through the API
(display name "Created via API") are revoked, so certificates made on a Mac are never touched.
Revoking them does not affect builds already uploaded to TestFlight or the App Store.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH (the .p8 file) in the environment. Uses only the
Python standard library plus the openssl command line tool.
"""

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
SNAPSHOT = os.path.join(os.environ.get("RUNNER_TEMP", "/tmp"), "certificates-before.json")


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_to_raw(signature: bytes) -> bytes:
    """openssl writes ECDSA signatures as DER; JWT ES256 wants r || s, 32 bytes each."""
    assert signature[0] == 0x30
    index = 2 if signature[1] < 0x80 else 2 + (signature[1] & 0x7F)
    parts = []
    for _ in range(2):
        assert signature[index] == 0x02
        length = signature[index + 1]
        value = signature[index + 2:index + 2 + length]
        parts.append(value.lstrip(b"\x00").rjust(32, b"\x00"))
        index += 2 + length
    return b"".join(parts)


def token() -> str:
    header = {"alg": "ES256", "kid": os.environ["ASC_KEY_ID"], "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"}
    message = f"{b64url(json.dumps(header).encode())}.{b64url(json.dumps(payload).encode())}"
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", os.environ["ASC_KEY_PATH"]],
                         input=message.encode(), capture_output=True, check=True).stdout
    return f"{message}.{b64url(der_to_raw(der))}"


def request(method: str, url: str):
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {token()}"})
    with urllib.request.urlopen(req, timeout=60) as response:
        body = response.read()
        return json.loads(body) if body else None


def certificates() -> dict:
    url = f"{API}/certificates?limit=200&fields[certificates]=name,displayName,certificateType"
    found = {}
    while url:
        page = request("GET", url)
        for item in page["data"]:
            found[item["id"]] = item["attributes"]
        url = page.get("links", {}).get("next")
    return found


def main() -> None:
    action = sys.argv[1] if len(sys.argv) > 1 else ""
    if action == "snapshot":
        before = certificates()
        with open(SNAPSHOT, "w") as f:
            json.dump(sorted(before), f)
        print(f"{len(before)} certificates on the team before the build.")
    elif action == "revoke":
        if not os.path.exists(SNAPSHOT):
            print("No snapshot; nothing to revoke.")
            return
        with open(SNAPSHOT) as f:
            before = set(json.load(f))
        for cert_id, attributes in certificates().items():
            if cert_id in before or attributes.get("displayName") != "Created via API":
                continue
            try:
                request("DELETE", f"{API}/certificates/{cert_id}")
                print(f"Revoked {attributes.get('certificateType')} certificate {attributes.get('name')} ({cert_id}).")
            except urllib.error.HTTPError as error:
                print(f"::warning::Could not revoke certificate {cert_id}: HTTP {error.code} {error.read().decode()[:300]}")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        # Never fail the build over housekeeping; just make it visible.
        print(f"::warning::App Store Connect API error: HTTP {error.code} {error.read().decode()[:300]}")
