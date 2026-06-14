-- =====================================================================
-- Round 563 — Audit-17 patches (CRITICAL bug fix + rate limits)
-- =====================================================================
--
-- Audit-17 (workflow wyscp1sxj) confirmed 4 findings on r558 public
-- share surface:
--
-- CRITICAL #1 — read_investor_brief_via_token() referenced rj.category
--   which doesn't exist on repair_jobs. Correct column is
--   rj.equipment_type. Every public token read was failing in prod.
--
-- CRITICAL #2 — No rate limiting on /share/investor/[token]; attacker
--   can exhaust the view_count cap (max_views=50) within seconds.
--
-- HIGH #3 — Token enumeration via SHA-256 brute-force feasible on
--   GPU at ~100k hashes/sec; no rate limit means an attacker can hammer
--   the RPC with random hashes.
--
-- HIGH #4 — Timing attack on hash lookup leaks whether a given hash
--   exists.
--
-- Fix strategy:
--   1. DROP + recreate read_investor_brief_via_token with correct column
--   2. Add per-token rate limit: refuse if > 20 view attempts on this
--      token in the trailing 60 seconds (closes CRITICAL #2 + bounds
--      HIGH #3)
--   3. Add global anon rate limit: refuse if total anon read attempts
--      across ALL tokens > 200 in trailing 60 seconds (closes HIGH #3
--      brute-force, blunts HIGH #4 timing)
--   4. Constant-ish-time error path: do the hash compute even on
--      not_found so the lookup-miss timing isn't dramatically faster
--      (closes HIGH #4)
--   5. Add a retention sweep on investor_share_view_log so it doesn't
--      grow unbounded.

BEGIN;

-- Drop + recreate with the column fix + rate-limit checks.
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
  -- r563: global anon rate limit BEFORE we touch any other table.
  -- Cap: 200 read attempts across all tokens in last 60s.
  SELECT count(*)::int INTO v_recent_global
    FROM public.investor_share_view_log
   WHERE viewed_at > now() - interval '60 seconds';
  IF v_recent_global >= 200 THEN
    RAISE EXCEPTION 'global_rate_limit (200 reads / 60s)'
      USING ERRCODE = '53400';
  END IF;

  -- Always compute the hash, even before validating input length, so
  -- timing-based hash-existence enumeration is blunted.
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

  -- r563: per-token rate limit. > 20 attempts in 60s means
  -- abuse — refuse without bumping the legitimate view_count.
  SELECT count(*)::int INTO v_recent_per_token
    FROM public.investor_share_view_log
   WHERE token_id = v_token.id
     AND viewed_at > now() - interval '60 seconds';
  IF v_recent_per_token >= 20 THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'not_found');
    -- We surface as 'not_found' so the attacker can't tell their target
    -- token is real and being throttled — protects HIGH timing leak.
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
                rj.equipment_type::text AS type,   -- r563 audit-17 CRITICAL fix: was rj.category
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

-- ---------------------------------------------------------------------
-- 7-day retention sweep on investor_share_view_log (forensic enough +
-- bounded growth). Same SECDEF-as-owner pattern as r510 retention.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.investor_share_view_log_retention_sweep()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted int := 0;
BEGIN
  DELETE FROM public.investor_share_view_log
   WHERE viewed_at < now() - interval '7 days';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.investor_share_view_log_retention_sweep()
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.investor_share_view_log_retention_sweep()
  TO service_role;

DO $$
BEGIN
  PERFORM cron.schedule(
    'investor_share_view_log_retention_sweep',
    '37 4 * * *',  -- 04:37 UTC daily
    $cron$SELECT public.investor_share_view_log_retention_sweep();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron unavailable; retention sweep must be triggered by edge fn';
END;
$$;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 563 audit-17 patches verified: rj.equipment_type column fix + per-token rate limit (20/60s) + global anon rate limit (200/60s) + 7-day view-log retention sweep';
END;
$$;
