-- Round 7: add WITH_CHECK to profiles UPDATE policy.
--
-- Round 4+6 swept the 18 tables flagged in the original audit, but the
-- broader pg_policies scan afterward surfaced one more gap: `profiles` has
-- an UPDATE policy `auth.uid() = id` with NO WITH_CHECK.
--
-- The guard_profile_self_escalation trigger (PR #137) blocks role /
-- role_confirmed / organization_id changes by non-admins — but it does NOT
-- block `id` changes. Without WITH_CHECK, a malicious user who passes the
-- USING check on their own row could attempt to SET id = <other_uuid>.
--
-- In practice the primary-key constraint stops the clearest takeover
-- attempts (collision if the victim has an existing profile row). But
-- there are edge cases around freshly-created accounts with no profile row
-- yet, and the WITH_CHECK is pure defense-in-depth: closes the entire
-- class of id-flip attempts regardless of whether the PK happens to catch
-- them.
--
-- The profile self-escalation trigger remains the primary guard for
-- privilege escalation; this WITH_CHECK just ensures the row's identity
-- column can't drift out from under it.

ALTER POLICY "Users can update own profile" ON public.profiles
  WITH CHECK (auth.uid() = id);
