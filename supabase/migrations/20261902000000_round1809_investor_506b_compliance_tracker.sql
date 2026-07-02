BEGIN;

-- ============================================================================
-- Round 1809: Investor 506(b) Compliance Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_506b_compliance_r1809 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  accredited_status text NOT NULL CHECK (accredited_status IN ('verified_accredited','pre_existing_relationship','income_attested','net_worth_attested')),
  last_verified_at timestamptz,
  verification_doc_url text,
  status text NOT NULL DEFAULT 'under_review' CHECK (status IN ('current','expired','under_review','non_compliant')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS investor_506b_compliance_r1809_investor_idx
  ON public.investor_506b_compliance_r1809(investor_id);
CREATE INDEX IF NOT EXISTS investor_506b_compliance_r1809_status_idx
  ON public.investor_506b_compliance_r1809(status);

CREATE TABLE IF NOT EXISTS public.investor_506b_attestations_r1809 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  compliance_id uuid NOT NULL REFERENCES public.investor_506b_compliance_r1809(id) ON DELETE CASCADE,
  attestation_type text NOT NULL CHECK (attestation_type IN ('income','net_worth','entity_status','qualified_purchaser')),
  attestation_text text NOT NULL,
  signed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS investor_506b_attestations_r1809_compliance_idx
  ON public.investor_506b_attestations_r1809(compliance_id);
CREATE INDEX IF NOT EXISTS investor_506b_attestations_r1809_expires_idx
  ON public.investor_506b_attestations_r1809(expires_at);

ALTER TABLE public.investor_506b_compliance_r1809 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_506b_attestations_r1809 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_506b_compliance_r1809 ON public.investor_506b_compliance_r1809;
CREATE POLICY founder_all_506b_compliance_r1809
  ON public.investor_506b_compliance_r1809
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_506b_attestations_r1809 ON public.investor_506b_attestations_r1809;
CREATE POLICY founder_all_506b_attestations_r1809
  ON public.investor_506b_attestations_r1809
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC: list_compliance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_506b_compliance_r1809()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  accredited_status text,
  last_verified_at timestamptz,
  verification_doc_url text,
  status text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz
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
    c.id,
    c.investor_id,
    p.email AS investor_email,
    c.accredited_status,
    c.last_verified_at,
    c.verification_doc_url,
    c.status,
    c.notes,
    c.created_at,
    c.updated_at
  FROM public.investor_506b_compliance_r1809 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY c.updated_at DESC;
END;
$$;

-- ============================================================================
-- RPC: set_compliance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_506b_compliance_r1809(
  p_investor_id uuid,
  p_accredited_status text,
  p_verification_doc_url text DEFAULT NULL,
  p_status text DEFAULT 'under_review',
  p_notes text DEFAULT NULL
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

  INSERT INTO public.investor_506b_compliance_r1809 (
    investor_id, accredited_status, verification_doc_url, status, notes, last_verified_at
  ) VALUES (
    p_investor_id, p_accredited_status, p_verification_doc_url, p_status, p_notes,
    CASE WHEN p_status = 'current' THEN now() ELSE NULL END
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'set_506b_compliance_r1809',
    jsonb_build_object(
      'compliance_id', v_id,
      'investor_id', p_investor_id,
      'accredited_status', p_accredited_status,
      'status', p_status
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC: list_attestations
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_506b_attestations_r1809()
RETURNS TABLE (
  id uuid,
  compliance_id uuid,
  investor_id uuid,
  investor_email text,
  attestation_type text,
  attestation_text text,
  signed_at timestamptz,
  expires_at timestamptz,
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
    a.id,
    a.compliance_id,
    c.investor_id,
    p.email AS investor_email,
    a.attestation_type,
    a.attestation_text,
    a.signed_at,
    a.expires_at,
    a.created_at
  FROM public.investor_506b_attestations_r1809 a
  JOIN public.investor_506b_compliance_r1809 c ON c.id = a.compliance_id
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  ORDER BY a.signed_at DESC;
END;
$$;

-- ============================================================================
-- RPC: log_attestation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_506b_attestation_r1809(
  p_compliance_id uuid,
  p_attestation_type text,
  p_attestation_text text,
  p_expires_at timestamptz DEFAULT NULL
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

  INSERT INTO public.investor_506b_attestations_r1809 (
    compliance_id, attestation_type, attestation_text, expires_at
  ) VALUES (
    p_compliance_id, p_attestation_type, p_attestation_text, p_expires_at
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_506b_attestation_r1809',
    jsonb_build_object(
      'attestation_id', v_id,
      'compliance_id', p_compliance_id,
      'attestation_type', p_attestation_type
    )
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC: terminate_compliance
-- ============================================================================
CREATE OR REPLACE FUNCTION public.terminate_506b_compliance_r1809(
  p_compliance_id uuid,
  p_reason text DEFAULT NULL
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

  UPDATE public.investor_506b_compliance_r1809
  SET status = 'non_compliant',
      notes = COALESCE(p_reason, notes),
      updated_at = now()
  WHERE id = p_compliance_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'terminate_506b_compliance_r1809',
    jsonb_build_object(
      'compliance_id', p_compliance_id,
      'reason', p_reason
    )
  );
END;
$$;

-- ============================================================================
-- RPC: expiring_verifications
-- ============================================================================
CREATE OR REPLACE FUNCTION public.expiring_506b_verifications_r1809(
  p_days_ahead int DEFAULT 30
)
RETURNS TABLE (
  compliance_id uuid,
  investor_id uuid,
  investor_email text,
  accredited_status text,
  last_verified_at timestamptz,
  days_since_verified int,
  status text
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
    c.id AS compliance_id,
    c.investor_id,
    p.email AS investor_email,
    c.accredited_status,
    c.last_verified_at,
    EXTRACT(DAY FROM (now() - c.last_verified_at))::int AS days_since_verified,
    c.status
  FROM public.investor_506b_compliance_r1809 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  WHERE c.last_verified_at IS NOT NULL
    AND c.last_verified_at < (now() - INTERVAL '1 year' + (p_days_ahead || ' days')::interval)
    AND c.status = 'current'
  ORDER BY c.last_verified_at ASC;
END;
$$;

-- ============================================================================
-- RPC: non_compliant_investors
-- ============================================================================
CREATE OR REPLACE FUNCTION public.non_compliant_506b_investors_r1809()
RETURNS TABLE (
  compliance_id uuid,
  investor_id uuid,
  investor_email text,
  accredited_status text,
  status text,
  notes text,
  updated_at timestamptz
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
    c.id AS compliance_id,
    c.investor_id,
    p.email AS investor_email,
    c.accredited_status,
    c.status,
    c.notes,
    c.updated_at
  FROM public.investor_506b_compliance_r1809 c
  LEFT JOIN public.profiles p ON p.id = c.investor_id
  WHERE c.status IN ('non_compliant','expired')
  ORDER BY c.updated_at DESC;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_506b_compliance_r1809() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_506b_compliance_r1809(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_506b_attestations_r1809() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_506b_attestation_r1809(uuid, text, text, timestamptz) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.terminate_506b_compliance_r1809(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.expiring_506b_verifications_r1809(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.non_compliant_506b_investors_r1809() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_506b_compliance_r1809() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_506b_compliance_r1809(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_506b_attestations_r1809() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_506b_attestation_r1809(uuid, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.terminate_506b_compliance_r1809(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.expiring_506b_verifications_r1809(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.non_compliant_506b_investors_r1809() TO authenticated;

COMMIT;