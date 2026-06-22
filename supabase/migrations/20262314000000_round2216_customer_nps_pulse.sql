BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_nps_surveys_r2216 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  engineer_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  city text,
  quarter_label text NOT NULL,
  score int NOT NULL CHECK (score BETWEEN 0 AND 10),
  category text NOT NULL CHECK (category IN ('promoter','passive','detractor')),
  verbatim text,
  surveyed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.customer_nps_followups_r2216 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  survey_id uuid REFERENCES public.customer_nps_surveys_r2216(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','contacted','resolved','escalated')),
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  contacted_at timestamptz,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_nps_surveys_r2216 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_nps_followups_r2216 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_nps_surveys_r2216;
CREATE POLICY founder_all ON public.customer_nps_surveys_r2216 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_nps_followups_r2216;
CREATE POLICY founder_all ON public.customer_nps_followups_r2216 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_nps_surveys_r2216()
RETURNS TABLE (
  id uuid,
  hospital_name text,
  engineer_email text,
  city text,
  quarter_label text,
  score int,
  category text,
  verbatim text,
  surveyed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id,
           o.name,
           p.email,
           s.city,
           s.quarter_label,
           s.score,
           s.category,
           s.verbatim,
           s.surveyed_at
    FROM public.customer_nps_surveys_r2216 s
    LEFT JOIN public.organizations o ON o.id = s.hospital_org_id
    LEFT JOIN public.profiles p ON p.id = s.engineer_user_id
    ORDER BY s.surveyed_at DESC
    LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.recent_actions_nps_r2216()
RETURNS TABLE (id bigint, actor_email text, op_name text, after_value jsonb, created_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.actor_email, f.op_name, f.after_value, f.created_at
    FROM public.founder_action_log f
    WHERE f.op_name LIKE 'op_r2216%'
    ORDER BY f.created_at DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.top_nps_by_hospital_r2216()
RETURNS TABLE (hospital_name text, response_count int, promoter_count int, detractor_count int, nps_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COALESCE(o.name, 'unknown'),
           COUNT(*)::int,
           (COUNT(*) FILTER (WHERE s.category = 'promoter'))::int,
           (COUNT(*) FILTER (WHERE s.category = 'detractor'))::int,
           ((COUNT(*) FILTER (WHERE s.category='promoter'))*100/GREATEST(COUNT(*),1)
            - (COUNT(*) FILTER (WHERE s.category='detractor'))*100/GREATEST(COUNT(*),1))::int
    FROM public.customer_nps_surveys_r2216 s
    LEFT JOIN public.organizations o ON o.id = s.hospital_org_id
    GROUP BY o.name
    ORDER BY COUNT(*) DESC
    LIMIT 50;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_nps_r2216(p_note text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2216_log', jsonb_build_object('note', p_note));
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_nps_r2216(p_survey_id uuid, p_action text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2216_action', jsonb_build_object('survey_id', p_survey_id, 'action', p_action));
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_status_nps_r2216(p_followup_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.customer_nps_followups_r2216
     SET status = p_status,
         contacted_at = CASE WHEN p_status='contacted' THEN now() ELSE contacted_at END,
         resolved_at  = CASE WHEN p_status='resolved'  THEN now() ELSE resolved_at  END
   WHERE id = p_followup_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2216_mark_status', jsonb_build_object('followup_id', p_followup_id, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.aggregate_nps_trend_r2216()
RETURNS TABLE (quarter_label text, response_count int, promoter_count int, detractor_count int, nps_score int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.quarter_label,
           COUNT(*)::int,
           (COUNT(*) FILTER (WHERE s.category='promoter'))::int,
           (COUNT(*) FILTER (WHERE s.category='detractor'))::int,
           ((COUNT(*) FILTER (WHERE s.category='promoter'))*100/GREATEST(COUNT(*),1)
            - (COUNT(*) FILTER (WHERE s.category='detractor'))*100/GREATEST(COUNT(*),1))::int
    FROM public.customer_nps_surveys_r2216 s
    GROUP BY s.quarter_label
    ORDER BY s.quarter_label DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_nps_surveys_r2216() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_nps_r2216() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_nps_by_hospital_r2216() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_nps_r2216(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_nps_r2216(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_nps_r2216(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.aggregate_nps_trend_r2216() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_nps_surveys_r2216() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_nps_r2216() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_nps_by_hospital_r2216() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_nps_r2216(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_nps_r2216(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_nps_r2216(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.aggregate_nps_trend_r2216() TO authenticated;

COMMIT;
