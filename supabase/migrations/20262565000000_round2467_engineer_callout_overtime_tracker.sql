-- Round 2467: Engineer Callout & Overtime Tracker
-- Tracks engineer callouts, overtime hours, premium pay, consent, fatigue impact, next-day rest

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_callouts_r2467 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  callout_at timestamptz NOT NULL DEFAULT now(),
  overtime_hours numeric(6,2) NOT NULL DEFAULT 0 CHECK (overtime_hours >= 0 AND overtime_hours <= 24),
  premium_rupees integer NOT NULL DEFAULT 0 CHECK (premium_rupees >= 0),
  consent_given boolean NOT NULL DEFAULT false,
  callout_kind text NOT NULL CHECK (callout_kind IN ('emergency','sla_breach','customer_call','equipment_critical','holiday')),
  fatigue_impact_kind text NOT NULL CHECK (fatigue_impact_kind IN ('none','mild','moderate','severe')),
  next_day_rest_taken boolean NOT NULL DEFAULT false,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.callout_fatigue_metrics_r2467 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  week_start date NOT NULL,
  total_callouts integer NOT NULL DEFAULT 0 CHECK (total_callouts >= 0),
  total_overtime_hours numeric(8,2) NOT NULL DEFAULT 0 CHECK (total_overtime_hours >= 0),
  total_premium_rupees integer NOT NULL DEFAULT 0 CHECK (total_premium_rupees >= 0),
  severe_fatigue_count integer NOT NULL DEFAULT 0 CHECK (severe_fatigue_count >= 0),
  rest_taken_count integer NOT NULL DEFAULT 0 CHECK (rest_taken_count >= 0),
  rest_compliance_pct numeric(5,2) NOT NULL DEFAULT 0 CHECK (rest_compliance_pct >= 0 AND rest_compliance_pct <= 100),
  status text NOT NULL CHECK (status IN ('green','amber','red')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_callouts_r2467 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callout_fatigue_metrics_r2467 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_callouts_r2467;
CREATE POLICY founder_all ON public.engineer_callouts_r2467
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.callout_fatigue_metrics_r2467;
CREATE POLICY founder_all ON public.callout_fatigue_metrics_r2467
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at ASC OFFSET 2 LIMIT 1;

  IF v_eng1 IS NOT NULL THEN
    INSERT INTO public.engineer_callouts_r2467 (engineer_user_id, callout_at, overtime_hours, premium_rupees, consent_given, callout_kind, fatigue_impact_kind, next_day_rest_taken, owner_email, notes)
    VALUES
      (v_eng1, now() - interval '2 days', 4.5, 2250, true, 'emergency', 'moderate', true, 'ops@equipseva.com', 'ICU ventilator down at midnight'),
      (v_eng1, now() - interval '5 days', 3.0, 1500, true, 'sla_breach', 'mild', true, 'ops@equipseva.com', 'P1 SLA at risk, extended shift');

    INSERT INTO public.callout_fatigue_metrics_r2467 (engineer_user_id, week_start, total_callouts, total_overtime_hours, total_premium_rupees, severe_fatigue_count, rest_taken_count, rest_compliance_pct, status, notes)
    VALUES (v_eng1, date_trunc('week', current_date)::date, 2, 7.5, 3750, 0, 2, 100.00, 'green', 'Healthy pace, full rest taken');
  END IF;

  IF v_eng2 IS NOT NULL THEN
    INSERT INTO public.engineer_callouts_r2467 (engineer_user_id, callout_at, overtime_hours, premium_rupees, consent_given, callout_kind, fatigue_impact_kind, next_day_rest_taken, owner_email, notes)
    VALUES (v_eng2, now() - interval '1 day', 6.0, 3500, true, 'equipment_critical', 'severe', false, 'ops@equipseva.com', 'CT scanner down, no rest taken next day');

    INSERT INTO public.callout_fatigue_metrics_r2467 (engineer_user_id, week_start, total_callouts, total_overtime_hours, total_premium_rupees, severe_fatigue_count, rest_taken_count, rest_compliance_pct, status, notes)
    VALUES (v_eng2, date_trunc('week', current_date)::date, 4, 18.0, 9500, 2, 1, 25.00, 'red', 'Burnout risk, mandatory rest day');
  END IF;

  IF v_eng3 IS NOT NULL THEN
    INSERT INTO public.engineer_callouts_r2467 (engineer_user_id, callout_at, overtime_hours, premium_rupees, consent_given, callout_kind, fatigue_impact_kind, next_day_rest_taken, owner_email, notes)
    VALUES (v_eng3, now() - interval '3 days', 2.5, 1250, false, 'holiday', 'mild', true, 'ops@equipseva.com', 'Holiday callout, no formal consent');

    INSERT INTO public.callout_fatigue_metrics_r2467 (engineer_user_id, week_start, total_callouts, total_overtime_hours, total_premium_rupees, severe_fatigue_count, rest_taken_count, rest_compliance_pct, status, notes)
    VALUES (v_eng3, date_trunc('week', current_date)::date, 3, 10.5, 5500, 1, 2, 66.67, 'amber', 'Watch consent process');
  END IF;
END $seed$;

-- RPC 1: list callouts
CREATE OR REPLACE FUNCTION public.list_callouts_r2467()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  callout_at timestamptz,
  overtime_hours numeric,
  premium_rupees integer,
  consent_given boolean,
  callout_kind text,
  fatigue_impact_kind text,
  next_day_rest_taken boolean,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.engineer_user_id, c.callout_at, c.overtime_hours, c.premium_rupees,
         c.consent_given, c.callout_kind, c.fatigue_impact_kind, c.next_day_rest_taken,
         c.owner_email, c.notes
  FROM public.engineer_callouts_r2467 c
  ORDER BY c.callout_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_callouts_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_callouts_r2467() TO authenticated;

-- RPC 2: list fatigue metrics
CREATE OR REPLACE FUNCTION public.list_fatigue_metrics_r2467()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  week_start date,
  total_callouts integer,
  total_overtime_hours numeric,
  total_premium_rupees integer,
  severe_fatigue_count integer,
  rest_taken_count integer,
  rest_compliance_pct numeric,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.engineer_user_id, m.week_start, m.total_callouts, m.total_overtime_hours,
         m.total_premium_rupees, m.severe_fatigue_count, m.rest_taken_count,
         m.rest_compliance_pct, m.status, m.notes
  FROM public.callout_fatigue_metrics_r2467 m
  ORDER BY m.week_start DESC, m.total_overtime_hours DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_fatigue_metrics_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_fatigue_metrics_r2467() TO authenticated;

-- RPC 3: top overtime engineers
CREATE OR REPLACE FUNCTION public.top_overtime_engineers_r2467()
RETURNS TABLE (
  engineer_user_id uuid,
  total_overtime numeric,
  total_premium integer,
  callout_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_user_id,
         SUM(c.overtime_hours)::numeric AS total_overtime,
         SUM(c.premium_rupees)::integer AS total_premium,
         COUNT(*)::bigint AS callout_count
  FROM public.engineer_callouts_r2467 c
  GROUP BY c.engineer_user_id
  ORDER BY total_overtime DESC
  LIMIT 20;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_overtime_engineers_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_overtime_engineers_r2467() TO authenticated;

-- RPC 4: fatigue severity breakdown
CREATE OR REPLACE FUNCTION public.fatigue_severity_breakdown_r2467()
RETURNS TABLE (
  fatigue_impact_kind text,
  callout_count bigint,
  avg_overtime numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.fatigue_impact_kind,
         COUNT(*)::bigint AS callout_count,
         ROUND(AVG(c.overtime_hours)::numeric, 2) AS avg_overtime
  FROM public.engineer_callouts_r2467 c
  GROUP BY c.fatigue_impact_kind
  ORDER BY callout_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fatigue_severity_breakdown_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fatigue_severity_breakdown_r2467() TO authenticated;

-- RPC 5: weekly premium trend
CREATE OR REPLACE FUNCTION public.weekly_premium_trend_r2467()
RETURNS TABLE (
  week_start date,
  total_premium bigint,
  total_callouts bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.week_start,
         SUM(m.total_premium_rupees)::bigint AS total_premium,
         SUM(m.total_callouts)::bigint AS total_callouts
  FROM public.callout_fatigue_metrics_r2467 m
  GROUP BY m.week_start
  ORDER BY m.week_start DESC
  LIMIT 12;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_premium_trend_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_premium_trend_r2467() TO authenticated;

-- RPC 6: rest compliance summary
CREATE OR REPLACE FUNCTION public.rest_compliance_summary_r2467()
RETURNS TABLE (
  status text,
  engineer_count bigint,
  avg_compliance numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.status,
         COUNT(*)::bigint AS engineer_count,
         ROUND(AVG(m.rest_compliance_pct)::numeric, 2) AS avg_compliance
  FROM public.callout_fatigue_metrics_r2467 m
  GROUP BY m.status
  ORDER BY avg_compliance DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.rest_compliance_summary_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rest_compliance_summary_r2467() TO authenticated;

-- RPC 7: kind breakdown
CREATE OR REPLACE FUNCTION public.kind_breakdown_r2467()
RETURNS TABLE (
  callout_kind text,
  callout_count bigint,
  total_overtime numeric,
  total_premium bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.callout_kind,
         COUNT(*)::bigint AS callout_count,
         SUM(c.overtime_hours)::numeric AS total_overtime,
         SUM(c.premium_rupees)::bigint AS total_premium
  FROM public.engineer_callouts_r2467 c
  GROUP BY c.callout_kind
  ORDER BY callout_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2467() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2467() TO authenticated;

