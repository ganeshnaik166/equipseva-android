# EquipSeva P1d-1 remote device-token claim/release: read-only preparation

26 September 2026. Source inspected in `codex/p1d0-main-20260926` at `df42167d8973372146fe377092526f2c48d96caf`, with the separate P1c candidate at `19b909aa9989f35f447ec8c333d6052c580d9243`. This is an inventory and proposed contract, not migration acceptance. No live Supabase, FCM, credentials, production rows, Gradle, or device was accessed; no repository file was changed.

## Repository evidence

- `supabase/migrations/20260428320000_security_revoke_delete_grants.sql:1-15,29` says no client DELETE path is legitimate and revokes `DELETE` on `public.device_tokens` from `authenticated, anon`. A tracked-migration search finds no `CREATE TABLE`, token unique key, table RLS policy, later direct `GRANT`, or claim/release RPC for `device_tokens`. The actual deployed schema and grants remain **unverified**.
- Main-line `app/src/main/kotlin/com/equipseva/app/core/push/DeviceTokenRegistrar.kt:51-79` caches the installation token, then performs a token-filtered authenticated DELETE before upsert inside one `runCatching`. If DELETE is denied, upsert is skipped and the error is swallowed. `:89-104` DELETEs by `(user_id, token)` on logout and then clears the local cache. `SessionViewModel.kt:55-77` invokes `refresh()` on observed sign-in; `EquipSevaMessagingService.kt:39-41` invokes `register(token)` on FCM rotation. Both registration paths need the eventual claim API.
- Main-line `SessionViewModel.kt:57-69` filters out `SignedOut` **before** `distinctUntilChangedBy { it.userId }`: an A→signed-out→A transition with no intervening different user can suppress the second A registration entirely. Its collector also awaits token refresh at `:69-77` before profile bootstrap, so slow token I/O blocks session presentation. The separate P1c candidate uses an exact `Login(userId, generation)` and a separate `tokenJob` (`SessionViewModel.kt:57,192-208,328-340`); preserve that behavior when integrating without assuming it exists on main.
- Adjacent **auth-routing limitation, not solved by P1d-1 alone:** main-line `SessionViewModel.kt:183-274` fetches the profile then has no after-fetch exact-login ownership check before deleted-account cleanup/sign-out at `:197-234` or role/onboarding writes at `:248-270`. A stale A result could mutate B's presentation/state. Freeze a separate test-first session/bootstrap slice for this boundary; do not fold unreviewed auth behavior into the token SQL migration.
- The separate P1c candidate `DeviceTokenRegistrar.kt:105-127,167-186` captures the departing local login ticket and token, but still remotely DELETEs by `(user_id, token)` without a claim revision; `SignOutCleanup.kt:75-87,131-132` performs capture before local work and revoke last. P1c's local result does not prove remote removal. Its Room `DeviceTokenEntity.kt:6-12` has one installation cache row; `DeviceTokenDao.kt:8-17` is not the server schema.
- The P1d-0 sender `supabase/functions/send_push_notification/index.ts:243-265` re-fetches the notification under service role and selects up to ten `device_tokens` rows by recipient, ordered by `updated_at`, requesting only `id, token`. `:283-320` builds generic/allow-listed payloads and deliberately does **no token-only invalid-token reap**. Stale rows may consume the ten-slot fanout until a versioned reap exists. `supabase/migrations/20260425020000_notifications_push_dispatch_trigger.sql:47-103` defines notification trigger wiring, but source does not prove that trigger, GUCs or Edge revision are deployed.
- Account erasure's SECURITY DEFINER `delete_my_account` deletes all of its user's token rows (`20260424120000_delete_my_account.sql:32-62`); it is not a per-device logout RPC.

## Minimum authorized deployed snapshot

Run the following **only through an authorized read-only database session**. Inspect the project/environment out of band. Do not paste token or user values, connection strings, role secrets, or raw rows into tickets or Git. If `to_regclass` returns null, stop and investigate the environment before running table-specific queries. These queries return aggregate counts and restricted metadata only; they have **not** been run here. Metadata is **not automatically non-secret**: default expressions, index/constraint/trigger definitions, RLS predicates, function body and `proconfig` can embed literals, URLs or credentials. The shareable query below omits free-form definitions. Any needed full definitions must be inspected only in the authorized SQL editor and manually reduced to an allowlisted handoff of column names/types, booleans, constraint/policy kind, and redacted rule semantics. Never copy raw results, screenshots or query logs into the repo or model memory; redact string literals, URLs, GUC values and identifiers beyond role names before review.

