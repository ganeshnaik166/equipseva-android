# Isolated UI smoke scaffold

This opt-in target builds the production source tree into a separate package,
`com.equipseva.app.uismoke`, but mounts only `UiSmokeHostActivity` with placeholder
Compose content. It does not yet mount Home, navigation, repositories or an account.

```sh
./gradlew -PuiSmoke=true :app:assembleUiSmoke :app:assembleUiSmokeAndroidTest
python -B -m unittest discover -s app/src/uiSmoke -p test_manifest_preflight.py -v
python app/src/uiSmoke/verify_packaged_manifests.py \
  --apkanalyzer "$ANDROID_HOME/cmdline-tools/latest/bin/apkanalyzer" \
  --target-apk app/build/outputs/apk/uiSmoke/app-uiSmoke.apk \
  --test-apk app/build/outputs/apk/androidTest/uiSmoke/app-uiSmoke-androidTest.apk
```

On Windows use `gradlew.bat` and `apkanalyzer.bat`. The preflight reads the actual
APK manifests using the Android SDK tool, checks a closed allowlist, and reports
both APK hashes. It does not infer device UIDs or network behavior from package names.

Without the exact `-PuiSmoke=true` property the build type is absent; normal debug,
release and AndroidJUnitRunner configuration stays in use. With the property,
instrumentation Kotlin sources come only from `src/androidTest/uiSmoke/kotlin`.
The existing production `SmokeFlowTest` is excluded. Do not combine this opt-in
invocation with normal debug/release test tasks.

Both manifests remove every requested permission, startup provider, service,
receiver, intent filter and inherited metadata entry. The target allows exactly:

- Nonexported `com.equipseva.app.uismoke.UiSmokeHostActivity`.
- Nonexported `androidx.test.core.app.InstrumentationActivityInvoker$EmptyActivity`,
  required by ActivityScenario teardown. It lives in the target UID; the other
  AndroidX bootstrap/floating helpers remain excluded.

The allowed EmptyActivity is a reviewed test-framework exception: it registers a
temporary exported runtime receiver for the framework's finish signal and sends
an unscoped lifecycle broadcast announcing that it has resumed. The received
finish signal only finishes that test activity; it exposes no production route or
data access. Its same-UID placement does not confine these broadcasts to that UID.
Run tests serially on a dedicated isolated emulator with no untrusted apps or
other concurrent tests, so another process cannot interfere with those lifecycle
signals. The receiver is removed when the activity is destroyed.

The test APK has no components and uses only `UiSmokeRunner`, targeting the isolated
package. A plain Application is the target fallback; the runner substitutes
HiltTestApplication. The host checks its package, application and denied INTERNET
permission before mounting. Supabase, Google, Maps and Sentry BuildConfig fields
are blank for this variant. Google Services/Crashlytics variant tasks are disabled,
and the Sentry plugin ignores this build type. SDK classes remain in the APK; their
presence is not evidence that initialization occurred.

Installation, actual UID separation, runtime permissions, Hilt/Compose startup and
teardown, and device rendering still need an isolated-device run. No test in this
scaffold establishes Home/navigation, TalkBack, authentication, Storage, Room,
payment or production-backend acceptance. Real Home fixtures must install strict
network/realtime/telemetry/worker boundaries before mounting the real graph.
