BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_biomed_staff_r2199 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  staff_name text NOT NULL,
  staff_email text,
  role_title text NOT NULL,
  years_experience int NOT NULL DEFAULT 0,
  modalities_covered text[] NOT NULL DEFAULT '{}',
  competency_score int NOT NULL DEFAULT 0,
  gap_flag text NOT NULL DEFAULT 'ok',
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.hospital_biomed_certifications_r2199 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES public.hospital_biomed_staff_r2199(id) ON DELETE CASCADE,
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  cert_name text NOT NULL,
  issuing_body text,
  issued_on date,
  expires_on date,
  status text NOT NULL DEFAULT 'active',
  days_to_expiry int,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id)
);

-- RLS
ALTER TABLE public.hospital_biomed_staff_r2199 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_biomed_certifications_r2199 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_biomed_staff_r2199;
CREATE POLICY founder_all ON public.hospital_biomed_staff_r2199
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_biomed_certifications_r2199;
CREATE POLICY founder_all ON public.hospital_biomed_certifications_r2199
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list staff
CREATE OR REPLACE FUNCTION public.list_biomed_staff_r2199()
RETURNS TABLE(
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  staff_name text,
  role_title text,
  years_experience int,
  modalities_covered text[],
  competency_score int,
  gap_flag text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.hospital_org_id, o.name, s.staff_name, s.role_title,
         s.years_experience, s.modalities_covered, s.competency_score,
         s.gap_flag, s.created_at
  FROM public.hospital_biomed_staff_r2199 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_org_id
  ORDER BY s.created_at DESC
  LIMIT 200;
END;
$$;

-- RPC 2: recent actions
CREATE OR REPLACE FUNCTION public.recent_actions_r2199()
RETURNS TABLE(
  id uuid,
  actor_email text,
  op_name text,
  after_value jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.actor_email, l.op_name, l.after_value, l.created_at
  FROM public.founder_action_log l
  WHERE l.op_name LIKE 'op_r2199%'
  ORDER BY l.created_at DESC
  LIMIT 100;
END;
$$;

-- RPC 3: top hospitals by staff competency
CREATE OR REPLACE FUNCTION public.top_hospitals_r2199()
RETURNS TABLE(
  hospital_org_id uuid,
  hospital_name text,
  staff_count int,
  avg_competency numeric,
  expiring_cert_count int,
  gap_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.hospital_org_id,
         o.name,
         COUNT(*)::int,
         ROUND(AVG(s.competency_score)::numeric, 2),
         (SELECT COUNT(*) FILTER (WHERE c.expires_on IS NOT NULL AND c.expires_on <= (now()::date + 60))
            FROM public.hospital_biomed_certifications_r2199 c
            WHERE c.hospital_org_id = s.hospital_org_id)::int,
         (COUNT(*) FILTER (WHERE s.gap_flag <> 'ok'))::int
  FROM public.hospital_biomed_staff_r2199 s
  LEFT JOIN public.organizations o ON o.id = s.hospital_org_id
  GROUP BY s.hospital_org_id, o.name
  ORDER BY COUNT(*) DESC
  LIMIT 50;
END;
$$;

-- RPC 4: log new staff entry
CREATE OR REPLACE FUNCTION public.log_biomed_staff_r2199(
  p_hospital_org_id uuid,
  p_staff_name text,
  p_role_title text,
  p_years_experience int,
  p_modalities text[],
  p_competency_score int,
  p_gap_flag text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_biomed_staff_r2199(
    hospital_org_id, staff_name, role_title, years_experience,
    modalities_covered, competency_score, gap_flag, notes, created_by
  ) VALUES (
    p_hospital_org_id, p_staff_name, p_role_title, p_years_experience,
    COALESCE(p_modalities,'{}'), p_competency_score, COALESCE(p_gap_flag,'ok'),
    p_notes, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2199_log_staff',
          jsonb_build_object('staff_id', v_id, 'hospital_org_id', p_hospital_org_id,
                             'staff_name', p_staff_name, 'gap_flag', p_gap_flag));
  RETURN v_id;
END;
$$;

-- RPC 5: generic log action
CREATE OR REPLACE FUNCTION public.log_action_r2199(p_op text, p_payload jsonb)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'),
          'op_r2199_' || COALESCE(p_op,'noop'),
          COALESCE(p_payload, '{}'::jsonb));
END;
$$;

-- RPC 6: mark status on a staff row
CREATE OR REPLACE FUNCTION public.mark_status_r2199(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_biomed_staff_r2199
    SET gap_flag = COALESCE(p_status,'ok')
  WHERE id = p_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2199_mark_status',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- RPC 7: aggregate — certifications expiry bucket roll-up
CREATE OR REPLACE FUNCTION public.cert_expiry_buckets_r2199()
RETURNS TABLE(
  bucket text,
  cert_count int,
  hospitals_affected int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.bucket,
         (COUNT(*) FILTER (WHERE c.id IS NOT NULL))::int,
         (COUNT(DISTINCT c.hospital_org_id) FILTER (WHERE c.id IS NOT NULL))::int
  FROM (VALUES ('expired'), ('lt_30d'), ('lt_60d'), ('lt_90d'), ('gt_90d')) AS b(bucket)
  LEFT JOIN public.hospital_biomed_certifications_r2199 c
    ON (b.bucket = 'expired'  AND c.expires_on IS NOT NULL AND c.expires_on <  now()::date)
    OR (b.bucket = 'lt_30d'   AND c.expires_on IS NOT NULL AND c.expires_on >= now()::date AND c.expires_on <  now()::date + 30)
    OR (b.bucket = 'lt_60d'   AND c.expires_on IS NOT NULL AND c.expires_on >= now()::date + 30 AND c.expires_on <  now()::date + 60)
    OR (b.bucket = 'lt_90d'   AND c.expires_on IS NOT NULL AND c.expires_on >= now()::date + 60 AND c.expires_on <  now()::date + 90)
    OR (b.bucket = 'gt_90d'   AND c.expires_on IS NOT NULL AND c.expires_on >= now()::date + 90)
  GROUP BY b.bucket
  ORDER BY b.bucket;
END;
$$;

-- Lock down grants
REVOKE ALL ON FUNCTION public.list_biomed_staff_r2199()       FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2199()          FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_hospitals_r2199()           FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_biomed_staff_r2199(uuid, text, text, int, text[], int, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2199(text, jsonb)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2199(uuid, text)   FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cert_expiry_buckets_r2199()     FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_biomed_staff_r2199()       TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2199()          TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_hospitals_r2199()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_biomed_staff_r2199(uuid, text, text, int, text[], int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2199(text, jsonb)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2199(uuid, text)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.cert_expiry_buckets_r2199()     TO authenticated;

COMMIT;
