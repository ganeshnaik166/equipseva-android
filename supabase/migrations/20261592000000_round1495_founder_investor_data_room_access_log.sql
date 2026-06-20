BEGIN;

-- =========================================================================
-- r1495 — Investor data-room access log + heat map + cold-investor ladder
-- =========================================================================

-- Table 1: every single data-room access event
CREATE TABLE IF NOT EXISTS public.investor_dataroom_access_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_token     text NOT NULL,
  investor_email  text,
  investor_name   text,
  investor_firm   text,
  doc_slug        text NOT NULL,
  doc_title       text,
  accessed_at     timestamptz NOT NULL DEFAULT now(),
  dwell_seconds   integer NOT NULL DEFAULT 0,
  ip_hash         text,
  user_agent      text,
  referrer        text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_dr_access_token    ON public.investor_dataroom_access_log(share_token);
CREATE INDEX IF NOT EXISTS idx_inv_dr_access_email    ON public.investor_dataroom_access_log(investor_email);
CREATE INDEX IF NOT EXISTS idx_inv_dr_access_at       ON public.investor_dataroom_access_log(accessed_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_dr_access_doc      ON public.investor_dataroom_access_log(doc_slug);

ALTER TABLE public.investor_dataroom_access_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_inv_dr_access_founder_only ON public.investor_dataroom_access_log;
CREATE POLICY p_inv_dr_access_founder_only
  ON public.investor_dataroom_access_log
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: founder action ladder for cold investors
CREATE TABLE IF NOT EXISTS public.investor_cold_actions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_email  text NOT NULL,
  investor_firm   text,
  share_token     text,
  ladder_step     text NOT NULL CHECK (ladder_step IN ('nudge_email','warm_intro_ask','product_demo_offer','founder_call','drop')),
  notes           text,
  taken_at        timestamptz NOT NULL DEFAULT now(),
  outcome         text CHECK (outcome IN ('pending','responded','no_response','converted','passed')),
  outcome_at      timestamptz,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_cold_actions_email ON public.investor_cold_actions(investor_email);
CREATE INDEX IF NOT EXISTS idx_inv_cold_actions_taken ON public.investor_cold_actions(taken_at DESC);
CREATE INDEX IF NOT EXISTS idx_inv_cold_actions_step  ON public.investor_cold_actions(ladder_step);

ALTER TABLE public.investor_cold_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_inv_cold_actions_founder_only ON public.investor_cold_actions;
CREATE POLICY p_inv_cold_actions_founder_only
  ON public.investor_cold_actions
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- log helpers (VOLATILE, SECDEF, is_founder gated)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.log_founder_dr_access_view()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'dr_access_log.view', jsonb_build_object('ts', now())
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_access_view() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_access_view() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_dr_heatmap_view()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'dr_access_log.heatmap_view', jsonb_build_object('ts', now())
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_heatmap_view() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_heatmap_view() TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_dr_cold_action_taken(p_email text, p_step text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'dr_cold_action.taken',
         jsonb_build_object('investor_email', p_email, 'step', p_step, 'ts', now())
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_cold_action_taken(text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_cold_action_taken(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_dr_export()
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'dr_access_log.export', jsonb_build_object('ts', now())
  FROM profiles p WHERE p.id = auth.uid();
END $$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_export() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_export() TO authenticated;

-- =========================================================================
-- Read RPCs (STABLE)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.founder_dr_access_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  WITH base AS (
    SELECT * FROM investor_dataroom_access_log
  ),
  per_inv AS (
    SELECT investor_email,
           COUNT(*) AS visits,
           MAX(accessed_at) AS last_seen,
           SUM(dwell_seconds) AS total_dwell
    FROM base
    WHERE investor_email IS NOT NULL
    GROUP BY investor_email
  )
  SELECT jsonb_build_object(
    'total_events',           (SELECT COUNT(*) FROM base),
    'events_24h',             (SELECT COUNT(*) FROM base WHERE accessed_at > now() - interval '24 hours'),
    'events_7d',              (SELECT COUNT(*) FROM base WHERE accessed_at > now() - interval '7 days'),
    'events_30d',             (SELECT COUNT(*) FROM base WHERE accessed_at > now() - interval '30 days'),
    'unique_investors',       (SELECT COUNT(*) FROM per_inv),
    'unique_firms',           (SELECT COUNT(DISTINCT investor_firm) FROM base WHERE investor_firm IS NOT NULL),
    'unique_docs',            (SELECT COUNT(DISTINCT doc_slug) FROM base),
    'unique_tokens',          (SELECT COUNT(DISTINCT share_token) FROM base),
    'avg_dwell_seconds',      (SELECT COALESCE(ROUND(AVG(dwell_seconds))::int,0) FROM base),
    'total_dwell_minutes',    (SELECT COALESCE(ROUND(SUM(dwell_seconds)/60.0)::int,0) FROM base),
    'repeat_visitors',        (SELECT COUNT(*) FROM per_inv WHERE visits >= 2),
    'whales_5plus',           (SELECT COUNT(*) FROM per_inv WHERE visits >= 5),
    'cold_investors',         (SELECT COUNT(*) FROM per_inv WHERE last_seen < now() - interval '14 days'),
    'hot_investors_7d',       (SELECT COUNT(*) FROM per_inv WHERE last_seen > now() - interval '7 days'),
    'cold_actions_total',     (SELECT COUNT(*) FROM investor_cold_actions),
    'cold_actions_pending',   (SELECT COUNT(*) FROM investor_cold_actions WHERE outcome = 'pending' OR outcome IS NULL)
  ) INTO r;
  RETURN r;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_access_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_access_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dr_recent_access(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid, accessed_at timestamptz, investor_email text, investor_firm text,
  doc_slug text, doc_title text, dwell_seconds int, share_token text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.accessed_at, l.investor_email, l.investor_firm,
         l.doc_slug, l.doc_title, l.dwell_seconds, l.share_token
  FROM investor_dataroom_access_log l
  ORDER BY l.accessed_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_recent_access(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_recent_access(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dr_investor_heatmap()
RETURNS TABLE(
  id text, investor_email text, investor_firm text, visits bigint,
  unique_docs bigint, total_dwell_seconds bigint, last_seen timestamptz,
  days_since_last numeric, temperature text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.investor_email AS id,
    l.investor_email,
    MAX(l.investor_firm) AS investor_firm,
    COUNT(*) AS visits,
    COUNT(DISTINCT l.doc_slug) AS unique_docs,
    COALESCE(SUM(l.dwell_seconds),0)::bigint AS total_dwell_seconds,
    MAX(l.accessed_at) AS last_seen,
    ROUND(EXTRACT(EPOCH FROM (now() - MAX(l.accessed_at)))/86400.0, 1) AS days_since_last,
    CASE
      WHEN MAX(l.accessed_at) > now() - interval '3 days'  THEN 'hot'
      WHEN MAX(l.accessed_at) > now() - interval '14 days' THEN 'warm'
      ELSE 'cold'
    END AS temperature
  FROM investor_dataroom_access_log l
  WHERE l.investor_email IS NOT NULL
  GROUP BY l.investor_email
  ORDER BY MAX(l.accessed_at) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_investor_heatmap() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_investor_heatmap() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dr_doc_popularity()
RETURNS TABLE(
  id text, doc_slug text, doc_title text, total_views bigint,
  unique_viewers bigint, avg_dwell_seconds numeric, last_viewed timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    l.doc_slug AS id,
    l.doc_slug,
    MAX(l.doc_title) AS doc_title,
    COUNT(*) AS total_views,
    COUNT(DISTINCT l.investor_email) AS unique_viewers,
    ROUND(AVG(l.dwell_seconds)::numeric, 1) AS avg_dwell_seconds,
    MAX(l.accessed_at) AS last_viewed
  FROM investor_dataroom_access_log l
  GROUP BY l.doc_slug
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_doc_popularity() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_doc_popularity() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dr_cold_investors()
RETURNS TABLE(
  id text, investor_email text, investor_firm text, last_seen timestamptz,
  days_since_last numeric, visits bigint, suggested_step text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH agg AS (
    SELECT l.investor_email,
           MAX(l.investor_firm) AS firm,
           MAX(l.accessed_at) AS last_seen,
           COUNT(*) AS visits
    FROM investor_dataroom_access_log l
    WHERE l.investor_email IS NOT NULL
    GROUP BY l.investor_email
  )
  SELECT
    a.investor_email AS id,
    a.investor_email,
    a.firm,
    a.last_seen,
    ROUND(EXTRACT(EPOCH FROM (now() - a.last_seen))/86400.0, 1) AS days_since_last,
    a.visits,
    CASE
      WHEN EXTRACT(EPOCH FROM (now() - a.last_seen))/86400.0 BETWEEN 14 AND 21 THEN 'nudge_email'
      WHEN EXTRACT(EPOCH FROM (now() - a.last_seen))/86400.0 BETWEEN 21 AND 35 THEN 'warm_intro_ask'
      WHEN EXTRACT(EPOCH FROM (now() - a.last_seen))/86400.0 BETWEEN 35 AND 60 THEN 'product_demo_offer'
      WHEN EXTRACT(EPOCH FROM (now() - a.last_seen))/86400.0 > 60               THEN 'drop'
      ELSE 'nudge_email'
    END AS suggested_step
  FROM agg a
  WHERE a.last_seen < now() - interval '14 days'
  ORDER BY a.last_seen ASC;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_cold_investors() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_cold_investors() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_dr_cold_action_history(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid, taken_at timestamptz, investor_email text, investor_firm text,
  ladder_step text, outcome text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.taken_at, a.investor_email, a.investor_firm,
         a.ladder_step, a.outcome, a.notes
  FROM investor_cold_actions a
  ORDER BY a.taken_at DESC
  LIMIT GREATEST(p_limit, 1);
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_cold_action_history(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_cold_action_history(int) TO authenticated;

-- =========================================================================
-- Write RPC (VOLATILE)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.founder_dr_record_cold_action(
  p_investor_email text,
  p_investor_firm  text,
  p_share_token    text,
  p_step           text,
  p_notes          text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE new_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_step NOT IN ('nudge_email','warm_intro_ask','product_demo_offer','founder_call','drop') THEN
    RAISE EXCEPTION 'invalid ladder_step %', p_step;
  END IF;
  INSERT INTO investor_cold_actions(investor_email, investor_firm, share_token, ladder_step, notes, outcome, created_by)
  VALUES (p_investor_email, p_investor_firm, p_share_token, p_step, p_notes, 'pending', auth.uid())
  RETURNING id INTO new_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  SELECT auth.uid(), p.email, 'dr_cold_action.recorded',
         jsonb_build_object('investor_email', p_investor_email, 'step', p_step, 'id', new_id)
  FROM profiles p WHERE p.id = auth.uid();

  RETURN new_id;
END $$;
REVOKE EXECUTE ON FUNCTION public.founder_dr_record_cold_action(text,text,text,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_dr_record_cold_action(text,text,text,text,text) TO authenticated;

COMMIT;