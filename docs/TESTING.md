# EquipSeva — Test Authoring Guide

A short, opinionated walkthrough of the test infrastructure we've built up across PRs #925 — #930. Read this before adding a new test so you pick the cheapest category that gives the coverage you actually need.

## Three test categories

| Category | Source set | Runner | Speed | Use when |
|---|---|---|---|---|
| **Pure JUnit** | `app/src/test/` | `JUnit4` (implicit) | ~5-20ms / test | Pure helpers, DTO mappers, validators, sealed-type folds, derived `UiState` properties. The bulk of the test suite. |
| **Robolectric (no Hilt)** | `app/src/test/` | `RobolectricTestRunner` | ~500ms - 3s / test | Code that genuinely needs an Android `Context` (DataStore, NotificationManager, PackageManager) but no DI. |
| **Robolectric + Hilt** | `app/src/test/` | `RobolectricTestRunner` + `HiltAndroidTest` | ~3-10s / test | Repository tests that need the real Hilt graph (e.g. `UserPrefs` resolves Context + SecurePrefs). |
| **Compose UI (Robolectric)** | `app/src/test/` | `RobolectricTestRunner` + `createComposeRule` | ~500ms - 2s / test | Composable smoke tests — verifies labels render + click handlers fire. |
| **Instrumented** | `app/src/androidTest/` | `AndroidJUnit4` | Emulator-bound | E2E flows + things that need the real OS surface (file picker intents, etc.). |

**Default to pure JUnit.** A pure-helper extraction is almost always cheaper than the test it would replace.

## Pattern: pure JUnit

```kotlin
class FooHelperTest {
    @Test fun `name describes the behaviour`() {
        assertEquals("expected", fooHelper("input"))
    }
}
```

