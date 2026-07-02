-- Round 2550: engineer client language coaching
-- Tables: engineer_language_coaching_sessions_r2550 + language_coaching_outcomes_r2550

CREATE TABLE IF NOT EXISTS public.engineer_language_coaching_sessions_r2550 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  language_name text NOT NULL,
  session_at timestamptz NOT NULL DEFAULT now(),
  coach_email text NOT NULL,
  focus_kind text NOT NULL CHECK (focus_kind IN ('greeting','explanation','escalation','technical_terms','diplomatic_pushback')),
  duration_minutes int NOT NULL DEFAULT 30,
  confidence_pre int NOT NULL CHECK (confidence_pre BETWEEN 0 AND 10),
  confidence_post int NOT NULL CHECK (confidence_post BETWEEN 0 AND 10),
  confidence_delta int GENERATED ALWAYS AS (confidence_post - confidence_pre) STORED,
  hospital_impact_md text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.language_coaching_outcomes_r2550 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.engineer_language_coaching_sessions_r2550(id) ON DELETE CASCADE,
  observed_at timestamptz NOT NULL DEFAULT now(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  hospital_csat_delta numeric(5,2),
  comments_md text,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_lcs_r2550_engineer ON public.engineer_language_coaching_sessions_r2550(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_lcs_r2550_session_at ON public.engineer_language_coaching_sessions_r2550(session_at DESC);
CREATE INDEX IF NOT EXISTS idx_lco_r2550_session ON public.language_coaching_outcomes_r2550(session_id);
CREATE INDEX IF NOT EXISTS idx_lco_r2550_observed ON public.language_coaching_outcomes_r2550(observed_at DESC);

ALTER TABLE public.engineer_language_coaching_sessions_r2550 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.language_coaching_outcomes_r2550 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_language_coaching_sessions_r2550;
CREATE POLICY founder_all ON public.engineer_language_coaching_sessions_r2550
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.language_coaching_outcomes_r2550;
CREATE POLICY founder_all ON public.language_coaching_outcomes_r2550
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_s1 uuid;
  v_s2 uuid;
  v_s3 uuid;
  v_s4 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_eng1 IS NOT NULL THEN
    INSERT INTO public.engineer_language_coaching_sessions_r2550(engineer_user_id, language_name, session_at, coach_email, focus_kind, duration_minutes, confidence_pre, confidence_post, hospital_impact_md, status, notes)
      VALUES (v_eng1, 'Tamil', now() - interval '14 days', 'coach.tamil@equipseva.in', 'technical_terms', 45, 4, 7, 'Engineer now able to explain MRI gradient coil failure in Tamil to Chennai chain.', 'done', 'Vocabulary list shared.')
      RETURNING id INTO v_s1;

    INSERT INTO public.engineer_language_coaching_sessions_r2550(engineer_user_id, language_name, session_at, coach_email, focus_kind, duration_minutes, confidence_pre, confidence_post, hospital_impact_md, status, notes)
      VALUES (v_eng1, 'Tamil', now() - interval '7 days', 'coach.tamil@equipseva.in', 'diplomatic_pushback', 30, 5, 8, 'Handled SLA breach pushback gracefully.', 'done', 'Role-play with hospital admin.')
      RETURNING id INTO v_s2;
  END IF;

  IF v_eng2 IS NOT NULL THEN
    INSERT INTO public.engineer_language_coaching_sessions_r2550(engineer_user_id, language_name, session_at, coach_email, focus_kind, duration_minutes, confidence_pre, confidence_post, hospital_impact_md, status, notes)
      VALUES (v_eng2, 'Bengali', now() - interval '21 days', 'coach.bengali@equipseva.in', 'greeting', 20, 3, 6, 'Better rapport with Kolkata Apollo team.', 'done', 'First-touch script.')
      RETURNING id INTO v_s3;
  END IF;

  IF v_eng3 IS NOT NULL THEN
    INSERT INTO public.engineer_language_coaching_sessions_r2550(engineer_user_id, language_name, session_at, coach_email, focus_kind, duration_minutes, confidence_pre, confidence_post, hospital_impact_md, status, notes)
      VALUES (v_eng3, 'Marathi', now() + interval '3 days', 'coach.marathi@equipseva.in', 'escalation', 40, 4, 4, 'Planned for next sprint.', 'planned', 'Pending materials.')
      RETURNING id INTO v_s4;
  END IF;

  IF v_s1 IS NOT NULL THEN
    INSERT INTO public.language_coaching_outcomes_r2550(session_id, observed_at, hospital_user_id, hospital_csat_delta, comments_md, owner_email, status, notes)
      VALUES (v_s1, now() - interval '10 days', v_hosp1, 1.20, 'Hospital CSAT jumped after Tamil explanation.', 'ops@equipseva.in', 'done', 'Closed.');
  END IF;
  IF v_s2 IS NOT NULL THEN
    INSERT INTO public.language_coaching_outcomes_r2550(session_id, observed_at, hospital_user_id, hospital_csat_delta, comments_md, owner_email, status, notes)
      VALUES (v_s2, now() - interval '3 days', v_hosp1, 0.80, 'Escalation defused.', 'ops@equipseva.in', 'open', 'Follow-up.');
  END IF;
  IF v_s3 IS NOT NULL THEN
    INSERT INTO public.language_coaching_outcomes_r2550(session_id, observed_at, hospital_user_id, hospital_csat_delta, comments_md, owner_email, status, notes)
      VALUES (v_s3, now() - interval '14 days', v_hosp2, 0.50, 'Greeting reception improved.', 'ops@equipseva.in', 'done', NULL);
  END IF;
END
$seed$;

-- ============================ RPCs ============================

CREATE OR REPLACE FUNCTION public.list_coaching_sessions_r2550()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  language_name text,
  session_at timestamptz,
  coach_email text,
  focus_kind text,
  duration_minutes int,
  confidence_pre int,
  confidence_post int,
  confidence_delta int,
  hospital_impact_md text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.engineer_user_id, s.language_name, s.session_at, s.coach_email,
           s.focus_kind, s.duration_minutes, s.confidence_pre, s.confidence_post,
           s.confidence_delta, s.hospital_impact_md, s.status, s.notes
    FROM public.engineer_language_coaching_sessions_r2550 s
    ORDER BY s.session_at DESC NULLS LAST
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_coaching_sessions_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_coaching_sessions_r2550() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_outcomes_r2550()
RETURNS TABLE (
  id uuid,
  session_id uuid,
  observed_at timestamptz,
  hospital_user_id uuid,
  hospital_csat_delta numeric,
  comments_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.id, o.session_id, o.observed_at, o.hospital_user_id, o.hospital_csat_delta,
           o.comments_md, o.owner_email, o.status, o.notes
    FROM public.language_coaching_outcomes_r2550 o
    ORDER BY o.observed_at DESC NULLS LAST
    LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2550() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_confidence_lifters_r2550()
RETURNS TABLE (
  engineer_user_id uuid,
  sessions_count bigint,
  avg_delta numeric,
  max_delta int,
  total_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.engineer_user_id,
           count(*)::bigint AS sessions_count,
           round(avg(s.confidence_delta)::numeric, 2) AS avg_delta,
           max(s.confidence_delta) AS max_delta,
           sum(s.duration_minutes)::bigint AS total_minutes
    FROM public.engineer_language_coaching_sessions_r2550 s
    WHERE s.status = 'done'
    GROUP BY s.engineer_user_id
    ORDER BY avg_delta DESC NULLS LAST
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_confidence_lifters_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_confidence_lifters_r2550() TO authenticated;

CREATE OR REPLACE FUNCTION public.focus_kind_breakdown_r2550()
RETURNS TABLE (
  focus_kind text,
  sessions_count bigint,
  avg_delta numeric,
  avg_duration numeric,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.focus_kind,
           count(*)::bigint AS sessions_count,
           round(avg(s.confidence_delta)::numeric, 2) AS avg_delta,
           round(avg(s.duration_minutes)::numeric, 1) AS avg_duration,
           count(*) FILTER (WHERE s.status = 'done')::bigint AS done_count
    FROM public.engineer_language_coaching_sessions_r2550 s
    GROUP BY s.focus_kind
    ORDER BY sessions_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.focus_kind_breakdown_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.focus_kind_breakdown_r2550() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_coaching_trend_r2550()
RETURNS TABLE (
  month_start timestamptz,
  sessions_count bigint,
  avg_delta numeric,
  total_minutes bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', s.session_at)::timestamptz AS month_start,
           count(*)::bigint AS sessions_count,
           round(avg(s.confidence_delta)::numeric, 2) AS avg_delta,
           sum(s.duration_minutes)::bigint AS total_minutes
    FROM public.engineer_language_coaching_sessions_r2550 s
    GROUP BY date_trunc('month', s.session_at)
    ORDER BY month_start DESC NULLS LAST
    LIMIT 24;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_coaching_trend_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_coaching_trend_r2550() TO authenticated;

CREATE OR REPLACE FUNCTION public.hospital_impact_summary_r2550()
RETURNS TABLE (
  hospital_user_id uuid,
  outcomes_count bigint,
  avg_csat_delta numeric,
  open_count bigint,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.hospital_user_id,
           count(*)::bigint AS outcomes_count,
           round(avg(o.hospital_csat_delta)::numeric, 2) AS avg_csat_delta,
           count(*) FILTER (WHERE o.status = 'open')::bigint AS open_count,
           count(*) FILTER (WHERE o.status = 'done')::bigint AS done_count
    FROM public.language_coaching_outcomes_r2550 o
    GROUP BY o.hospital_user_id
    ORDER BY avg_csat_delta DESC NULLS LAST
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.hospital_impact_summary_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hospital_impact_summary_r2550() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2550()
RETURNS TABLE (
  owner_email text,
  outcomes_count bigint,
  open_count bigint,
  done_count bigint,
  dropped_count bigint,
  avg_csat_delta numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT o.owner_email,
           count(*)::bigint AS outcomes_count,
           count(*) FILTER (WHERE o.status = 'open')::bigint AS open_count,
           count(*) FILTER (WHERE o.status = 'done')::bigint AS done_count,
           count(*) FILTER (WHERE o.status = 'dropped')::bigint AS dropped_count,
           round(avg(o.hospital_csat_delta)::numeric, 2) AS avg_csat_delta
    FROM public.language_coaching_outcomes_r2550 o
    GROUP BY o.owner_email
    ORDER BY outcomes_count DESC NULLS LAST
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2550() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2550() TO authenticated;
