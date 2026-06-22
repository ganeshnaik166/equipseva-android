BEGIN;

-- ============================================================================
-- Round 2301: Founder family-event commitment tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_family_events_r2301 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  founder_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_title text NOT NULL,
  event_category text NOT NULL CHECK (event_category IN ('anniversary','birthday','school_event','religious','family_gathering','medical','milestone','other')),
  family_member_name text,
  relationship text CHECK (relationship IN ('spouse','child','parent','sibling','in_law','extended','self','other')),
  event_date date NOT NULL,
  event_start_time time,
  event_end_time time,
  location text,
  importance_tier text NOT NULL DEFAULT 'medium' CHECK (importance_tier IN ('critical','high','medium','low')),
  is_recurring_annual boolean NOT NULL DEFAULT false,
  founder_commitment_status text NOT NULL DEFAULT 'tentative' CHECK (founder_commitment_status IN ('committed','tentative','attending_partial','declined','missed','attended')),
  commitment_notes text,
  spouse_attending boolean,
  preparation_required text,
  budget_rupees integer CHECK (budget_rupees IS NULL OR budget_rupees >= 0),
  reminder_lead_days integer NOT NULL DEFAULT 7 CHECK (reminder_lead_days >= 0 AND reminder_lead_days <= 365),
  conflict_check_status text NOT NULL DEFAULT 'pending' CHECK (conflict_check_status IN ('pending','clear','soft_conflict','hard_conflict','resolved')),
  conflicting_meetings jsonb NOT NULL DEFAULT '[]'::jsonb,
  guilt_score integer CHECK (guilt_score IS NULL OR guilt_score BETWEEN 0 AND 10),
  consecutive_misses integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ffe_r2301_date ON public.founder_family_events_r2301(event_date DESC);
CREATE INDEX IF NOT EXISTS idx_ffe_r2301_status ON public.founder_family_events_r2301(founder_commitment_status);
CREATE INDEX IF NOT EXISTS idx_ffe_r2301_conflict ON public.founder_family_events_r2301(conflict_check_status);
CREATE INDEX IF NOT EXISTS idx_ffe_r2301_tier ON public.founder_family_events_r2301(importance_tier);

ALTER TABLE public.founder_family_events_r2301 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ffe_r2301 ON public.founder_family_events_r2301;
CREATE POLICY founder_all_ffe_r2301 ON public.founder_family_events_r2301
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_family_commitment_log_r2301 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.founder_family_events_r2301(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('created','updated','committed','declined','attended','missed','conflict_flagged','reminder_sent','rescheduled')),
  prior_status text,
  new_status text,
  conflict_details jsonb,
  reason text,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ffcl_r2301_event ON public.founder_family_commitment_log_r2301(event_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ffcl_r2301_action ON public.founder_family_commitment_log_r2301(action_type);

ALTER TABLE public.founder_family_commitment_log_r2301 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_ffcl_r2301 ON public.founder_family_commitment_log_r2301;
CREATE POLICY founder_all_ffcl_r2301 ON public.founder_family_commitment_log_r2301
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.r2301_list_upcoming_events(p_days_ahead integer DEFAULT 90)
RETURNS TABLE (
  id uuid,
  event_title text,
  event_category text,
  family_member_name text,
  relationship text,
  event_date date,
  days_until integer,
  importance_tier text,
  founder_commitment_status text,
  conflict_check_status text,
  is_recurring_annual boolean,
  spouse_attending boolean,
  guilt_score integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_title, e.event_category, e.family_member_name, e.relationship,
         e.event_date, (e.event_date - CURRENT_DATE)::integer AS days_until,
         e.importance_tier, e.founder_commitment_status, e.conflict_check_status,
         e.is_recurring_annual, e.spouse_attending, e.guilt_score
  FROM public.founder_family_events_r2301 e
  WHERE e.event_date >= CURRENT_DATE
    AND e.event_date <= CURRENT_DATE + (p_days_ahead || ' days')::interval
  ORDER BY e.event_date ASC, e.importance_tier;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2301_summary_stats()
RETURNS TABLE (
  total_events integer,
  upcoming_30d integer,
  critical_upcoming integer,
  committed_count integer,
  tentative_count integer,
  declined_count integer,
  missed_last_90d integer,
  hard_conflict_count integer,
  attended_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_attended integer;
  v_past integer;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) FILTER (WHERE founder_commitment_status = 'attended'),
         COUNT(*) FILTER (WHERE event_date < CURRENT_DATE)
    INTO v_attended, v_past
  FROM public.founder_family_events_r2301;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE event_date BETWEEN CURRENT_DATE AND CURRENT_DATE + interval '30 days'),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE importance_tier = 'critical' AND event_date >= CURRENT_DATE),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE founder_commitment_status = 'committed'),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE founder_commitment_status = 'tentative'),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE founder_commitment_status = 'declined'),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE founder_commitment_status = 'missed' AND event_date >= CURRENT_DATE - interval '90 days'),
    (SELECT COUNT(*)::integer FROM public.founder_family_events_r2301 WHERE conflict_check_status = 'hard_conflict'),
    CASE WHEN v_past = 0 THEN 0::numeric
         ELSE ROUND((v_attended::numeric / v_past::numeric) * 100, 1) END;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2301_conflict_alerts()
