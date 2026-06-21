BEGIN;

-- ============================================================================
-- Round 1778: Founder Customer Reference Lookup
-- Curated customer reference list for investor diligence
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_customer_reference_lookup_r1778 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  reference_strength text NOT NULL CHECK (reference_strength IN ('strong','moderate','willing','unwilling')),
  can_speak_about text[] NOT NULL DEFAULT '{}'::text[],
  do_not_contact_until date,
  last_invoked_at timestamptz,
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','used_recently','cooldown','blacklisted')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fcrl_r1778_hospital ON public.founder_customer_reference_lookup_r1778(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fcrl_r1778_status ON public.founder_customer_reference_lookup_r1778(status);
CREATE INDEX IF NOT EXISTS idx_fcrl_r1778_strength ON public.founder_customer_reference_lookup_r1778(reference_strength);

CREATE TABLE IF NOT EXISTS public.founder_reference_invocation_log_r1778 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_id uuid NOT NULL REFERENCES public.founder_customer_reference_lookup_r1778(id) ON DELETE CASCADE,
  investor_id uuid,
  investor_label text,
  invoked_at timestamptz NOT NULL DEFAULT now(),
  prep_call_done boolean NOT NULL DEFAULT false,
  reference_call_outcome text CHECK (reference_call_outcome IN ('positive','neutral','concerning')),
  founder_post_thanks_sent boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fril_r1778_reference ON public.founder_reference_invocation_log_r1778(reference_id);
CREATE INDEX IF NOT EXISTS idx_fril_r1778_invoked ON public.founder_reference_invocation_log_r1778(invoked_at DESC);

ALTER TABLE public.founder_customer_reference_lookup_r1778 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_reference_invocation_log_r1778 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fcrl_r1778_founder_all ON public.founder_customer_reference_lookup_r1778;
CREATE POLICY fcrl_r1778_founder_all ON public.founder_customer_reference_lookup_r1778
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS fril_r1778_founder_all ON public.founder_reference_invocation_log_r1778;
CREATE POLICY fril_r1778_founder_all ON public.founder_reference_invocation_log_r1778
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_references
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_references_r1778()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  org_name text,
  city text,
  reference_strength text,
  can_speak_about text[],
  do_not_contact_until date,
  last_invoked_at timestamptz,
  status text,
  notes text,
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
  SELECT
    r.id,
    r.hospital_user_id,
    p.email::text,
    o.name::text,
    o.city::text,
    r.reference_strength,
    r.can_speak_about,
    r.do_not_contact_until,
    r.last_invoked_at,
    r.status,
    r.notes,
    r.created_at
  FROM public.founder_customer_reference_lookup_r1778 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY r.created_at DESC;
END;
$$;

