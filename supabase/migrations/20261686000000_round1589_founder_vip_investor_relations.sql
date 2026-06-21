BEGIN;

-- =====================================================================
-- Round 1589: Founder VIP Investor Relations
-- White-glove tier for lead investor + board chair: 1:1 calls, custom
-- KPI dashboards, advance access to news, per-VIP commitment tracker.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: founder_vip_investors
-- Roster of VIP investors with tier, cadence, commitment, contact prefs.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_vip_investors (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name text NOT NULL,
  firm_name text,
  email text NOT NULL,
  phone text,
  role_label text NOT NULL CHECK (role_label IN ('lead_investor','board_chair','board_member','advisor','strategic_lp')),
  tier text NOT NULL DEFAULT 'gold' CHECK (tier IN ('platinum','gold','silver')),
  commitment_rupees bigint NOT NULL DEFAULT 0,
  drawn_rupees bigint NOT NULL DEFAULT 0,
  next_tranche_rupees bigint NOT NULL DEFAULT 0,
  next_tranche_due_on date,
  cadence_days int NOT NULL DEFAULT 30 CHECK (cadence_days BETWEEN 7 AND 180),
  last_one_to_one_at timestamptz,
  next_one_to_one_at timestamptz,
  advance_news_optin boolean NOT NULL DEFAULT true,
  custom_kpi_keys text[] NOT NULL DEFAULT ARRAY[]::text[],
  notes text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvip_active_tier ON public.founder_vip_investors (active, tier);
CREATE INDEX IF NOT EXISTS idx_fvip_next_call ON public.founder_vip_investors (next_one_to_one_at) WHERE active;

ALTER TABLE public.founder_vip_investors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fvip_founder_all ON public.founder_vip_investors;
CREATE POLICY p_fvip_founder_all ON public.founder_vip_investors
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- Table 2: founder_vip_touchpoints
-- Per-VIP timeline: 1:1 calls, advance news drops, KPI dashboard sends.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_vip_touchpoints (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vip_id uuid NOT NULL REFERENCES public.founder_vip_investors(id) ON DELETE CASCADE,
  touchpoint_kind text NOT NULL CHECK (touchpoint_kind IN ('one_to_one_call','kpi_dashboard_send','advance_news','tranche_nudge','custom_note')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  subject text NOT NULL,
  body_md text,
  sentiment text CHECK (sentiment IN ('positive','neutral','concerned','blocker')),
  next_action text,
  created_by_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fvip_tp_vip_time ON public.founder_vip_touchpoints (vip_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_fvip_tp_kind ON public.founder_vip_touchpoints (touchpoint_kind, occurred_at DESC);

ALTER TABLE public.founder_vip_touchpoints ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_fvip_tp_founder_all ON public.founder_vip_touchpoints;
CREATE POLICY p_fvip_tp_founder_all ON public.founder_vip_touchpoints
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- LOG HELPERS (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.log_founder_vip_upsert(p_vip_id uuid, p_after jsonb)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_investor_upsert', jsonb_build_object('vip_id', p_vip_id, 'after', p_after));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_upsert(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_upsert(uuid, jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_vip_touchpoint(p_vip_id uuid, p_kind text, p_subject text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_touchpoint_logged', jsonb_build_object('vip_id', p_vip_id, 'kind', p_kind, 'subject', p_subject));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_touchpoint(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_touchpoint(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_vip_tranche(p_vip_id uuid, p_amount_rupees bigint)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_tranche_drawn', jsonb_build_object('vip_id', p_vip_id, 'amount_rupees', p_amount_rupees));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_tranche(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_tranche(uuid, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_vip_advance_news(p_vip_ids uuid[], p_subject text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vip_advance_news_sent', jsonb_build_object('vip_ids', to_jsonb(p_vip_ids), 'subject', p_subject));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_vip_advance_news(uuid[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_vip_advance_news(uuid[], text) TO authenticated;

-- =====================================================================
-- READ RPCs (STABLE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.founder_vip_roster()
RETURNS TABLE (
  id uuid,
  full_name text,
  firm_name text,
  role_label text,
  tier text,
  commitment_rupees bigint,
  drawn_rupees bigint,
  remaining_rupees bigint,
  draw_pct numeric,
  next_tranche_rupees bigint,
  next_tranche_due_on date,
  cadence_days int,
  last_one_to_one_at timestamptz,
  next_one_to_one_at timestamptz,
  days_to_next_call numeric,
  active boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.full_name, v.firm_name, v.role_label, v.tier,
         v.commitment_rupees, v.drawn_rupees,
         GREATEST(v.commitment_rupees - v.drawn_rupees, 0)::bigint AS remaining_rupees,
         CASE WHEN v.commitment_rupees > 0
              THEN ROUND((v.drawn_rupees::numeric / v.commitment_rupees::numeric) * 100, 1)
              ELSE 0 END AS draw_pct,
         v.next_tranche_rupees, v.next_tranche_due_on, v.cadence_days,
         v.last_one_to_one_at, v.next_one_to_one_at,
         CASE WHEN v.next_one_to_one_at IS NULL THEN NULL
              ELSE ROUND(EXTRACT(EPOCH FROM (v.next_one_to_one_at - now())) / 86400.0, 1)
         END AS days_to_next_call,
         v.active
    FROM public.founder_vip_investors v
   ORDER BY v.active DESC,
            CASE v.tier WHEN 'platinum' THEN 0 WHEN 'gold' THEN 1 ELSE 2 END,
            v.next_one_to_one_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_roster() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_roster() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_vip_kpis()
RETURNS TABLE (
  total_vips int,
  active_vips int,
  platinum_vips int,
  total_commitment_rupees bigint,
  total_drawn_rupees bigint,
  total_remaining_rupees bigint,
  overall_draw_pct numeric,
  next_tranche_total_rupees bigint,
  tranches_due_30d int,
  calls_overdue int,
  calls_due_7d int,
  calls_logged_30d int,
  advance_news_sent_30d int,
  blockers_open int,
  positive_sentiment_30d int,
  avg_cadence_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT * FROM public.founder_vip_investors
  ),
  tp30 AS (
    SELECT * FROM public.founder_vip_touchpoints WHERE occurred_at >= now() - interval '30 days'
  )
  SELECT
    (SELECT count(*)::int FROM base),
    (SELECT count(*)::int FROM base WHERE active),
    (SELECT count(*)::int FROM base WHERE active AND tier = 'platinum'),
    (SELECT COALESCE(sum(commitment_rupees),0)::bigint FROM base WHERE active),
    (SELECT COALESCE(sum(drawn_rupees),0)::bigint FROM base WHERE active),
    (SELECT COALESCE(sum(GREATEST(commitment_rupees - drawn_rupees, 0)),0)::bigint FROM base WHERE active),
    (SELECT CASE WHEN COALESCE(sum(commitment_rupees),0) > 0
                 THEN ROUND(sum(drawn_rupees)::numeric / sum(commitment_rupees)::numeric * 100, 1)
                 ELSE 0 END FROM base WHERE active),
    (SELECT COALESCE(sum(next_tranche_rupees),0)::bigint FROM base WHERE active),
    (SELECT count(*)::int FROM base WHERE active AND next_tranche_due_on IS NOT NULL AND next_tranche_due_on <= (current_date + 30)),
    (SELECT count(*)::int FROM base WHERE active AND next_one_to_one_at IS NOT NULL AND next_one_to_one_at < now()),
    (SELECT count(*)::int FROM base WHERE active AND next_one_to_one_at IS NOT NULL AND next_one_to_one_at BETWEEN now() AND now() + interval '7 days'),
    (SELECT count(*)::int FROM tp30 WHERE touchpoint_kind = 'one_to_one_call'),
    (SELECT count(*)::int FROM tp30 WHERE touchpoint_kind = 'advance_news'),
    (SELECT count(*)::int FROM public.founder_vip_touchpoints WHERE sentiment = 'blocker' AND occurred_at >= now() - interval '60 days'),
    (SELECT count(*)::int FROM tp30 WHERE sentiment = 'positive'),
    (SELECT ROUND(AVG(cadence_days)::numeric, 1) FROM base WHERE active);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_vip_recent_touchpoints(p_limit int DEFAULT 30)
RETURNS TABLE (
  id uuid,
  vip_id uuid,
  vip_name text,
  tier text,
  touchpoint_kind text,
  occurred_at timestamptz,
  subject text,
  sentiment text,
  next_action text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT tp.id, tp.vip_id, v.full_name, v.tier, tp.touchpoint_kind,
         tp.occurred_at, tp.subject, tp.sentiment, tp.next_action
    FROM public.founder_vip_touchpoints tp
    JOIN public.founder_vip_investors v ON v.id = tp.vip_id
   ORDER BY tp.occurred_at DESC
   LIMIT GREATEST(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_recent_touchpoints(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_recent_touchpoints(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_vip_calls_due()
RETURNS TABLE (
  vip_id uuid,
  full_name text,
  tier text,
  role_label text,
  next_one_to_one_at timestamptz,
  days_to_call numeric,
  is_overdue boolean,
  cadence_days int,
  last_one_to_one_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.full_name, v.tier, v.role_label, v.next_one_to_one_at,
         ROUND(EXTRACT(EPOCH FROM (v.next_one_to_one_at - now())) / 86400.0, 1),
         (v.next_one_to_one_at < now()) AS is_overdue,
         v.cadence_days, v.last_one_to_one_at
    FROM public.founder_vip_investors v
   WHERE v.active
     AND v.next_one_to_one_at IS NOT NULL
     AND v.next_one_to_one_at <= now() + interval '14 days'
   ORDER BY v.next_one_to_one_at ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_calls_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_calls_due() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_vip_tranches_due()
RETURNS TABLE (
  vip_id uuid,
  full_name text,
  tier text,
  next_tranche_rupees bigint,
  next_tranche_due_on date,
  days_to_due numeric,
  commitment_rupees bigint,
  drawn_rupees bigint,
  remaining_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT v.id, v.full_name, v.tier,
         v.next_tranche_rupees, v.next_tranche_due_on,
         (v.next_tranche_due_on - current_date)::numeric,
         v.commitment_rupees, v.drawn_rupees,
         GREATEST(v.commitment_rupees - v.drawn_rupees, 0)::bigint
    FROM public.founder_vip_investors v
   WHERE v.active
     AND v.next_tranche_due_on IS NOT NULL
     AND v.next_tranche_rupees > 0
   ORDER BY v.next_tranche_due_on ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_tranches_due() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_tranches_due() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_vip_sentiment_trend()
RETURNS TABLE (
  week_start date,
  positive_count int,
  neutral_count int,
  concerned_count int,
  blocker_count int,
  total_touchpoints int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', tp.occurred_at)::date AS week_start,
         count(*) FILTER (WHERE sentiment = 'positive')::int,
         count(*) FILTER (WHERE sentiment = 'neutral')::int,
         count(*) FILTER (WHERE sentiment = 'concerned')::int,
         count(*) FILTER (WHERE sentiment = 'blocker')::int,
         count(*)::int
    FROM public.founder_vip_touchpoints tp
   WHERE tp.occurred_at >= now() - interval '12 weeks'
   GROUP BY 1
   ORDER BY 1 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_sentiment_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_sentiment_trend() TO authenticated;

-- =====================================================================
-- WRITE RPC (VOLATILE SECDEF)
-- =====================================================================

CREATE OR REPLACE FUNCTION public.founder_vip_log_one_to_one(
  p_vip_id uuid,
  p_subject text,
  p_body_md text,
  p_sentiment text,
  p_next_action text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_cadence int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT cadence_days INTO v_cadence FROM public.founder_vip_investors WHERE id = p_vip_id;
  IF v_cadence IS NULL THEN RAISE EXCEPTION 'vip not found'; END IF;

  INSERT INTO public.founder_vip_touchpoints (vip_id, touchpoint_kind, subject, body_md, sentiment, next_action, created_by_user_id)
  VALUES (p_vip_id, 'one_to_one_call', p_subject, p_body_md, p_sentiment, p_next_action, auth.uid())
  RETURNING id INTO v_id;

  UPDATE public.founder_vip_investors
     SET last_one_to_one_at = now(),
         next_one_to_one_at = now() + (v_cadence || ' days')::interval,
         updated_at = now()
   WHERE id = p_vip_id;

  PERFORM public.log_founder_vip_touchpoint(p_vip_id, 'one_to_one_call', p_subject);
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_vip_log_one_to_one(uuid, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_vip_log_one_to_one(uuid, text, text, text, text) TO authenticated;

COMMIT;