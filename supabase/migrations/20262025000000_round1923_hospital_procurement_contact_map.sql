BEGIN;

-- ============================================================================
-- Round 1923: Hospital Procurement Contact Map
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.hospital_procurement_contacts_r1923 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  contact_name text NOT NULL,
  contact_email text NOT NULL,
  role text NOT NULL CHECK (role IN ('head_procurement','clinical_engineering','finance','biomedical','admin')),
  decision_power text NOT NULL CHECK (decision_power IN ('final','recommend','influence','none')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive','replaced')),
  last_contacted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpcr1923_hospital ON public.hospital_procurement_contacts_r1923(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hpcr1923_role ON public.hospital_procurement_contacts_r1923(role);
CREATE INDEX IF NOT EXISTS idx_hpcr1923_status ON public.hospital_procurement_contacts_r1923(status);

CREATE TABLE IF NOT EXISTS public.hospital_procurement_outreach_log_r1923 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.hospital_procurement_contacts_r1923(id) ON DELETE CASCADE,
  outreach_type text NOT NULL CHECK (outreach_type IN ('intro_call','discovery','proposal_sent','follow_up','negotiation','close_won','close_lost')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpolr1923_contact ON public.hospital_procurement_outreach_log_r1923(contact_id);
CREATE INDEX IF NOT EXISTS idx_hpolr1923_taken_at ON public.hospital_procurement_outreach_log_r1923(taken_at DESC);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------

ALTER TABLE public.hospital_procurement_contacts_r1923 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_procurement_outreach_log_r1923 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hpc_r1923 ON public.hospital_procurement_contacts_r1923;
CREATE POLICY founder_all_hpc_r1923 ON public.hospital_procurement_contacts_r1923
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hpol_r1923 ON public.hospital_procurement_outreach_log_r1923;
CREATE POLICY founder_all_hpol_r1923 ON public.hospital_procurement_outreach_log_r1923
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ----------------------------------------------------------------------------
-- RPCs
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.r1923_list_contacts(
  p_hospital_id uuid DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 200
)
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_name text,
  contact_name text,
  contact_email text,
  role text,
  decision_power text,
  status text,
  last_contacted_at timestamptz,
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
  SELECT c.id, c.hospital_id, o.name, c.contact_name, c.contact_email,
         c.role, c.decision_power, c.status, c.last_contacted_at, c.created_at
  FROM public.hospital_procurement_contacts_r1923 c
  LEFT JOIN public.organizations o ON o.id = c.hospital_id
  WHERE (p_hospital_id IS NULL OR c.hospital_id = p_hospital_id)
    AND (p_status IS NULL OR c.status = p_status)
  ORDER BY c.created_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 200), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.r1923_log_contact(
  p_hospital_id uuid,
  p_contact_name text,
  p_contact_email text,
  p_role text,
  p_decision_power text
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

  INSERT INTO public.hospital_procurement_contacts_r1923 (
    hospital_id, contact_name, contact_email, role, decision_power
  ) VALUES (
    p_hospital_id, p_contact_name, p_contact_email, p_role, p_decision_power
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1923_log_contact',
    jsonb_build_object('contact_id', v_id, 'hospital_id', p_hospital_id, 'role', p_role)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1923_list_outreach(
  p_contact_id uuid DEFAULT NULL,
  p_limit int DEFAULT 200
)
RETURNS TABLE (
  id uuid,
  contact_id uuid,
  contact_name text,
  outreach_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
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
  SELECT l.id, l.contact_id, c.contact_name, l.outreach_type, l.taken_at, l.by_email, l.outcome_md
  FROM public.hospital_procurement_outreach_log_r1923 l
  LEFT JOIN public.hospital_procurement_contacts_r1923 c ON c.id = l.contact_id
  WHERE (p_contact_id IS NULL OR l.contact_id = p_contact_id)
  ORDER BY l.taken_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 200), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.r1923_log_outreach(
  p_contact_id uuid,
  p_outreach_type text,
  p_outcome_md text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.hospital_procurement_outreach_log_r1923 (
    contact_id, outreach_type, by_email, outcome_md
  ) VALUES (
    p_contact_id, p_outreach_type, v_email, p_outcome_md
  )
  RETURNING id INTO v_id;

  UPDATE public.hospital_procurement_contacts_r1923
  SET last_contacted_at = now(), updated_at = now()
  WHERE id = p_contact_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'r1923_log_outreach',
    jsonb_build_object('outreach_id', v_id, 'contact_id', p_contact_id, 'outreach_type', p_outreach_type)
  );

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.r1923_mark_status(
  p_contact_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.hospital_procurement_contacts_r1923
  SET status = p_status, updated_at = now()
  WHERE id = p_contact_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1923_mark_status',
    jsonb_build_object('contact_id', p_contact_id, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.r1923_top_decision_makers(
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  contact_id uuid,
  hospital_id uuid,
  hospital_name text,
  contact_name text,
  contact_email text,
  role text,
  decision_power text,
  outreach_count bigint,
  last_contacted_at timestamptz
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
  SELECT c.id, c.hospital_id, o.name, c.contact_name, c.contact_email,
         c.role, c.decision_power,
         COALESCE(COUNT(l.id), 0)::bigint,
         c.last_contacted_at
  FROM public.hospital_procurement_contacts_r1923 c
  LEFT JOIN public.organizations o ON o.id = c.hospital_id
  LEFT JOIN public.hospital_procurement_outreach_log_r1923 l ON l.contact_id = c.id
  WHERE c.status = 'active'
    AND c.decision_power IN ('final','recommend')
  GROUP BY c.id, o.name
  ORDER BY
    CASE c.decision_power WHEN 'final' THEN 1 WHEN 'recommend' THEN 2 ELSE 3 END,
    COALESCE(COUNT(l.id), 0) DESC,
    c.last_contacted_at DESC NULLS LAST
  LIMIT GREATEST(COALESCE(p_limit, 50), 1);
END;
$$;

CREATE OR REPLACE FUNCTION public.r1923_recent_outreach(
  p_days int DEFAULT 14,
  p_limit int DEFAULT 100
)
RETURNS TABLE (
  outreach_id uuid,
  contact_id uuid,
  contact_name text,
  hospital_name text,
  outreach_type text,
  taken_at timestamptz,
  by_email text
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
  SELECT l.id, l.contact_id, c.contact_name, o.name, l.outreach_type, l.taken_at, l.by_email
  FROM public.hospital_procurement_outreach_log_r1923 l
  LEFT JOIN public.hospital_procurement_contacts_r1923 c ON c.id = l.contact_id
  LEFT JOIN public.organizations o ON o.id = c.hospital_id
  WHERE l.taken_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 14), 1))
  ORDER BY l.taken_at DESC
  LIMIT GREATEST(COALESCE(p_limit, 100), 1);
END;
$$;

-- ----------------------------------------------------------------------------
-- Permissions
-- ----------------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.r1923_list_contacts(uuid, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1923_log_contact(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1923_list_outreach(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1923_log_outreach(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1923_mark_status(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1923_top_decision_makers(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.r1923_recent_outreach(int, int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r1923_list_contacts(uuid, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1923_log_contact(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1923_list_outreach(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1923_log_outreach(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1923_mark_status(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1923_top_decision_makers(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r1923_recent_outreach(int, int) TO authenticated;

COMMIT;
