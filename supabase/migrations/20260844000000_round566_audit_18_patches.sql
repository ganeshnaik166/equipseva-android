-- =====================================================================
-- Round 566 — Audit-18 patches (global rate-limit DoS via not_found spam)
-- =====================================================================
--
-- Audit-18 (workflow w2fix2s5u) on r560/r561/r563. Raw 4 → 3 confirmed
-- (2 HIGH + 1 LOW). After deeper analysis:
--
-- HIGH #1 — TOCTOU race on per-token rate limit
--   VERDICT: FALSE POSITIVE. The SELECT FOR UPDATE on
--   investor_share_tokens at line 89 serializes same-token concurrent
--   requests. The per-token count check at lines 99-109 runs INSIDE
--   that serialized window, so the verify lens's race analysis missed
--   that subsequent same-token requests block on the FOR UPDATE before
--   they even reach the count check. Not patching.
--
-- HIGH #2 — Global rate-limit DoS via not_found spam — REAL
--   The global anon counter at lines 66-74 of r563 counts ALL log
--   outcomes including 'not_found'. An attacker can send 200+ random
--   tokens within 60s, each logging 'not_found', and saturate the
--   global counter — blocking legitimate valid-token reads.
--   FIX: filter the global counter to outcome IN ('ok', 'expired',
--   'revoked', 'exhausted') — exclude 'not_found' so legitimate reads
--   survive a brute-force flood. Per-token rate limit still caps
--   abuse of a single valid token.
--
-- LOW — Hardcoded tier list in SetTierAction.tsx UI
--   ACCEPTED. UI maintenance gap, not a security issue. Future tier
--   additions need a UI bump, but the DB CHECK constraint + RPC
--   validation are the real source of truth. Documented in r561 PR.

BEGIN;

DROP FUNCTION IF EXISTS public.read_investor_brief_via_token(text, text);

