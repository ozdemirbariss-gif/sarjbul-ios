#!/usr/bin/env python3
"""Validate local release inputs without contacting services or printing credentials."""

import argparse
import plistlib
import re
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
RESOURCES = Path("SarjBul/Resources")
DEFAULT_BUNDLE_ID = "com.ozdemirbaris.sarjbul"
USER_DEFAULTS = "NSPrivacyAccessedAPICategoryUserDefaults"


def read_plist(path, errors, label=None):
    label = label or path.name
    try:
        with path.open("rb") as source:
            value = plistlib.load(source)
        if not isinstance(value, dict):
            raise ValueError("Expected a dictionary")
        return value
    except (OSError, ValueError, plistlib.InvalidFileException):
        errors.append(f"{label}: missing or invalid plist.")
        return None


def populated(value):
    if not isinstance(value, str) or not value.strip():
        return False
    return not any(marker in value.lower() for marker in (
        "your_", "your-", "replace_me", "placeholder", "example.com", "$(",
    ))


def https_url(value):
    if not populated(value):
        return False
    try:
        parsed = urlsplit(value)
        return (parsed.scheme == "https" and bool(parsed.hostname)
                and parsed.username is None and parsed.password is None
                and parsed.hostname not in {"localhost", "127.0.0.1", "::1"})
    except ValueError:
        return False


def firebase_database_url(value):
    if not https_url(value):
        return False
    parsed = urlsplit(value)
    return (parsed.hostname.endswith((".firebaseio.com", ".firebasedatabase.app"))
            and parsed.path in {"", "/"} and not parsed.query and not parsed.fragment)


def production_issues(config, firebase, bundle_id=DEFAULT_BUNDLE_ID):
    errors = []
    if config.get("firebaseBackendReady") is not True:
        errors.append("AppConfig.plist: firebaseBackendReady must be true only after backend deployment and verification.")
    for key in ("firebaseAPIKey", "supportEmail"):
        if not populated(config.get(key)):
            errors.append(f"AppConfig.plist: configure {key}.")
    email = config.get("supportEmail", "")
    if populated(email) and not re.fullmatch(r"[^\s@]+@[^\s@]+\.[^\s@]+", email):
        errors.append("AppConfig.plist: supportEmail must be a valid contact address.")
    for key in ("privacyPolicyURL", "termsOfUseURL", "supportURL", "stationTileManifestURL"):
        if not https_url(config.get(key)):
            errors.append(f"AppConfig.plist: {key} must be a public HTTPS URL.")
    if not firebase_database_url(config.get("firebaseDatabaseURL")):
        errors.append("AppConfig.plist: configure the root Realtime Database HTTPS URL.")
    for key in ("stationDataURL", "liveAvailabilityURL"):
        if config.get(key) and not https_url(config[key]):
            errors.append(f"AppConfig.plist: {key} must use HTTPS when configured.")

    for key in ("API_KEY", "GOOGLE_APP_ID", "GCM_SENDER_ID", "PROJECT_ID"):
        if not populated(firebase.get(key)):
            errors.append(f"GoogleService-Info.plist: configure {key}.")
    if firebase.get("BUNDLE_ID") != bundle_id:
        errors.append("GoogleService-Info.plist: BUNDLE_ID does not match the app target.")
    if firebase.get("API_KEY") != config.get("firebaseAPIKey"):
        errors.append("Firebase API keys in the two configuration files do not match.")
    app_id = firebase.get("GOOGLE_APP_ID", "")
    sender = firebase.get("GCM_SENDER_ID", "")
    if (not isinstance(app_id, str) or not isinstance(sender, str)
            or not re.fullmatch(r"1:" + re.escape(sender) + r":ios:[a-fA-F0-9]+", app_id)):
        errors.append("GoogleService-Info.plist: iOS app ID and sender ID do not match.")
    if firebase.get("DATABASE_URL"):
        database = config.get("firebaseDatabaseURL")
        if (not firebase_database_url(firebase["DATABASE_URL"])
                or not firebase_database_url(database)
                or urlsplit(database).hostname != urlsplit(firebase["DATABASE_URL"]).hostname):
            errors.append("Realtime Database URLs in the two configuration files do not match.")
    return errors


def manifest_issues(manifest, required_reasons, label):
    errors = []
    if manifest.get("NSPrivacyTracking") is not False:
        errors.append(f"{label}: tracking must remain disabled for this release.")
    if manifest.get("NSPrivacyTrackingDomains") != []:
        errors.append(f"{label}: unexpected tracking domains.")
    entries = manifest.get("NSPrivacyAccessedAPITypes", [])
    reasons = set()
    for entry in entries if isinstance(entries, list) else []:
        if isinstance(entry, dict) and entry.get("NSPrivacyAccessedAPIType") == USER_DEFAULTS:
            values = entry.get("NSPrivacyAccessedAPITypeReasons", [])
            if isinstance(values, list):
                reasons.update(value for value in values if isinstance(value, str))
    for reason in sorted(required_reasons - reasons):
        errors.append(f"{label}: missing UserDefaults reason {reason}.")
    return errors


def validate(root, production=False, bundle_id=DEFAULT_BUNDLE_ID):
    errors = []
    for relative, reasons in (
        (RESOURCES / "PrivacyInfo.xcprivacy", {"CA92.1", "1C8F.1"}),
        (Path("SarjBulWidgets/PrivacyInfo.xcprivacy"), {"1C8F.1"}),
    ):
        manifest = read_plist(root / relative, errors, str(relative))
        if manifest is not None:
            errors.extend(manifest_issues(manifest, reasons, str(relative)))

    app = read_plist(root / "SarjBul/SarjBul.entitlements", errors)
    widget = read_plist(root / "SarjBulWidgets/SarjBulWidgets.entitlements", errors)
    if app is not None and widget is not None:
        groups = app.get("com.apple.security.application-groups", [])
        if not groups or widget.get("com.apple.security.application-groups") != groups:
            errors.append("App and widget must declare the same nonempty App Group list.")
        if app.get("aps-environment") != "production":
            errors.append("Release push entitlement must use production.")
        if app.get("com.apple.developer.devicecheck.appattest-environment") != "production":
            errors.append("Release App Attest entitlement must use production.")

    if production:
        config = read_plist(root / RESOURCES / "AppConfig.plist", errors)
        firebase = read_plist(root / RESOURCES / "GoogleService-Info.plist", errors)
        if config is not None and firebase is not None:
            errors.extend(production_issues(config, firebase, bundle_id))
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--production", action="store_true",
                        help="Also require real, mutually consistent Firebase and support configuration.")
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    args = parser.parse_args()
    errors = validate(args.root, args.production, args.bundle_id)
    for error in errors:
        print(f"error: {error}")
    if errors:
        return 1
    mode = "Production configuration" if args.production else "Repository privacy and entitlement"
    print(f"{mode} checks passed. Signing, service access and device tests are separate checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
