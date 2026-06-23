-- Round r2574: Engineer x Customer trust credit score
-- Tables: engineer_trust_credit_r2574, trust_event_log_r2574
-- 7 RPCs guarded by public.is_founder()

CREATE TABLE IF NOT EXISTS public.engineer_trust_credit_r2574 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  promise_made_count int NOT NULL DEFAULT 0,
  promise_kept_count int NOT NULL DEFAULT 0,
  promise_broken_count int NOT NULL DEFAULT 0,
  trust_score int NOT NULL DEFAULT 50 CHECK (trust_score BETWEEN 0 AND 100),
  decay_rate_per_week numeric NOT NULL DEFAULT 1.0,
  last_event_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'building' CHECK (status IN ('building','strong','champion','strained','broken')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trust_event_log_r2574 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  credit_id uuid NOT NULL REFERENCES public.engineer_trust_credit_r2574(id) ON DELETE CASCADE,
  event_at timestamptz NOT NULL DEFAULT now(),
  event_kind text NOT NULL CHECK (event_kind IN ('promise_kept','promise_broken','extra_mile','missed_callback','proactive_warning')),
  impact_score int NOT NULL DEFAULT 0,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_trust_credit_r2574 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trust_event_log_r2574 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_trust_credit_r2574;
CREATE POLICY founder_all ON public.engineer_trust_credit_r2574
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.trust_event_log_r2574;
CREATE POLICY founder_all ON public.trust_event_log_r2574
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed trust credits (engineer x hospital pairs)
DO $seed$
DECLARE
  v_engineer_id uuid;
  v_hospital_id uuid;
BEGIN
  SELECT id INTO v_engineer_id FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hospital_id FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;

  IF v_engineer_id IS NOT NULL AND v_hospital_id IS NOT NULL THEN
    INSERT INTO public.engineer_trust_credit_r2574
      (id, engineer_user_id, hospital_user_id, promise_made_count, promise_kept_count, promise_broken_count,
       trust_score, decay_rate_per_week, last_event_at, owner_email, status, notes)
    VALUES
      ('22222222-2222-2222-2222-222222222201', v_engineer_id, v_hospital_id, 24, 22, 2, 88, 0.5, now() - interval '2 days',
       'csm@equipseva.in', 'champion', 'Apollo Hyd flagship trust account'),
      ('22222222-2222-2222-2222-222222222202', v_engineer_id, v_hospital_id, 18, 16, 2, 78, 0.8, now() - interval '5 days',
       'csm@equipseva.in', 'strong', 'Reliable but two missed callbacks last quarter'),
      ('22222222-2222-2222-2222-222222222203', v_engineer_id, v_hospital_id, 12, 7, 5, 42, 2.0, now() - interval '14 days',
       'csm@equipseva.in', 'strained', 'AMC under review - two broken SLAs in a row'),
      ('22222222-2222-2222-2222-222222222204', v_engineer_id, v_hospital_id, 8, 8, 0, 65, 1.2, now() - interval '3 days',
       'csm@equipseva.in', 'building', 'New account onboarded last month'),
      ('22222222-2222-2222-2222-222222222205', v_engineer_id, v_hospital_id, 30, 18, 12, 25, 3.0, now() - interval '30 days',
       'csm@equipseva.in', 'broken', 'Churn risk - escalate to founder')
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.trust_event_log_r2574
      (credit_id, event_at, event_kind, impact_score, owner_email, notes)
    VALUES
      ('22222222-2222-2222-2222-222222222201', now() - interval '2 days', 'extra_mile', 8, 'csm@equipseva.in', 'Engineer drove 80km for free on a Sunday'),
      ('22222222-2222-2222-2222-222222222201', now() - interval '10 days', 'promise_kept', 4, 'csm@equipseva.in', 'SLA met for ventilator repair'),
      ('22222222-2222-2222-2222-222222222202', now() - interval '5 days', 'promise_kept', 3, 'csm@equipseva.in', 'Quarterly maintenance on time'),
      ('22222222-2222-2222-2222-222222222203', now() - interval '14 days', 'promise_broken', -7, 'csm@equipseva.in', 'Promised 2h ETA, took 6h'),
      ('22222222-2222-2222-2222-222222222203', now() - interval '20 days', 'missed_callback', -3, 'csm@equipseva.in', 'Did not return diagnostic call'),
      ('22222222-2222-2222-2222-222222222204', now() - interval '3 days', 'proactive_warning', 5, 'csm@equipseva.in', 'Warned hospital of upcoming firmware EOL'),
      ('22222222-2222-2222-2222-222222222205', now() - interval '30 days', 'promise_broken', -10, 'csm@equipseva.in', 'Critical OT lamp down 36h');
  END IF;
END $seed$;

-- RPC 1: list trust credit
CREATE OR REPLACE FUNCTION public.list_trust_credit_r2574()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  promise_made_count int,
  promise_kept_count int,
  promise_broken_count int,
  trust_score int,
  decay_rate_per_week numeric,
  last_event_at timestamptz,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_user_id, t.hospital_user_id, t.promise_made_count, t.promise_kept_count,
         t.promise_broken_count, t.trust_score, t.decay_rate_per_week, t.last_event_at,
         t.owner_email, t.status, t.notes, t.created_at
  FROM public.engineer_trust_credit_r2574 t
  ORDER BY t.trust_score DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_trust_credit_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_trust_credit_r2574() TO authenticated;

-- RPC 2: list event log
CREATE OR REPLACE FUNCTION public.list_event_log_r2574()
RETURNS TABLE (
  id uuid,
  credit_id uuid,
  trust_score int,
  status text,
  event_at timestamptz,
  event_kind text,
  impact_score int,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.credit_id, c.trust_score, c.status,
         e.event_at, e.event_kind, e.impact_score, e.owner_email, e.notes
  FROM public.trust_event_log_r2574 e
  JOIN public.engineer_trust_credit_r2574 c ON c.id = e.credit_id
  ORDER BY e.event_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_event_log_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_event_log_r2574() TO authenticated;

-- RPC 3: top trust engineers
CREATE OR REPLACE FUNCTION public.top_trust_engineers_r2574()
RETURNS TABLE (
  engineer_user_id uuid,
  account_count bigint,
  avg_trust_score numeric,
  total_promises_kept bigint,
  total_promises_broken bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.engineer_user_id,
         COUNT(*)::bigint AS account_count,
         AVG(t.trust_score)::numeric AS avg_trust_score,
         COALESCE(SUM(t.promise_kept_count),0)::bigint AS total_promises_kept,
         COALESCE(SUM(t.promise_broken_count),0)::bigint AS total_promises_broken
  FROM public.engineer_trust_credit_r2574 t
  GROUP BY t.engineer_user_id
  ORDER BY avg_trust_score DESC NULLS LAST
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_trust_engineers_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_trust_engineers_r2574() TO authenticated;

-- RPC 4: broken focus
CREATE OR REPLACE FUNCTION public.broken_focus_r2574()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  trust_score int,
  promise_broken_count int,
  last_event_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.engineer_user_id, t.hospital_user_id, t.trust_score,
         t.promise_broken_count, t.last_event_at, t.status, t.notes
  FROM public.engineer_trust_credit_r2574 t
  WHERE t.status IN ('strained','broken') OR t.trust_score < 50
  ORDER BY t.trust_score ASC NULLS LAST
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.broken_focus_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.broken_focus_r2574() TO authenticated;

-- RPC 5: event kind breakdown
CREATE OR REPLACE FUNCTION public.event_kind_breakdown_r2574()
RETURNS TABLE (
  event_kind text,
  event_count bigint,
  total_impact bigint,
  avg_impact numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.event_kind,
         COUNT(*)::bigint AS event_count,
         COALESCE(SUM(e.impact_score),0)::bigint AS total_impact,
         AVG(e.impact_score)::numeric AS avg_impact
  FROM public.trust_event_log_r2574 e
  GROUP BY e.event_kind
  ORDER BY event_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.event_kind_breakdown_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.event_kind_breakdown_r2574() TO authenticated;

-- RPC 6: trust score trend (weekly buckets)
CREATE OR REPLACE FUNCTION public.trust_score_trend_r2574()
RETURNS TABLE (
  week_label text,
  events_logged bigint,
  total_impact bigint,
  positive_events bigint,
  negative_events bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('week', e.event_at), 'IYYY-"W"IW') AS week_label,
         COUNT(*)::bigint AS events_logged,
         COALESCE(SUM(e.impact_score),0)::bigint AS total_impact,
         COUNT(*) FILTER (WHERE e.impact_score > 0)::bigint AS positive_events,
         COUNT(*) FILTER (WHERE e.impact_score < 0)::bigint AS negative_events
  FROM public.trust_event_log_r2574 e
  GROUP BY date_trunc('week', e.event_at)
  ORDER BY date_trunc('week', e.event_at) DESC NULLS LAST
  LIMIT 26;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.trust_score_trend_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.trust_score_trend_r2574() TO authenticated;

-- RPC 7: hospital trust summary
CREATE OR REPLACE FUNCTION public.hospital_trust_summary_r2574()
RETURNS TABLE (
  hospital_user_id uuid,
  engineer_count bigint,
  avg_trust_score numeric,
  min_trust_score int,
  max_trust_score int,
  total_broken_promises bigint,
  strained_or_broken_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.hospital_user_id,
         COUNT(*)::bigint AS engineer_count,
         AVG(t.trust_score)::numeric AS avg_trust_score,
         MIN(t.trust_score)::int AS min_trust_score,
         MAX(t.trust_score)::int AS max_trust_score,
         COALESCE(SUM(t.promise_broken_count),0)::bigint AS total_broken_promises,
         COUNT(*) FILTER (WHERE t.status IN ('strained','broken'))::bigint AS strained_or_broken_count
  FROM public.engineer_trust_credit_r2574 t
  GROUP BY t.hospital_user_id
  ORDER BY avg_trust_score ASC NULLS LAST
  LIMIT 30;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_trust_summary_r2574() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospital_trust_summary_r2574() TO authenticated;
