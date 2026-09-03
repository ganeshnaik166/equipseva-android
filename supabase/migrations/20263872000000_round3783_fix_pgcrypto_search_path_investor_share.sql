-- =====================================================================
-- Round 3783 — the whole investor-share feature was broken (pgcrypto)
-- =====================================================================
--
-- All three functions of the token-gated investor-share feature raise
-- `42883: function digest(text, unknown) does not exist`:
--
--   founder_mint_investor_share_token(text,int,int)  -- founder mints a link
--   investor_share_v2(text)                          -- investor opens it
--   read_investor_brief_via_token(text,text)         -- investor reads the brief
--
-- ROOT CAUSE: pgcrypto is installed in the `extensions` schema on
-- Supabase (verified: SELECT n.nspname FROM pg_proc p JOIN pg_namespace n
-- ... WHERE p.proname='digest'  -->  extensions, 2 overloads). All three
-- functions are correctly hardened with `SET search_path = public,
-- pg_temp` — which is the right security posture — but that pin
-- deliberately EXCLUDES `extensions`, so a bare `digest(...)` call
-- cannot resolve. The functions were presumably authored and tested in
-- an environment where pgcrypto lived in `public`.
--
-- Net effect: the founder cannot mint a working investor share link,
-- and no investor can open one — mint AND both read paths are dead.
-- Every token is hashed before storage (`digest(token,'sha256')`), so
-- the failure is on the very first statement that touches a token.
--
-- Note this is the SECOND independent fatal defect found in
-- read_investor_brief_via_token: round563 previously fixed it
-- referencing `rj.category`, a column that does not exist on
-- repair_jobs. Fixing that one simply exposed this one behind it —
-- the same "one bug masks the next" pattern seen tonight in
-- profitability_for_repair_bid (round3781).
--
-- FIX: schema-qualify the call as `extensions.digest(...)`. This keeps
-- the hardened search_path intact — the alternative (adding
-- `extensions` to search_path) would widen resolution for every other
-- identifier in these SECURITY DEFINER bodies, which is exactly the
-- hazard the pin exists to prevent.
--
-- WHY THIS MIGRATION REWRITES PROGRAMMATICALLY RATHER THAN RETYPING
-- THE BODIES: each function contains EXACTLY ONE bare pgcrypto call
-- (asserted below before any rewrite happens). These are
-- security-sensitive token-hashing and token-validation bodies totalling
-- ~280 lines; hand-retranscribing them to change one token per function
-- risks a silent transcription error in exactly the code that decides
-- whether an unauthenticated caller may read investor financials.
-- Instead we take the authoritative definition from
-- pg_get_functiondef() — which preserves the signature, volatility,
-- SECURITY DEFINER flag and the search_path pin verbatim — requalify
-- the single call, and assert both before and after that the rewrite
-- did exactly what was intended. The assertions make this strictly
-- safer than a manual edit, not looser.

BEGIN;

DO $$
DECLARE
  v_fn        text;
  v_oid       oid;
  v_def       text;
  v_new       text;
  v_before    int;
  v_after     int;
  -- Matches a `digest(` / `crypt(` / `hmac(` / `gen_salt(` call that is
  -- NOT already schema-qualified and NOT part of a longer identifier
  -- (so `payload_digest(`, `x.digest(` and `mydigest(` are all skipped).
  c_bare      text := '([^.[:alnum:]_])(digest|crypt|hmac|gen_salt)[[:space:]]*\(';
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'founder_mint_investor_share_token',
    'investor_share_v2',
    'read_investor_brief_via_token'
  ]
  LOOP
    SELECT p.oid INTO v_oid
      FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace
       AND p.proname = v_fn;
    IF v_oid IS NULL THEN
      RAISE EXCEPTION 'round 3783: function public.% not found', v_fn;
    END IF;

    v_def := pg_get_functiondef(v_oid);

    -- Guard 1: there must be exactly ONE bare pgcrypto call. If a future
    -- edit adds a second, this migration refuses to run rather than
    -- silently rewriting something it was never reviewed against.
    SELECT count(*) INTO v_before
      FROM regexp_matches(v_def, c_bare, 'g');
    IF v_before <> 1 THEN
      RAISE EXCEPTION
        'round 3783: expected exactly 1 bare pgcrypto call in public.%, found % — refusing to rewrite',
        v_fn, v_before;
    END IF;

    v_new := regexp_replace(v_def, c_bare, '\1extensions.\2(', 'g');

    -- Guard 2: the rewrite must have eliminated the bare call.
    SELECT count(*) INTO v_after
      FROM regexp_matches(v_new, c_bare, 'g');
    IF v_after <> 0 THEN
      RAISE EXCEPTION
        'round 3783: rewrite of public.% left % bare pgcrypto call(s) — refusing to apply',
        v_fn, v_after;
    END IF;

    -- Guard 3: the pinned search_path must survive verbatim. Losing it
    -- would be a security regression on a SECURITY DEFINER function.
    IF position('search_path' IN v_new) = 0 THEN
      RAISE EXCEPTION
        'round 3783: rewrite of public.% lost its search_path pin — refusing to apply', v_fn;
    END IF;

    EXECUTE v_new;
    RAISE NOTICE 'round 3783: requalified pgcrypto call in public.%', v_fn;
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------
-- Verification — exercise the read path for real, inside the txn
-- ---------------------------------------------------------------------
-- A deliberately bogus token must now produce a DOMAIN response (no
-- rows, or a "not found / expired" application error) rather than
-- 42883. Anything still raising 42883 means the requalification did not
-- take, and the migration aborts.
DO $$
DECLARE
  v_n int;
BEGIN
  BEGIN
    SELECT count(*) INTO v_n
      FROM public.investor_share_v2('round3783-definitely-not-a-real-token');
    RAISE NOTICE 'round 3783: investor_share_v2() executed OK (% rows for a bogus token)', v_n;
  EXCEPTION
    WHEN undefined_function THEN
      RAISE EXCEPTION 'round 3783 VERIFY FAILED: investor_share_v2 still cannot resolve digest()';
    WHEN OTHERS THEN
      -- An application-level rejection is the CORRECT outcome for a bogus
      -- token; only 42883 indicates the bug is still present.
      RAISE NOTICE 'round 3783: investor_share_v2() reached application logic (rejected bogus token with %) — digest() resolves', SQLSTATE;
  END;

  BEGIN
    SELECT count(*) INTO v_n
      FROM public.read_investor_brief_via_token('round3783-definitely-not-a-real-token', 'round3783-probe');
    RAISE NOTICE 'round 3783: read_investor_brief_via_token() executed OK (% rows for a bogus token)', v_n;
  EXCEPTION
    WHEN undefined_function THEN
      RAISE EXCEPTION 'round 3783 VERIFY FAILED: read_investor_brief_via_token still cannot resolve digest()';
    WHEN OTHERS THEN
      RAISE NOTICE 'round 3783: read_investor_brief_via_token() reached application logic (rejected bogus token with %) — digest() resolves', SQLSTATE;
  END;

  RAISE NOTICE 'round 3783 verified: investor-share mint + both read paths can resolve pgcrypto again';
END;
$$;

COMMIT;