When the logic lives inside a `private fun` on a class with injected deps, **extract it** to a top-level `internal fun` in the same file and have the original call site delegate. The wave-2 backfill (PR #926) has ~40 examples of this — search for `internal fun` in `features/` to see the pattern. Behaviour is unchanged; the test gets a cheap target.

KDoc on each test should explain **why** the assertion matters (what bug it catches), not what the code does. Code names already say what.

## Pattern: Robolectric without Hilt

For code that needs an Android `Context` but not the full DI graph — force a vanilla Application so Robolectric doesn't boot the prod `EquipSevaApplication`'s Hilt graph + a real `SupabaseClient` (which can't initialise on the JVM).

```kotlin
@RunWith(RobolectricTestRunner::class)
@Config(
    application = android.app.Application::class,
    manifest = Config.NONE,
)
class FooTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    // ... drive Context-dependent code ...
}
```

See `UserPrefsThemeRobolectricTest` for a working example.

## Pattern: Robolectric + Hilt

When you need real instances from the Hilt graph (typically a repository that depends on `Context` + other Hilt-bound deps):

```kotlin
@HiltAndroidTest
@RunWith(RobolectricTestRunner::class)
@Config(application = HiltTestApplication::class)
class FooRepositoryTest {

    @get:Rule
    val hiltRule = HiltAndroidRule(this)

    @Inject lateinit var fooRepository: FooRepository

    @Before fun init() {
        hiltRule.inject()
    }

    @Test fun `it works`() = runTest {
        // ...
    }
}
```

A fake `SupabaseClient` is already wired in via `TestSupabaseModule` (test source set) — `@TestInstallIn(replaces = [SupabaseModule::class])` swaps the real client for a relaxed MockK mock at SingletonComponent scope. Every `@Inject SupabaseClient` site across the graph gets the same mock instance per test class.

To swap a different binding (e.g. `AuthRepository`), use `@UninstallModules` + `@BindValue`:

```kotlin
@HiltAndroidTest
@UninstallModules(AuthModule::class)
@RunWith(RobolectricTestRunner::class)
@Config(application = HiltTestApplication::class)
class FooTest {

    @get:Rule val hiltRule = HiltAndroidRule(this)

    @BindValue @JvmField
    val authRepository: AuthRepository = FakeAuthRepository()

    // ...
}
```

`FakeAuthRepository` is a hand-rolled fake (not a MockK mock) — see `app/src/test/kotlin/com/equipseva/app/testing/FakeAuthRepository.kt` for the contract.

## Pattern: ViewModel tests

`@HiltViewModel` classes can't be `@Inject`'d directly into tests — Hilt requires `ViewModelProvider` / `SavedStateHandle`. Instead, instantiate the VM with a plain Kotlin constructor:

```kotlin
class FooViewModelTest {
    private lateinit var fake: FakeAuthRepository
    private lateinit var viewModel: FooViewModel

    @Before fun setUp() {
        // viewModelScope dispatches on Dispatchers.Main; redirect to a
        // TestDispatcher so the launched coroutines surface to runTest.
        Dispatchers.setMain(StandardTestDispatcher())
        fake = FakeAuthRepository()
        viewModel = FooViewModel(fake)
    }

    @After fun tearDown() { Dispatchers.resetMain() }

    @Test fun `does the thing`() = runTest {
        viewModel.onSubmit()
        val final = viewModel.state.first { !it.submitting }
        // assertions ...
    }
}
```

`ForgotPasswordViewModelTest` + `ChangePasswordViewModelTest` are working examples.

**Don't** combine the Hilt-graph pattern with VM injection — you'll hit `ViewModelValidationPlugin` errors. Either inject just the dependencies and construct the VM by hand, or inject `UserPrefs` / `Context` and construct the VM with the injected deps + the rest as fakes.

## Pattern: Compose UI

For composables that don't navigate, `createComposeRule()` is enough:

```kotlin
@RunWith(RobolectricTestRunner::class)
@Config(application = android.app.Application::class)
class FooUiTest {

    @get:Rule val composeRule = createComposeRule()

    @Composable
    private fun Themed(content: @Composable () -> Unit) {
        MaterialTheme { content() }
    }

    @Test fun `renders the label`() {
        composeRule.setContent { Themed { Foo(label = "Hello") } }
        composeRule.onNodeWithText("Hello").assertIsDisplayed()
    }
}
```

Always wrap composables in `MaterialTheme { ... }` — many design-system components read `MaterialTheme.colorScheme` for tones and will crash on first paint without a provider.

Stick to **text + click action + enabled state** assertions. Pixel-level checks belong in screenshot tests (separate follow-up).

See `StatusPillUiTest` / `StatusChipUiTest` / `EmptyStateViewUiTest` / `PrimaryButtonUiTest` for working examples.

## Anti-patterns to avoid

- **Don't write end-to-end VM tests that pull in real `viewModelScope.launch` + real `DataStore` writes.** The dispatcher coordination between `runTest`, `Dispatchers.setMain`, and `viewModelScope` is fragile — we tried this once on `NotificationSettingsViewModel` and it timed out. If the helper is pure, extract it to a top-level fn; if it's coroutine wiring, instrumented tests on an emulator are more reliable.

- **Don't pin pixel values in Compose tests.** Screen sizes vary; theme tokens evolve. Pin labels + roles + content descriptions; leave pixels for screenshot tests.

- **Don't pin a class name to identify a MockK mock** (e.g. `assert(client::class.java.name == "MockKProxy...")`). MockK's proxy class hierarchy isn't a public contract; use behavior assertions (`coEvery { ... } returns ...`) instead.

- **Don't write a Robolectric test when pure JUnit would do.** Robolectric tests are 100-1000x slower; reserve them for surfaces that genuinely need `Context`.

## Running tests

```bash
# Full unit test suite (pure JUnit + Robolectric)
./gradlew :app:testDebugUnitTest

# A single test class
./gradlew :app:testDebugUnitTest --tests "com.equipseva.app.features.foo.FooTest"

# A single test method
./gradlew :app:testDebugUnitTest --tests "com.equipseva.app.features.foo.FooTest.it does the thing"

# Verify the app still assembles after a refactor
./gradlew :app:assembleDebug
```

The HTML report lands at `app/build/reports/tests/testDebugUnitTest/index.html`.
