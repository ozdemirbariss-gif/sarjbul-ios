import copy
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from validate_release import ROOT, USER_DEFAULTS, manifest_issues, production_issues


def configuration():
    return (
        {
            "firebaseAPIKey": "fixture-key-never-used-on-network",
            "firebaseBackendReady": True,
            "commercialDataUseApproved": True,
            "firebaseDatabaseURL": "https://fixture-default-rtdb.europe-west1.firebasedatabase.app/",
            "stationTileManifestURL": "https://fixture.invalid/station-tiles-manifest.json",
            "privacyPolicyURL": "https://fixture.invalid/privacy",
            "termsOfUseURL": "https://fixture.invalid/terms",
            "supportURL": "https://fixture.invalid/support",
            "supportEmail": "support@fixture.invalid",
        },
        {
            "BUNDLE_ID": "com.ozdemirbaris.sarjbul",
            "API_KEY": "fixture-key-never-used-on-network",
            "GOOGLE_APP_ID": "1:123456:ios:aabbcc",
            "GCM_SENDER_ID": "123456",
            "PROJECT_ID": "fixture",
        },
    )


class ReleaseValidationTests(unittest.TestCase):
    def test_commercial_release_requires_provider_rights_review(self):
        config, firebase = configuration()
        config.pop("commercialDataUseApproved")
        self.assertTrue(production_issues(config, firebase))
        for value in (False, "true", 1, None):
            with self.subTest(value=value):
                self.assertTrue(production_issues({**config, "commercialDataUseApproved": value}, firebase))

    def test_plist_credentials_alone_do_not_mark_backend_ready(self):
        config, firebase = configuration()
        config.pop("firebaseBackendReady")
        self.assertTrue(production_issues(config, firebase))
        for value in (False, "true", 1, None):
            with self.subTest(value=value):
                self.assertTrue(production_issues({**config, "firebaseBackendReady": value}, firebase))

    def test_matching_configuration_is_accepted_without_network_access(self):
        config, firebase = configuration()
        self.assertEqual(production_issues(config, firebase), [])

    def test_configuration_from_another_app_is_rejected(self):
        config, firebase = configuration()
        for key, value in (
            ("BUNDLE_ID", "com.another.app"),
            ("API_KEY", "different-key"),
            ("GCM_SENDER_ID", "999"),
            ("GOOGLE_APP_ID", "1:123456:android:aabbcc"),
            ("DATABASE_URL", "https://other.firebaseio.com"),
        ):
            with self.subTest(key=key):
                changed = {**firebase, key: value}
                self.assertTrue(production_issues(config, changed))

    def test_database_can_use_regional_host_and_trailing_slash(self):
        config, firebase = configuration()
        firebase["DATABASE_URL"] = config["firebaseDatabaseURL"].rstrip("/")
        self.assertEqual(production_issues(config, firebase), [])

    def test_insecure_missing_and_placeholder_inputs_are_rejected(self):
        config, firebase = configuration()
        for key, value in (
            ("firebaseAPIKey", ""),
            ("firebaseDatabaseURL", "https://fixture-default-rtdb.firebaseio.com/users.json"),
            ("firebaseDatabaseURL", "http://fixture-default-rtdb.firebaseio.com"),
            ("firebaseDatabaseURL", "https://fixture-default-rtdb.firebaseio.com.evil.invalid"),
            ("supportURL", "https://user:password@fixture.invalid"),
            ("supportURL", "http://fixture.invalid/support"),
            ("supportURL", "https://localhost/support"),
            ("supportURL", "https://example.com/support"),
            ("supportEmail", "not-an-email"),
            ("supportEmail", ""),
            ("stationTileManifestURL", "YOUR_MANIFEST"),
        ):
            with self.subTest(key=key, value=value):
                self.assertTrue(production_issues({**config, key: value}, firebase))

    def test_validation_errors_never_print_credentials(self):
        config, firebase = configuration()
        config["firebaseAPIKey"] = "credential-must-not-be-logged"
        config["supportURL"] = "https://private-user:private-password@fixture.invalid"
        output = "\n".join(production_issues(config, firebase))
        for secret in ("credential-must-not-be-logged", "private-user", "private-password"):
            self.assertNotIn(secret, output)

    def test_shared_defaults_reason_cannot_be_replaced_by_private_defaults(self):
        manifest = {
            "NSPrivacyTracking": False,
            "NSPrivacyTrackingDomains": [],
            "NSPrivacyAccessedAPITypes": [{
                "NSPrivacyAccessedAPIType": USER_DEFAULTS,
                "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
            }],
        }
        self.assertTrue(manifest_issues(manifest, {"1C8F.1"}, "widget"))
        fixed = copy.deepcopy(manifest)
        fixed["NSPrivacyAccessedAPITypes"][0]["NSPrivacyAccessedAPITypeReasons"].append("1C8F.1")
        self.assertEqual(manifest_issues(fixed, {"1C8F.1"}, "widget"), [])

    def test_repository_check_passes_but_missing_production_files_block_release(self):
        # These source-controlled files are enough for CI, but never for an archive.
        paths = (
            "SarjBul/Resources/PrivacyInfo.xcprivacy",
            "SarjBulWidgets/PrivacyInfo.xcprivacy",
            "SarjBul/SarjBul.entitlements",
            "SarjBulWidgets/SarjBulWidgets.entitlements",
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for relative in paths:
                destination = root / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes((ROOT / relative).read_bytes())
            command = [sys.executable, str(ROOT / "Scripts/validate_release.py"), "--root", str(root)]
            result = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stdout)
            result = subprocess.run(command + ["--production"], capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertIn("AppConfig.plist", result.stdout)
            self.assertIn("GoogleService-Info.plist", result.stdout)
            for filename in ("AppConfig.plist", "GoogleService-Info.plist"):
                with (root / "SarjBul/Resources" / filename).open("wb") as target:
                    plistlib.dump([], target)
            result = subprocess.run(command + ["--production"], capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()
