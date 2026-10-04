#!/usr/bin/env python3
"""Wait for an uploaded build to finish processing in App Store Connect, then attach it
to the app's internal TestFlight testers and confirm it is IN_BETA_TESTING.

Release tooling only (not needed to build the app). Reads its configuration from the
environment (see archive_and_upload.sh); no credentials are stored in this repo.
Requires PyJWT: pip3 install pyjwt cryptography
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

try:
    import jwt
except ImportError:
    print("PyJWT is required: pip3 install pyjwt cryptography")
    sys.exit(1)

API = "https://api.appstoreconnect.apple.com"


def require_env(name):
    value = os.environ.get(name, "")
    if not value:
        print(f"Missing {name}.")
        sys.exit(1)
    return value


def make_token(key_id, issuer_id, key_path):
    with open(key_path, "r") as handle:
        private_key = handle.read()
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def request(path, token, method="GET", body=None):
    data = json.dumps(body).encode("utf-8") if body else None
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            content = response.read()
            return json.loads(content.decode("utf-8")) if content else {}
    except urllib.error.HTTPError as error:
        return {"error": error.code, "message": error.read().decode("utf-8", errors="replace")}


def internal_group(app_id, token):
    groups = request(f"/v1/apps/{app_id}/betaGroups", token).get("data", [])
    for group in groups:
        attrs = group.get("attributes", {})
        if attrs.get("isInternalGroup"):
            return group["id"], attrs.get("hasAccessToAllBuilds", False)
    return None, False


def ensure_internal_group(app_id, token):
    """Returns (group_id, has_access_to_all_builds), creating "Internal Testers" if the app has none."""
    group_id, has_all = internal_group(app_id, token)
    if group_id:
        return group_id, has_all
    body = {
        "data": {
            "type": "betaGroups",
            "attributes": {"name": "Internal Testers", "isInternalGroup": True, "hasAccessToAllBuilds": True},
            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
        }
    }
    created = request("/v1/betaGroups", token, "POST", body)
    if "data" in created:
        return created["data"]["id"], True
    print(f"Could not create internal group: HTTP {created.get('error')}")
    return None, False


def ensure_tester(group_id, app_id, token, email):
    """Returns this app's beta tester id for `email`, creating the tester in `group_id` if needed.
    Tester records are per app, so a tester that exists on another app cannot be reused."""
    found = request(f"/v1/betaTesters?filter[email]={email}&filter[apps]={app_id}", token).get("data", [])
    if found:
        return found[0]["id"]
    body = {
        "data": {
            "type": "betaTesters",
            "attributes": {"email": email},
            "relationships": {"betaGroups": {"data": [{"type": "betaGroups", "id": group_id}]}},
        }
    }
    created = request("/v1/betaTesters", token, "POST", body)
    if "data" in created:
        return created["data"]["id"]
    print(f"Could not create tester: HTTP {created.get('error')}")
    return None


def distribute(build_id, app_id, token, tester_email):
    group_id, has_all = ensure_internal_group(app_id, token)
    if group_id and tester_email:
        tester_id = ensure_tester(group_id, app_id, token, tester_email)
        if tester_id:
            body = {"data": [{"type": "betaTesters", "id": tester_id}]}
            result = request(f"/v1/betaGroups/{group_id}/relationships/betaTesters", token, "POST", body)
            if result.get("error") not in (None, 409):
                print(f"Could not add tester to group: HTTP {result['error']}")
    if group_id and not has_all:
        body = {"data": [{"type": "builds", "id": build_id}]}
        result = request(f"/v1/betaGroups/{group_id}/relationships/builds", token, "POST", body)
        if result.get("error") not in (None, 409):
            print(f"Could not attach to internal group: HTTP {result['error']}")

    detail = request(f"/v1/builds/{build_id}?include=buildBetaDetail", token)
    for item in detail.get("included", []):
        if item.get("type") == "buildBetaDetails":
            return item.get("attributes", {}).get("internalBuildState", "UNKNOWN")
    return "UNKNOWN"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="build number to wait for")
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--poll-interval", type=int, default=15)
    args = parser.parse_args()

    key_id = require_env("ASC_KEY_ID")
    issuer_id = require_env("ASC_ISSUER_ID")
    key_path = require_env("ASC_KEY_PATH")
    app_id = require_env("ASC_APP_ID")
    tester_email = os.environ.get("TESTER_EMAIL", "")

    token = make_token(key_id, issuer_id, key_path)
    deadline = time.time() + args.timeout

    while time.time() < deadline:
        builds = request(f"/v1/builds?filter[app]={app_id}&sort=-uploadedDate&limit=10", token).get("data", [])
        match = next((b for b in builds if b["attributes"].get("version") == str(args.version)), None)
        if match is None:
            print(f"Build {args.version} not visible yet...")
        else:
            state = match["attributes"].get("processingState")
            print(f"Build {args.version}: {state}")
            if state == "VALID":
                final = distribute(match["id"], app_id, token, tester_email)
                print(f"Internal build state: {final}")
                if final == "IN_BETA_TESTING":
                    print(f"Build {args.version} is live in TestFlight.")
                    return
                print("Build is processed but not yet IN_BETA_TESTING; re-checking...")
            elif state in ("FAILED", "INVALID"):
                print(f"Build {args.version} failed processing: {state}")
                sys.exit(1)
        time.sleep(args.poll_interval)

    print("Timed out waiting for the build to reach TestFlight.")
    sys.exit(1)


if __name__ == "__main__":
    main()