RETURNS TABLE (
  id uuid,
  event_title text,
  event_date date,
  importance_tier text,
  conflict_check_status text,
  conflicting_meetings jsonb,
  days_until integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_title, e.event_date, e.importance_tier,
         e.conflict_check_status, e.conflicting_meetings,
         (e.event_date - CURRENT_DATE)::integer
  FROM public.founder_family_events_r2301 e
  WHERE e.conflict_check_status IN ('soft_conflict','hard_conflict')
    AND e.event_date >= CURRENT_DATE
  ORDER BY e.event_date ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2301_category_breakdown()
RETURNS TABLE (
  event_category text,
  total integer,
  attended integer,
  missed integer,
  upcoming integer,
  attend_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_category,
         COUNT(*)::integer AS total,
         COUNT(*) FILTER (WHERE e.founder_commitment_status = 'attended')::integer,
         COUNT(*) FILTER (WHERE e.founder_commitment_status = 'missed')::integer,
         COUNT(*) FILTER (WHERE e.event_date >= CURRENT_DATE)::integer,
         CASE WHEN COUNT(*) FILTER (WHERE e.event_date < CURRENT_DATE) = 0 THEN 0::numeric
              ELSE ROUND(
                COUNT(*) FILTER (WHERE e.founder_commitment_status = 'attended')::numeric
                / NULLIF(COUNT(*) FILTER (WHERE e.event_date < CURRENT_DATE), 0)::numeric * 100, 1) END
  FROM public.founder_family_events_r2301 e
  GROUP BY e.event_category
  ORDER BY total DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2301_recent_log(p_limit integer DEFAULT 25)
RETURNS TABLE (
  id uuid,
  event_id uuid,
  event_title text,
  action_type text,
  prior_status text,
  new_status text,
  reason text,
  actor_email text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.event_id, e.event_title, l.action_type, l.prior_status,
         l.new_status, l.reason, l.actor_email, l.created_at
  FROM public.founder_family_commitment_log_r2301 l
  LEFT JOIN public.founder_family_events_r2301 e ON e.id = l.event_id
  ORDER BY l.created_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.r2301_update_commitment(
  p_event_id uuid,
  p_new_status text,
  p_reason text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_prior text;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('committed','tentative','attending_partial','declined','missed','attended') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  SELECT founder_commitment_status INTO v_prior
  FROM public.founder_family_events_r2301
  WHERE id = p_event_id;

  IF v_prior IS NULL THEN RAISE EXCEPTION 'event_not_found'; END IF;

  v_email := auth.jwt()->>'email';

  UPDATE public.founder_family_events_r2301
  SET founder_commitment_status = p_new_status,
      consecutive_misses = CASE WHEN p_new_status = 'missed' THEN consecutive_misses + 1
                                WHEN p_new_status = 'attended' THEN 0
                                ELSE consecutive_misses END,
      updated_at = now()
  WHERE id = p_event_id;

  INSERT INTO public.founder_family_commitment_log_r2301 (event_id, action_type, prior_status, new_status, reason, actor_email)
  VALUES (p_event_id,
          CASE p_new_status WHEN 'committed' THEN 'committed'
                            WHEN 'declined' THEN 'declined'
                            WHEN 'attended' THEN 'attended'
                            WHEN 'missed' THEN 'missed'
                            ELSE 'updated' END,
          v_prior, p_new_status, p_reason, v_email);

  RETURN p_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r2301_high_risk_misses()
RETURNS TABLE (
  id uuid,
  event_title text,
  family_member_name text,
  relationship text,
  importance_tier text,
  consecutive_misses integer,
  guilt_score integer,
  next_event_date date
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_title, e.family_member_name, e.relationship,
         e.importance_tier, e.consecutive_misses, e.guilt_score,
         e.event_date
  FROM public.founder_family_events_r2301 e
  WHERE (e.consecutive_misses >= 2 OR COALESCE(e.guilt_score, 0) >= 7)
    AND e.event_date >= CURRENT_DATE
  ORDER BY e.consecutive_misses DESC, e.guilt_score DESC NULLS LAST
  LIMIT 50;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE ALL ON FUNCTION public.r2301_list_upcoming_events(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2301_summary_stats() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2301_conflict_alerts() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2301_category_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2301_recent_log(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2301_update_commitment(uuid, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2301_high_risk_misses() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2301_list_upcoming_events(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2301_summary_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2301_conflict_alerts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2301_category_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2301_recent_log(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2301_update_commitment(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2301_high_risk_misses() TO authenticated;

COMMIT;
