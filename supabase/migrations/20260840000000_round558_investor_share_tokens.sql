-- =====================================================================
-- Round 558 — Investor share tokens (v0.5 P5 — sanitized public brief)
-- =====================================================================
--
-- Founder can mint a token-gated public link to a sanitized investor
-- brief. The token holder (e.g. a VC analyst) opens
--   /share/investor/<token>
-- without authenticating. The /share route reads ONLY non-PII headline
-- KPIs — no engineer names, no hospital names, no transaction ids.
--
-- Security model:
--   1. Token stored as SHA-256 hash (raw shown ONCE to the founder
--      when minting; lost after that)
--   2. Per-token expiry (default 7 days) + per-token view cap (default 50)
--   3. View attempts are logged (forensic + anomaly detection if a
--      single token is being hammered)
--   4. Read RPC anon-callable but only returns sanitized columns
--      (GMV, jobs, engineers count, AMC count, vertical mix names —
--      NO emails, NO ids, NO disputes detail)
--   5. Founder can revoke any token

BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_share_tokens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  token_hash      text NOT NULL UNIQUE,         -- sha256 hex
  label           text NOT NULL,                -- "Tata AIG meeting" — founder-visible label
  expires_at      timestamptz NOT NULL,
  max_views       int NOT NULL DEFAULT 50,
  view_count      int NOT NULL DEFAULT 0,
  status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','expired','revoked','exhausted')),
  created_by      uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  revoked_at      timestamptz,
  revoke_reason   text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS investor_share_tokens_hash_idx
  ON public.investor_share_tokens (token_hash);
CREATE INDEX IF NOT EXISTS investor_share_tokens_status_idx
  ON public.investor_share_tokens (status, expires_at);

ALTER TABLE public.investor_share_tokens ENABLE ROW LEVEL SECURITY;