```sql
BEGIN READ ONLY;

SELECT to_regclass('public.device_tokens') AS token_table;
SELECT version FROM supabase_migrations.schema_migrations
WHERE version = '20260428320000';

SELECT a.attname AS column_name,
       format_type(a.atttypid, a.atttypmod) AS data_type,
       a.attnotnull AS not_null,
       (d.oid IS NOT NULL) AS has_default
FROM pg_attribute a
JOIN pg_class t ON t.oid = a.attrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
WHERE n.nspname = 'public' AND t.relname = 'device_tokens'
  AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY a.attnum;

SELECT c.conname, c.contype, c.conkey AS attribute_numbers,
       c.condeferrable, c.condeferred
FROM pg_constraint c
WHERE c.conrelid = 'public.device_tokens'::regclass;
SELECT ci.relname AS index_name, i.indisunique, i.indisprimary,
       i.indkey::text AS attribute_numbers,
       (i.indexprs IS NOT NULL) AS expression_index,
       (i.indpred IS NOT NULL) AS partial_index
FROM pg_index i JOIN pg_class ci ON ci.oid = i.indexrelid
WHERE i.indrelid = 'public.device_tokens'::regclass;
SELECT t.relrowsecurity, t.relforcerowsecurity, t.relowner::regrole AS table_owner
FROM pg_class t WHERE t.oid = 'public.device_tokens'::regclass;
SELECT policyname, cmd, roles,
       (qual IS NOT NULL) AS has_using,
       (with_check IS NOT NULL) AS has_with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'device_tokens';
SELECT tgname, tgfoid::regproc AS trigger_function, tgenabled FROM pg_trigger
WHERE tgrelid = 'public.device_tokens'::regclass AND NOT tgisinternal;

SELECT rolname,
       has_table_privilege(rolname, 'public.device_tokens', 'SELECT') AS can_select,
       has_table_privilege(rolname, 'public.device_tokens', 'INSERT') AS can_insert,
       has_table_privilege(rolname, 'public.device_tokens', 'UPDATE') AS can_update,
       has_table_privilege(rolname, 'public.device_tokens', 'DELETE') AS can_delete
FROM pg_roles WHERE rolname IN ('anon', 'authenticated', 'service_role')
ORDER BY rolname;
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS arguments,
       p.prosecdef AS security_definer,
       (p.proconfig IS NOT NULL) AS has_function_config,
       has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_execute
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN
  ('claim_device_token', 'release_device_token', 'reap_device_token');

SELECT count(*) AS total_rows,
       count(DISTINCT token) AS distinct_nonnull_tokens,
       count(*) FILTER (WHERE token IS NULL OR btrim(token::text) = '') AS null_or_blank_tokens,
       count(*) FILTER (WHERE user_id IS NULL) AS null_owners
FROM public.device_tokens;
WITH token_groups AS (
  SELECT token, count(*) AS rows_per_token,
         count(DISTINCT user_id) AS distinct_owners
  FROM public.device_tokens
  WHERE token IS NOT NULL AND btrim(token::text) <> ''
  GROUP BY token
)
SELECT count(*) FILTER (WHERE rows_per_token > 1) AS duplicate_token_groups,
       coalesce(sum(rows_per_token - 1) FILTER (WHERE rows_per_token > 1), 0) AS extra_rows,
       count(*) FILTER (WHERE distinct_owners > 1) AS cross_owner_groups,
       coalesce(max(rows_per_token), 0) AS max_rows_per_token
FROM token_groups;

ROLLBACK;
```

If the migration-history relation is unavailable to the read-only role, record that as **unknown**, not as proof the migration was unapplied. Current privileges are the authoritative grant observation. Full RLS/trigger/default/index/function definitions still require **private local inspection** to verify semantics; the booleans above cannot prove that a policy is safe. Check deployed Edge function revision and webhook trigger configuration through authorized **read-only provider metadata** without retrieving secret GUC values; the database queries alone cannot prove hosted sender parity or FCM delivery.

## Test-first P1d-1 contract

