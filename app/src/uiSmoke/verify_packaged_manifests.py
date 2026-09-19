"""Fail closed on the two actual APK manifests; uses the Android SDK apkanalyzer.

python app/src/uiSmoke/verify_packaged_manifests.py --apkanalyzer PATH \
  --target-apk app/build/outputs/apk/uiSmoke/app-uiSmoke.apk \
  --test-apk app/build/outputs/apk/androidTest/uiSmoke/app-uiSmoke-androidTest.apk

This is a static package gate, not a device UID/network or UI acceptance test.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import xml.etree.ElementTree as ET

ANDROID = "{http://schemas.android.com/apk/res/android}"
TARGET = "com.equipseva.app.uismoke"
TEST = TARGET + ".test"
HOST = TARGET + ".UiSmokeHostActivity"
EMPTY_ACTIVITY = "androidx.test.core.app.InstrumentationActivityInvoker$EmptyActivity"
RUNNER = TARGET + ".UiSmokeRunner"
COMPONENTS = {"activity", "activity-alias", "provider", "receiver", "service"}


def check_manifest(xml, test=False):
    root = ET.fromstring(xml)
    expected_package = TEST if test else TARGET
    errors = []

    def require(ok, message):
        if not ok:
            errors.append(message)

    require(root.tag == "manifest", "Expected manifest root")
    require(root.get("package") == expected_package, "Wrong package identity")
    require(root.get(ANDROID + "sharedUserId") is None, "Shared UID is forbidden")
    permissions = [node.attrib for node in root if node.tag.startswith("uses-permission") or node.tag == "permission"]
    require(not permissions, "Permissions are forbidden")
    require(root.find("queries") is None, "External package queries are forbidden")
    applications = root.findall("application")
    require(len(applications) == 1, "Expected exactly one application")
    components = []
    if len(applications) == 1:
        app = applications[0]
        expected_app = {None, "android.app.Application"} if test else {"android.app.Application"}
        require(app.get(ANDROID + "name") in expected_app, "Unexpected application class")
        require(app.get(ANDROID + "backupAgent") is None, "Backup agent is forbidden")
        require(app.get(ANDROID + "process") is None, "Application process override is forbidden")
        require(app.get(ANDROID + "usesCleartextTraffic") != "true", "Cleartext override is forbidden")
        require(app.get(ANDROID + "appComponentFactory") in {None, "androidx.core.app.CoreComponentFactory"}, "Unexpected component factory")
        require(app.get(ANDROID + "allowBackup") == "false", "Backup must be disabled")
        for node in app:
            require(node.tag in COMPONENTS, "Unexpected application child: " + node.tag)
            if node.tag in COMPONENTS:
                components.append({"kind": node.tag, **node.attrib})
                require(not test and node.tag == "activity" and node.get(ANDROID + "name") in {HOST, EMPTY_ACTIVITY}, "Unexpected component")
                require(node.get(ANDROID + "exported") == "false", "Exported component is forbidden")
                require(node.get(ANDROID + "process") is None, "Additional process is forbidden")
                require(len(node) == 0, "Component metadata/intent filters are forbidden")
        names = sorted(node[ANDROID + "name"] for node in components if ANDROID + "name" in node)
        require(names == ([] if test else sorted([HOST, EMPTY_ACTIVITY])), "Wrong component identity/count")
    instrumentation = root.findall("instrumentation")
    require(len(instrumentation) == (1 if test else 0), "Wrong instrumentation count")
    if test and len(instrumentation) == 1:
        node = instrumentation[0]
        require(node.get(ANDROID + "name") == RUNNER, "Wrong runner")
        require(node.get(ANDROID + "targetPackage") == TARGET, "Wrong instrumentation target")
        require(node.get(ANDROID + "targetProcesses") in {None, TARGET}, "Unexpected instrumented processes")
    allowed_root = {"uses-sdk", "application", "instrumentation"}
    for node in root:
        require(node.tag in allowed_root, "Unexpected manifest child: " + node.tag)
    return {"package": root.get("package"), "permissions": permissions,
            "components": components, "instrumentation": [node.attrib for node in instrumentation],
            "errors": errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apkanalyzer", required=True, type=Path)
    parser.add_argument("--target-apk", required=True, type=Path)
    parser.add_argument("--test-apk", required=True, type=Path)
    args = parser.parse_args()
    reports = []
    for apk, test in ((args.target_apk, False), (args.test_apk, True)):
        apk = apk.resolve(strict=True)
        result = subprocess.run([str(args.apkanalyzer.resolve(strict=True)), "manifest", "print", str(apk)],
                                capture_output=True, text=True, encoding="utf-8", timeout=60, check=True)
        report = check_manifest(result.stdout, test)
        report.update({"apk": str(apk), "sha256": hashlib.sha256(apk.read_bytes()).hexdigest()})
        reports.append(report)
    passed = all(not report["errors"] for report in reports)
    print(json.dumps({"passed": passed, "scope": "packaged manifest only", "apks": reports}, indent=2))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