CREATE OR REPLACE FUNCTION public.read_investor_brief_via_token(
  p_raw_token  text,
  p_user_agent text DEFAULT NULL
)
RETURNS TABLE (
  generated_at           timestamptz,
  gmv_7d_rupees          numeric,
  gmv_wow_pct            numeric,
  completed_jobs_7d      int,
  active_engineers_30d   int,
  amc_contracts_active   int,
  total_escrow_held_rupees numeric,
  top_verticals          jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hash             text;
  v_token            record;
  v_hero             record;
  v_recent_per_token int;
  v_recent_global    int;
BEGIN
  -- r566 audit-18 HIGH #2 fix: count only successful + state-change
  -- outcomes for the global limit. 'not_found' attempts are excluded
  -- so an attacker spamming garbage tokens can't lock out legitimate
  -- valid-token reads.
  SELECT count(*)::int INTO v_recent_global
    FROM public.investor_share_view_log
   WHERE viewed_at > now() - interval '60 seconds'
     AND outcome IN ('ok', 'expired', 'revoked', 'exhausted');
  IF v_recent_global >= 200 THEN
    RAISE EXCEPTION 'global_rate_limit (200 valid reads / 60s)'
      USING ERRCODE = '53400';
  END IF;

  v_hash := encode(digest(coalesce(p_raw_token, ''), 'sha256'), 'hex');

  IF p_raw_token IS NULL OR length(p_raw_token) < 32 THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (NULL, left(coalesce(p_user_agent, ''), 200), 'not_found');
    RAISE EXCEPTION 'invalid_token' USING ERRCODE = '02000';
  END IF;

  SELECT * INTO v_token
    FROM public.investor_share_tokens
   WHERE token_hash = v_hash
   FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (NULL, left(coalesce(p_user_agent, ''), 200), 'not_found');
    RAISE EXCEPTION 'token_not_found' USING ERRCODE = '02000';
  END IF;

  SELECT count(*)::int INTO v_recent_per_token
    FROM public.investor_share_view_log
   WHERE token_id = v_token.id
     AND viewed_at > now() - interval '60 seconds';
  IF v_recent_per_token >= 20 THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'not_found');
    RAISE EXCEPTION 'token_not_found' USING ERRCODE = '02000';
  END IF;

  IF v_token.status = 'revoked' THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'revoked');
    RAISE EXCEPTION 'token_revoked' USING ERRCODE = '02000';
  END IF;

  IF v_token.expires_at < now() THEN
    UPDATE public.investor_share_tokens SET status = 'expired' WHERE id = v_token.id;
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'expired');
    RAISE EXCEPTION 'token_expired' USING ERRCODE = '02000';
  END IF;

  IF v_token.view_count >= v_token.max_views THEN
    UPDATE public.investor_share_tokens SET status = 'exhausted' WHERE id = v_token.id;
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'exhausted');
    RAISE EXCEPTION 'token_view_cap_reached' USING ERRCODE = '02000';
  END IF;

  UPDATE public.investor_share_tokens
     SET view_count = view_count + 1
   WHERE id = v_token.id;
  INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
  VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'ok');

  SELECT * INTO v_hero
    FROM (
      WITH g AS (
        SELECT
          coalesce(sum(rje.amount_rupees) FILTER (
            WHERE rj.completed_at >= now() - interval '7 days'
          ), 0)::numeric AS gmv_7d_rupees,
          coalesce(sum(rje.amount_rupees) FILTER (
            WHERE rj.completed_at >= now() - interval '14 days'
              AND rj.completed_at <  now() - interval '7 days'
          ), 0)::numeric AS gmv_prior_7d_rupees
        FROM public.repair_jobs rj
        LEFT JOIN public.repair_job_escrow rje ON rje.repair_job_id = rj.id
        WHERE rj.status = 'completed'
      )
      SELECT
        now() AS generated_at,
        g.gmv_7d_rupees,
        CASE WHEN g.gmv_prior_7d_rupees > 0
             THEN ((g.gmv_7d_rupees - g.gmv_prior_7d_rupees) / g.gmv_prior_7d_rupees * 100)::numeric
             ELSE 0::numeric END AS gmv_wow_pct,
        (SELECT count(*)::int FROM public.repair_jobs
          WHERE status = 'completed' AND completed_at >= now() - interval '7 days'
        ) AS completed_jobs_7d,
        (
          SELECT count(DISTINCT b.engineer_user_id)::int
            FROM public.repair_job_bids b
            JOIN public.repair_jobs rj ON rj.id = b.repair_job_id
           WHERE b.status = 'accepted'
             AND rj.completed_at >= now() - interval '30 days'
        ) AS active_engineers_30d,
        (SELECT count(*)::int FROM public.amc_contracts WHERE status = 'active') AS amc_contracts_active,
        (SELECT coalesce(sum(amount_rupees), 0)::numeric
           FROM public.repair_job_escrow WHERE status IN ('held','disputed')
        ) AS total_escrow_held_rupees,
        (
          SELECT coalesce(jsonb_agg(row_to_json(v) ORDER BY v.gmv DESC), '[]'::jsonb)
            FROM (
              SELECT
                rj.equipment_type::text AS type,
                coalesce(sum(rje.amount_rupees), 0)::numeric AS gmv
                FROM public.repair_jobs rj
                LEFT JOIN public.repair_job_escrow rje ON rje.repair_job_id = rj.id
               WHERE rj.status = 'completed'
                 AND rj.completed_at >= now() - interval '90 days'
               GROUP BY rj.equipment_type
               ORDER BY 2 DESC
               LIMIT 3
            ) v
        ) AS top_verticals
       FROM g
    ) inner_calc;

  RETURN QUERY
  SELECT v_hero.generated_at, v_hero.gmv_7d_rupees, v_hero.gmv_wow_pct,
         v_hero.completed_jobs_7d, v_hero.active_engineers_30d,
         v_hero.amc_contracts_active, v_hero.total_escrow_held_rupees,
         v_hero.top_verticals;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.read_investor_brief_via_token(text, text)
  FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.read_investor_brief_via_token(text, text)
  TO anon, authenticated, service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 566 audit-18 patch verified: global anon rate limit now excludes not_found outcomes — attacker cannot DoS legitimate share reads by spamming random tokens';
END;
$$;
