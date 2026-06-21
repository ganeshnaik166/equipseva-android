BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_local_marketing_activities_r1727 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  activity_type text NOT NULL CHECK (activity_type IN ('btl_event','doctor_visit','opd_signage','local_ad','community_outreach')),
  activity_date date NOT NULL DEFAULT CURRENT_DATE,
  spend_rupees int NOT NULL DEFAULT 0,
  leads_generated int NOT NULL DEFAULT 0,
  conversions int NOT NULL DEFAULT 0,
  lead_owner_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_marketing_lead_outcomes_r1727 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id uuid NOT NULL REFERENCES public.hospital_local_marketing_activities_r1727(id) ON DELETE CASCADE,
  lead_name text NOT NULL,
  lead_org text,
  converted boolean NOT NULL DEFAULT false,
  conversion_value_rupees bigint NOT NULL DEFAULT 0,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hlma_r1727_hospital ON public.hospital_local_marketing_activities_r1727(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hlma_r1727_date ON public.hospital_local_marketing_activities_r1727(activity_date DESC);
CREATE INDEX IF NOT EXISTS idx_hmlo_r1727_activity ON public.hospital_marketing_lead_outcomes_r1727(activity_id);

-- RLS
ALTER TABLE public.hospital_local_marketing_activities_r1727 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_marketing_lead_outcomes_r1727 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hlma_r1727 ON public.hospital_local_marketing_activities_r1727;
CREATE POLICY founder_all_hlma_r1727 ON public.hospital_local_marketing_activities_r1727
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hmlo_r1727 ON public.hospital_marketing_lead_outcomes_r1727;
CREATE POLICY founder_all_hmlo_r1727 ON public.hospital_marketing_lead_outcomes_r1727
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_activities
CREATE OR REPLACE FUNCTION public.list_activities_r1727(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  activity_type text,
  activity_date date,
  spend_rupees int,
  leads_generated int,
  conversions int,
  lead_owner_email text,
  notes_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, p.email::text, a.activity_type, a.activity_date,
         a.spend_rupees, a.leads_generated, a.conversions, a.lead_owner_email,
         a.notes_md, a.created_at
  FROM public.hospital_local_marketing_activities_r1727 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY a.activity_date DESC, a.created_at DESC
  LIMIT p_limit;
END;
$$;

-- RPC 2: log_activity
CREATE OR REPLACE FUNCTION public.log_activity_r1727(
  p_hospital_user_id uuid,
  p_activity_type text,
  p_activity_date date,
  p_spend_rupees int,
  p_leads_generated int,
  p_conversions int,
  p_lead_owner_email text,
  p_notes_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_local_marketing_activities_r1727(
    hospital_user_id, activity_type, activity_date, spend_rupees,
    leads_generated, conversions, lead_owner_email, notes_md
  ) VALUES (
    p_hospital_user_id, p_activity_type, p_activity_date, p_spend_rupees,
    p_leads_generated, p_conversions, p_lead_owner_email, p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_activity_r1727',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'activity_type', p_activity_type));

  RETURN v_id;
END;
$$;

-- RPC 3: list_outcomes
CREATE OR REPLACE FUNCTION public.list_outcomes_r1727(p_activity_id uuid DEFAULT NULL, p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  activity_id uuid,
  activity_type text,
  lead_name text,
  lead_org text,
  converted boolean,
  conversion_value_rupees bigint,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.id, o.activity_id, a.activity_type, o.lead_name, o.lead_org, o.converted,
         o.conversion_value_rupees, o.recorded_at
  FROM public.hospital_marketing_lead_outcomes_r1727 o
  LEFT JOIN public.hospital_local_marketing_activities_r1727 a ON a.id = o.activity_id
  WHERE (p_activity_id IS NULL OR o.activity_id = p_activity_id)
  ORDER BY o.recorded_at DESC
  LIMIT p_limit;
END;
$$;

-- RPC 4: record_outcome
CREATE OR REPLACE FUNCTION public.record_outcome_r1727(
  p_activity_id uuid,
  p_lead_name text,
  p_lead_org text,
  p_converted boolean,
  p_conversion_value_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_marketing_lead_outcomes_r1727(
    activity_id, lead_name, lead_org, converted, conversion_value_rupees
  ) VALUES (
    p_activity_id, p_lead_name, p_lead_org, p_converted, p_conversion_value_rupees
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'record_outcome_r1727',
    jsonb_build_object('id', v_id, 'activity_id', p_activity_id, 'converted', p_converted));

  RETURN v_id;
END;
$$;

-- RPC 5: roi_summary_per_activity
CREATE OR REPLACE FUNCTION public.roi_summary_per_activity_r1727()
RETURNS TABLE(
  activity_id uuid,
  activity_type text,
  activity_date date,
  spend_rupees int,
  leads_generated int,
  conversions int,
  total_conversion_value_rupees bigint,
  roi_multiplier numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.id, a.activity_type, a.activity_date, a.spend_rupees, a.leads_generated, a.conversions,
         COALESCE(SUM(o.conversion_value_rupees) FILTER (WHERE o.converted), 0)::bigint AS total_conversion_value_rupees,
         CASE WHEN a.spend_rupees > 0
              THEN ROUND(COALESCE(SUM(o.conversion_value_rupees) FILTER (WHERE o.converted), 0)::numeric / a.spend_rupees::numeric, 2)
              ELSE 0 END AS roi_multiplier
  FROM public.hospital_local_marketing_activities_r1727 a
  LEFT JOIN public.hospital_marketing_lead_outcomes_r1727 o ON o.activity_id = a.id
  GROUP BY a.id, a.activity_type, a.activity_date, a.spend_rupees, a.leads_generated, a.conversions
  ORDER BY a.activity_date DESC;
END;
$$;

-- RPC 6: top_lead_generators
CREATE OR REPLACE FUNCTION public.top_lead_generators_r1727(p_limit int DEFAULT 10)
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_email text,
  total_activities int,
  total_leads int,
  total_conversions int,
  total_spend_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT a.hospital_user_id, p.email::text,
         (COUNT(*))::int AS total_activities,
         (COALESCE(SUM(a.leads_generated), 0))::int AS total_leads,
         (COALESCE(SUM(a.conversions), 0))::int AS total_conversions,
         (COALESCE(SUM(a.spend_rupees), 0))::bigint AS total_spend_rupees
  FROM public.hospital_local_marketing_activities_r1727 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  GROUP BY a.hospital_user_id, p.email
  ORDER BY total_leads DESC
  LIMIT p_limit;
END;
$$;

-- RPC 7: recent_conversions
CREATE OR REPLACE FUNCTION public.recent_conversions_r1727(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  activity_id uuid,
  activity_type text,
  lead_name text,
  lead_org text,
  conversion_value_rupees bigint,
  recorded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT o.id, o.activity_id, a.activity_type, o.lead_name, o.lead_org,
         o.conversion_value_rupees, o.recorded_at
  FROM public.hospital_marketing_lead_outcomes_r1727 o
  LEFT JOIN public.hospital_local_marketing_activities_r1727 a ON a.id = o.activity_id
  WHERE o.converted = true
  ORDER BY o.recorded_at DESC
  LIMIT p_limit;
END;
$$;

-- Grants
REVOKE EXECUTE ON FUNCTION public.list_activities_r1727(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_activity_r1727(uuid, text, date, int, int, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r1727(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_outcome_r1727(uuid, text, text, boolean, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.roi_summary_per_activity_r1727() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_lead_generators_r1727(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_conversions_r1727(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_activities_r1727(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_activity_r1727(uuid, text, date, int, int, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r1727(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_outcome_r1727(uuid, text, text, boolean, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.roi_summary_per_activity_r1727() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_lead_generators_r1727(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_conversions_r1727(int) TO authenticated;

COMMIT;