# SignUp footer after A3 main — independent QA, 27 September 2026

**9.6/10: local scoped UI pass, no mandatory source blocker.** Reviewed clean
merge head `e02af65564c49a4740b2d4dce4a4357900e7382f` against accepted A3
main `3283ab55164f6af2593ec557ec243342dd466d0c`. The only app/test
delta from main is `SignUpScreen.kt`'s Sign in footer and the new
`SignUpFooterTargetTest.kt`. Their blobs exactly match the earlier locally
accepted SignUp code at `1e62b7cd` (`854f6bf7` and `66326ba4`). The merged
`DeepLinkPolicy.kt` and `DeepLinkRouter.kt` blobs exactly match A3 main.

Five combined target suites passed **23/0**. I independently counted the
exact-head JUnit XML: **2,930 tests / 346 suites / 0 failures, errors or
skips**. Lint XML records **0 errors / 87 warnings / 2 hints**. The
coordinator's combined Gradle command exited 0 after unit tests, lint,
debug assembly and unsigned release R8 assembly. The design ratchet exited
0. These are local synthetic/source checks, not a signed or shipped release.

The footer has a 48dp minimum width and height, `Role.Button`, a stacked
prompt/link for 320×420dp at 200% text, and the same existing `onSignIn`
callback. No overlapping A3 app source changed. Hosted PR CI and main
integration remain mandatory. Physical device/TalkBack, dark rendered review
and provider signup are unverified. The footer remains clickable during an
in-flight signup, as before; the separate auth/session identity work must
resolve that race before any broad auth-security claim. This score accepts
only the bounded footer/navigation UI slice.