1. Freeze old-client rollout and token-possession model first. An authenticated caller must not transfer an arbitrary stolen FCM token merely by naming it. A possible design uses a **server-issued, token-bound challenge** delivered to the physical FCM token, with a short-lived one-use nonce bound to the authenticated *session*, token, installation credential and **observed current claim generation**. Reject a session already superseded by the token's committed current session **before issuing a challenge**; rate-limit begin/redeem calls and record only non-sensitive audit events. Critically, issuance is **non-authoritative**: it neither changes ownership, advances the generation nor blocks a proved current claim. An old A JWT that requests an unproved challenge, or an offline B challenge that never completes, must not fence or starve valid registration. App/device attestation alone is not token possession proof. This challenge is a design candidate, not a proven production FCM flow; validate background delivery and inaccessible-token behavior before adopting it. Do not restore broad table DELETE.
2. Define a **server-enforced current-login generation**, not a client-supplied counter. Only a successful proof-and-claim transaction may advance the authoritative per-token generation. Under a per-token lock it must consume the nonce and compare its bound expected generation, verified auth-session identity, token proof and prior claim revision against the **current committed** row (CAS), then atomically assign the next generation and opaque claim revision. B's successful claim therefore makes A's earlier nonce/expected generation stale; A-start→B-success→late-A must fail. A retry with A's still-valid but superseded JWT/old session must fail *before* issuing a new challenge; an already issued A challenge must fail the commit CAS. A can reclaim only after a genuinely new authenticated login with a new server-verifiable session order and fresh possession proof. Whether Supabase exposes a reliable session identifier and creation order must be verified in the disposable/auth environment. If it cannot, choose a different server-verifiable session-fencing mechanism before implementation. A mere unique-token last-writer-wins upsert, fresh UUID, client generation, or generation bump on challenge issuance cannot enforce this.
3. In a disposable PostgreSQL baseline matching the observed schema, write failing **role/RLS negative tests**: anon/unauthenticated RPC EXECUTE denied; authenticated direct DELETE denied; direct INSERT/UPDATE unable to bypass ownership; spoofed owner ignored or denied; null/expired/consumed/wrong-token nonce denied; bounded malformed token denied; stale session/epoch/revision rejected; wrong-owner release and stale sender reap affect zero rows; disabled/deleted account policy honored. Derive owner from `auth.uid()` inside narrowly granted SECURITY DEFINER RPCs with locked search path and reviewed owner privileges. Native role tests alone cannot prove JWT verification; add disposable PostgREST/JWT tests for that boundary.
4. Write **two-session** ordering tests before migration: A claim then B claim; same-user A logout/re-login; stale A release after B; old A **claim** started before B but committed after B; old A retry after B while A's old JWT remains valid; B→new-A login with a fresh session; simultaneous sign-in `refresh()` and FCM `onNewToken`; lost response/idempotent retry; process restart and concurrent release/reap. Specifically assert that an unproved A challenge request cannot advance generation or fence B, an offline/unredeemed B challenge cannot starve A, superseded A is denied a new challenge after B commits, and late A redemption of its earlier nonce fails CAS. Assert exactly one current claim and no stale mutation, not just matching HTTP codes.
5. Switch both Android registration entry points and logout only after the server contract is tested. P1d-1 acceptance on main also requires the **separately owned auth-routing slice** to replace its filtered/distinct signed-in observer so A→signed-out→A registers again, keep token refresh in a separate cancelable job, and fence profile/deleted-account effects after suspension. Do not claim the SQL/token slice by itself repairs that whole observer. Persist the returned opaque revision with its originating exact login ticket, verified auth session and request generation; reject late/noncooperative responses and rotation-order reversals. Retain the installation token on logout, and make 401/42501/offline release failures observable with bounded retry rather than claiming success. Cover cancellation, refresh/onNewToken overlap, token rotation, same-account re-login, A→B, restart, offline sign-out and recovery with synthetic tests. In the adjacent auth slice, assert slow refresh does not block a B event and late A profile/null/inactive results cannot write B's role/onboarding flags or sign B out.
6. Make sender lookup/reap version-safe after the server schema is known. Test ten stale rows ahead of a fresh claim so `.limit(10)` cannot starve valid delivery; then test a delayed FCM `UNREGISTERED` against a newer claim of the same token so reap affects zero fresh rows. Test selected recipient, generic foreground/background content, webhook retry and old-client residual rows. Finish with a controlled provider/device pilot; generic P1d-0 text limits disclosure but cannot unsend a push already in flight.

**Next decision:** obtain the read-only metadata/count snapshot or a faithful disposable baseline and choose the token-possession/fencing contract. Until then, P1d-1 SQL, client integration, and production rollout remain blocked. No numeric acceptance score is warranted by this inventory.