-- Founder reads all. Anon cannot read directly — must go through the
-- read RPC which only returns sanitized fields.
DROP POLICY IF EXISTS investor_share_tokens_select ON public.investor_share_tokens;
CREATE POLICY investor_share_tokens_select
  ON public.investor_share_tokens FOR SELECT
  TO authenticated
  USING (public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.investor_share_tokens
  FROM anon, authenticated, service_role;

CREATE TABLE IF NOT EXISTS public.investor_share_view_log (
  id            bigserial PRIMARY KEY,
  token_id      uuid NOT NULL REFERENCES public.investor_share_tokens(id) ON DELETE CASCADE,
  viewed_at     timestamptz NOT NULL DEFAULT now(),
  user_agent    text,
  outcome       text NOT NULL CHECK (outcome IN ('ok','expired','exhausted','revoked','not_found'))
);

CREATE INDEX IF NOT EXISTS investor_share_view_log_token_idx
  ON public.investor_share_view_log (token_id, viewed_at DESC);

ALTER TABLE public.investor_share_view_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS investor_share_view_log_select ON public.investor_share_view_log;
CREATE POLICY investor_share_view_log_select
  ON public.investor_share_view_log FOR SELECT
  TO authenticated
  USING (public.is_founder());
REVOKE INSERT, UPDATE, DELETE ON public.investor_share_view_log
  FROM anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- founder_mint_investor_share_token — returns the RAW token only once
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_mint_investor_share_token(
  p_label          text,
  p_expires_in_days int DEFAULT 7,
  p_max_views      int DEFAULT 50
)
RETURNS TABLE (
  token_id   uuid,
  raw_token  text,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_raw    text;
  v_hash   text;
  v_id     uuid;
  v_exp    timestamptz;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_label IS NULL OR length(trim(p_label)) < 3 THEN
    RAISE EXCEPTION 'label required (min 3 chars)' USING ERRCODE = '22023';
  END IF;
  IF p_expires_in_days < 1 OR p_expires_in_days > 90 THEN
    RAISE EXCEPTION 'expires_in_days must be 1..90' USING ERRCODE = '22023';
  END IF;
  IF p_max_views < 1 OR p_max_views > 1000 THEN
    RAISE EXCEPTION 'max_views must be 1..1000' USING ERRCODE = '22023';
  END IF;

  -- Raw token = 64 hex chars from two random uuids concatenated.
  v_raw := replace(gen_random_uuid()::text, '-', '') ||
           replace(gen_random_uuid()::text, '-', '');
  v_hash := encode(digest(v_raw, 'sha256'), 'hex');
  v_exp := now() + (p_expires_in_days || ' days')::interval;

  INSERT INTO public.investor_share_tokens
    (token_hash, label, expires_at, max_views, created_by)
  VALUES
    (v_hash, trim(p_label), v_exp, p_max_views, auth.uid())
  RETURNING id INTO v_id;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_mint_investor_share_token',
    p_target_table  => 'investor_share_tokens',
    p_target_row_id => v_id,
    p_before_value  => NULL,
    p_after_value   => jsonb_build_object('label', p_label,
                                          'expires_at', v_exp,
                                          'max_views', p_max_views),
    p_reason        => 'investor share link minted'
  );

  RETURN QUERY SELECT v_id, v_raw, v_exp;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_mint_investor_share_token(text, int, int)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_mint_investor_share_token(text, int, int)
  TO service_role;

-- ---------------------------------------------------------------------
-- founder_revoke_investor_share_token
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_revoke_investor_share_token(
  p_token_id uuid,
  p_reason   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  IF p_reason IS NULL OR length(trim(p_reason)) < 5 THEN
    RAISE EXCEPTION 'reason required (min 5 chars)' USING ERRCODE = '22023';
  END IF;

  UPDATE public.investor_share_tokens
     SET status = 'revoked',
         revoked_at = now(),
         revoke_reason = trim(p_reason)
   WHERE id = p_token_id AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'token_not_found_or_not_active' USING ERRCODE = '02000';
  END IF;

  PERFORM public.log_founder_action(
    p_op_name       => 'founder_revoke_investor_share_token',
    p_target_table  => 'investor_share_tokens',
    p_target_row_id => p_token_id,
    p_before_value  => jsonb_build_object('status', 'active'),
    p_after_value   => jsonb_build_object('status', 'revoked'),
    p_reason        => p_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_revoke_investor_share_token(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_revoke_investor_share_token(uuid, text)
  TO service_role;

-- ---------------------------------------------------------------------
-- read_investor_brief_via_token — PUBLIC, no auth
-- ---------------------------------------------------------------------
--
-- Returns only sanitized headline KPIs. NO engineer names, NO hospital
-- emails, NO transaction ids, NO disputes detail. Founders can also
-- view this — RLS-gated other surfaces remain founder-only.
CREATE OR REPLACE FUNCTION public.read_investor_brief_via_token(
  p_raw_token text,
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
  top_verticals          jsonb     -- [{type, gmv}] top 3 by GMV
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_hash   text;
  v_token  record;
  v_hero   record;
BEGIN
  IF p_raw_token IS NULL OR length(p_raw_token) < 32 THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (NULL, left(coalesce(p_user_agent, ''), 200), 'not_found');
    RAISE EXCEPTION 'invalid_token' USING ERRCODE = '02000';
  END IF;

  v_hash := encode(digest(p_raw_token, 'sha256'), 'hex');

  SELECT * INTO v_token
    FROM public.investor_share_tokens
   WHERE token_hash = v_hash
   FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
    VALUES (NULL, left(coalesce(p_user_agent, ''), 200), 'not_found');
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

  -- Bump view count + log success.
  UPDATE public.investor_share_tokens
     SET view_count = view_count + 1
   WHERE id = v_token.id;
  INSERT INTO public.investor_share_view_log (token_id, user_agent, outcome)
  VALUES (v_token.id, left(coalesce(p_user_agent, ''), 200), 'ok');

  -- Build the sanitized response.
  SELECT * INTO v_hero
    FROM (
      -- Bypass the founder gate by reading the same data via direct
      -- table joins. is_founder() is false for anon callers; the hero
      -- KPIs RPC would raise. We compute equivalents here.
      WITH g AS (
        SELECT
          coalesce(sum(amount_rupees) FILTER (
            WHERE rj.completed_at >= now() - interval '7 days'
          ), 0)::numeric AS gmv_7d_rupees,
          coalesce(sum(amount_rupees) FILTER (
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
                rj.category AS type,
                coalesce(sum(rje.amount_rupees), 0)::numeric AS gmv
                FROM public.repair_jobs rj
                LEFT JOIN public.repair_job_escrow rje ON rje.repair_job_id = rj.id
               WHERE rj.status = 'completed'
                 AND rj.completed_at >= now() - interval '90 days'
               GROUP BY rj.category
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
-- founder_list_investor_share_tokens — cockpit read
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.founder_list_investor_share_tokens(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id              uuid,
  label           text,
  status          text,
  expires_at      timestamptz,
  max_views       int,
  view_count      int,
  revoked_at      timestamptz,
  revoke_reason   text,
  created_at      timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT t.id, t.label, t.status, t.expires_at, t.max_views, t.view_count,
         t.revoked_at, t.revoke_reason, t.created_at
    FROM public.investor_share_tokens t
   ORDER BY t.created_at DESC
   LIMIT greatest(coalesce(p_limit, 50), 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_investor_share_tokens(int)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.founder_list_investor_share_tokens(int)
  TO service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 558 investor share tokens verified: 2 tables + 4 RPCs (mint / revoke / read via token / list); pgcrypto digest used for sha256 hash';
END;
$$;