-- ============================================================================
-- RPC 2: set_reference
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_reference_r1778(
  p_hospital_user_id uuid,
  p_reference_strength text,
  p_can_speak_about text[],
  p_do_not_contact_until date,
  p_notes text
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
  INSERT INTO public.founder_customer_reference_lookup_r1778
    (hospital_user_id, reference_strength, can_speak_about, do_not_contact_until, notes)
  VALUES
    (p_hospital_user_id, p_reference_strength, COALESCE(p_can_speak_about, '{}'::text[]), p_do_not_contact_until, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'set_reference_r1778',
    jsonb_build_object('reference_id', v_id, 'hospital_user_id', p_hospital_user_id, 'strength', p_reference_strength)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_invocations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_invocations_r1778()
RETURNS TABLE (
  id uuid,
  reference_id uuid,
  hospital_email text,
  org_name text,
  investor_id uuid,
  investor_label text,
  invoked_at timestamptz,
  prep_call_done boolean,
  reference_call_outcome text,
  founder_post_thanks_sent boolean,
  notes text
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
  SELECT
    l.id,
    l.reference_id,
    p.email::text,
    o.name::text,
    l.investor_id,
    l.investor_label,
    l.invoked_at,
    l.prep_call_done,
    l.reference_call_outcome,
    l.founder_post_thanks_sent,
    l.notes
  FROM public.founder_reference_invocation_log_r1778 l
  LEFT JOIN public.founder_customer_reference_lookup_r1778 r ON r.id = l.reference_id
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY l.invoked_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4: log_invocation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_invocation_r1778(
  p_reference_id uuid,
  p_investor_id uuid,
  p_investor_label text,
  p_prep_call_done boolean,
  p_notes text
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
  INSERT INTO public.founder_reference_invocation_log_r1778
    (reference_id, investor_id, investor_label, prep_call_done, notes)
  VALUES
    (p_reference_id, p_investor_id, p_investor_label, COALESCE(p_prep_call_done, false), p_notes)
  RETURNING id INTO v_id;

  UPDATE public.founder_customer_reference_lookup_r1778
     SET last_invoked_at = now(),
         updated_at = now()
   WHERE id = p_reference_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_invocation_r1778',
    jsonb_build_object('invocation_id', v_id, 'reference_id', p_reference_id, 'investor_label', p_investor_label)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_reference_used
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_reference_used_r1778(
  p_reference_id uuid,
  p_cooldown_days int
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
  UPDATE public.founder_customer_reference_lookup_r1778
     SET status = 'used_recently',
         last_invoked_at = now(),
         do_not_contact_until = (CURRENT_DATE + COALESCE(p_cooldown_days, 30)),
         updated_at = now()
   WHERE id = p_reference_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_reference_used_r1778',
    jsonb_build_object('reference_id', p_reference_id, 'cooldown_days', p_cooldown_days)
  );
END;
$$;

-- ============================================================================
-- RPC 6: available_references
-- ============================================================================
CREATE OR REPLACE FUNCTION public.available_references_r1778()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  org_name text,
  city text,
  reference_strength text,
  can_speak_about text[],
  last_invoked_at timestamptz
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
  SELECT
    r.id,
    p.email::text,
    o.name::text,
    o.city::text,
    r.reference_strength,
    r.can_speak_about,
    r.last_invoked_at
  FROM public.founder_customer_reference_lookup_r1778 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE r.status = 'available'
    AND r.reference_strength IN ('strong','moderate','willing')
    AND (r.do_not_contact_until IS NULL OR r.do_not_contact_until <= CURRENT_DATE)
  ORDER BY
    CASE r.reference_strength
      WHEN 'strong' THEN 1
      WHEN 'moderate' THEN 2
      WHEN 'willing' THEN 3
      ELSE 4
    END,
    r.last_invoked_at NULLS FIRST;
END;
$$;

-- ============================================================================
-- RPC 7: cooldown_releases
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cooldown_releases_r1778()
RETURNS TABLE (
  id uuid,
  hospital_email text,
  org_name text,
  reference_strength text,
  status text,
  do_not_contact_until date,
  days_until_release int
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
  SELECT
    r.id,
    p.email::text,
    o.name::text,
    r.reference_strength,
    r.status,
    r.do_not_contact_until,
    GREATEST(0, (r.do_not_contact_until - CURRENT_DATE))::int
  FROM public.founder_customer_reference_lookup_r1778 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  WHERE r.do_not_contact_until IS NOT NULL
    AND r.status IN ('used_recently','cooldown')
  ORDER BY r.do_not_contact_until ASC;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_references_r1778() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_reference_r1778(uuid, text, text[], date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_invocations_r1778() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_invocation_r1778(uuid, uuid, text, boolean, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_reference_used_r1778(uuid, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.available_references_r1778() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.cooldown_releases_r1778() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_references_r1778() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_reference_r1778(uuid, text, text[], date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_invocations_r1778() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_invocation_r1778(uuid, uuid, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_reference_used_r1778(uuid, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.available_references_r1778() TO authenticated;
GRANT EXECUTE ON FUNCTION public.cooldown_releases_r1778() TO authenticated;

COMMIT;