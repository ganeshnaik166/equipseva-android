"""Mutation tests for the fail-closed packaged manifest allowlist."""
import unittest
from verify_packaged_manifests import check_manifest


class ManifestPreflightTest(unittest.TestCase):
    target = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.equipseva.app.uismoke">
      <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="35"/>
      <application android:name="android.app.Application" android:allowBackup="false">
        <activity android:name="com.equipseva.app.uismoke.UiSmokeHostActivity" android:exported="false"/>
        <activity android:name="androidx.test.core.app.InstrumentationActivityInvoker$EmptyActivity" android:exported="false"/>
      </application></manifest>'''
    test = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="com.equipseva.app.uismoke.test">
      <uses-sdk/><instrumentation android:name="com.equipseva.app.uismoke.UiSmokeRunner" android:targetPackage="com.equipseva.app.uismoke"/>
      <application android:allowBackup="false"/></manifest>'''

    def test_allowed_packages(self):
        self.assertEqual([], check_manifest(self.target)["errors"])
        self.assertEqual([], check_manifest(self.test, True)["errors"])

    def test_permission_in_either_apk_is_rejected(self):
        for source, is_test in ((self.target, False), (self.test, True)):
            for tag in ("uses-permission", "uses-permission-sdk-23", "permission"):
                with self.subTest(test_apk=is_test, tag=tag):
                    changed = source.replace("<uses-sdk", '<' + tag + ' android:name="android.permission.INTERNET"/><uses-sdk')
                    self.assertTrue(check_manifest(changed, is_test)["errors"])

    def test_component_or_metadata_injection_is_rejected(self):
        for addition in ('<provider android:name="FirebaseInitProvider"/>', '<service android:name="worker"/>',
                         '<receiver android:name="push"/>', '<meta-data android:name="io.sentry"/>',
                         '<activity android:name="com.equipseva.app.MainActivity" android:exported="false"/>'):
            with self.subTest(addition=addition):
                self.assertTrue(check_manifest(self.target.replace('</application>', addition + '</application>'))["errors"])

    def test_wrong_identity_export_or_application_is_rejected(self):
        for changed in (self.target.replace('package="com.equipseva.app.uismoke"', 'package="com.equipseva.app.debug"'),
                        self.target.replace('android:exported="false"', 'android:exported="true"'),
                        self.target.replace('android.app.Application', 'com.equipseva.app.EquipSevaApplication'),
                        self.target.replace('<uses-sdk', '<queries/><uses-sdk'),
                        self.target.replace('<uses-sdk', '<uses-library android:name="unexpected"/><uses-sdk')):
            with self.subTest(changed=changed):
                self.assertTrue(check_manifest(changed)["errors"])

    def test_instrumentation_target_or_runner_drift_is_rejected(self):
        self.assertTrue(check_manifest(self.test.replace('android:targetPackage="com.equipseva.app.uismoke"',
                                                         'android:targetPackage="com.equipseva.app.debug"'), True)["errors"])
        self.assertTrue(check_manifest(self.test.replace('.UiSmokeRunner', '.OtherRunner'), True)["errors"])

    def test_shared_uid_or_host_intent_is_rejected(self):
        self.assertTrue(check_manifest(self.target.replace(
            'package="com.equipseva.app.uismoke"', 'package="com.equipseva.app.uismoke" android:sharedUserId="android.uid.system"'))["errors"])
        changed = self.target.replace('android:exported="false"/>', 'android:exported="false"><intent-filter/></activity>')
        self.assertTrue(check_manifest(changed)["errors"])

    def test_helper_is_exact_nonexported_and_cannot_replace_host(self):
        for changed in (
            self.target.replace('$EmptyActivity', '$BootstrapActivity'),
            self.target.replace('$EmptyActivity', '$EmptyFloatingActivity'),
            self.target.replace('android:exported="false"', 'android:exported="true"'),
            self.target.replace('com.equipseva.app.uismoke.UiSmokeHostActivity', 'androidx.test.core.app.InstrumentationActivityInvoker$EmptyActivity'),
        ):
            with self.subTest(changed=changed):
                self.assertTrue(check_manifest(changed)["errors"])


if __name__ == "__main__":
    unittest.main()
