BEGIN;

-- ============================================================================
-- Round 1836: Engineer Health Insurance Claims
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_health_insurance_claims_r1836 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  claim_date date NOT NULL DEFAULT CURRENT_DATE,
  claim_amount_rupees bigint NOT NULL CHECK (claim_amount_rupees >= 0),
  claim_type text NOT NULL CHECK (claim_type IN ('inpatient','outpatient','diagnostic','maternity','preventive','dental')),
  insurer_name text NOT NULL,
  status text NOT NULL DEFAULT 'filed' CHECK (status IN ('filed','processing','approved','rejected','paid')),
  payout_rupees bigint CHECK (payout_rupees IS NULL OR payout_rupees >= 0),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehic_r1836_engineer ON public.engineer_health_insurance_claims_r1836(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_ehic_r1836_status ON public.engineer_health_insurance_claims_r1836(status);
CREATE INDEX IF NOT EXISTS idx_ehic_r1836_date ON public.engineer_health_insurance_claims_r1836(claim_date DESC);

CREATE TABLE IF NOT EXISTS public.engineer_health_insurance_notes_r1836 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.engineer_health_insurance_claims_r1836(id) ON DELETE CASCADE,
  note_text text NOT NULL,
  note_by_email text NOT NULL,
  note_at timestamptz NOT NULL DEFAULT now(),
  requires_action boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehin_r1836_claim ON public.engineer_health_insurance_notes_r1836(claim_id);
CREATE INDEX IF NOT EXISTS idx_ehin_r1836_at ON public.engineer_health_insurance_notes_r1836(note_at DESC);

ALTER TABLE public.engineer_health_insurance_claims_r1836 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_health_insurance_notes_r1836 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ehic_r1836_founder ON public.engineer_health_insurance_claims_r1836;
CREATE POLICY ehic_r1836_founder ON public.engineer_health_insurance_claims_r1836
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS ehin_r1836_founder ON public.engineer_health_insurance_notes_r1836;
CREATE POLICY ehin_r1836_founder ON public.engineer_health_insurance_notes_r1836
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_claims
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_engineer_health_claims_r1836(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 200
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  claim_date date,
  claim_amount_rupees bigint,
  claim_type text,
  insurer_name text,
  status text,
  payout_rupees bigint,
  decided_at timestamptz,
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
    c.id,
    c.engineer_user_id,
    p.email::text AS engineer_email,
    c.claim_date,
    c.claim_amount_rupees,
    c.claim_type,
    c.insurer_name,
    c.status,
    c.payout_rupees,
    c.decided_at,
    c.created_at
  FROM public.engineer_health_insurance_claims_r1836 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE (p_status IS NULL OR c.status = p_status)
  ORDER BY c.claim_date DESC, c.created_at DESC
  LIMIT COALESCE(p_limit, 200);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_engineer_health_claims_r1836(text, int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_health_claims_r1836(text, int) TO authenticated;

-- ============================================================================
-- RPC 2: file_claim
-- ============================================================================
CREATE OR REPLACE FUNCTION public.file_engineer_health_claim_r1836(
  p_engineer_user_id uuid,
  p_claim_date date,
  p_claim_amount_rupees bigint,
  p_claim_type text,
  p_insurer_name text
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

  INSERT INTO public.engineer_health_insurance_claims_r1836 (
    engineer_user_id, claim_date, claim_amount_rupees, claim_type, insurer_name, status
  ) VALUES (
    p_engineer_user_id, p_claim_date, p_claim_amount_rupees, p_claim_type, p_insurer_name, 'filed'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'file_engineer_health_claim_r1836',
    jsonb_build_object('claim_id', v_id, 'engineer_user_id', p_engineer_user_id, 'amount', p_claim_amount_rupees));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.file_engineer_health_claim_r1836(uuid, date, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.file_engineer_health_claim_r1836(uuid, date, bigint, text, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_notes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_engineer_health_claim_notes_r1836(
  p_claim_id uuid
)
RETURNS TABLE (
  id uuid,
  claim_id uuid,
  note_text text,
  note_by_email text,
  note_at timestamptz,
  requires_action boolean
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
  SELECT n.id, n.claim_id, n.note_text, n.note_by_email, n.note_at, n.requires_action
  FROM public.engineer_health_insurance_notes_r1836 n
  WHERE n.claim_id = p_claim_id
  ORDER BY n.note_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_engineer_health_claim_notes_r1836(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engineer_health_claim_notes_r1836(uuid) TO authenticated;

-- ============================================================================
-- RPC 4: add_note
-- ============================================================================
CREATE OR REPLACE FUNCTION public.add_engineer_health_claim_note_r1836(
  p_claim_id uuid,
  p_note_text text,
  p_requires_action boolean DEFAULT false
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

  INSERT INTO public.engineer_health_insurance_notes_r1836 (
    claim_id, note_text, note_by_email, requires_action
  ) VALUES (
    p_claim_id, p_note_text, COALESCE(v_email, 'founder'), p_requires_action
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), v_email, 'add_engineer_health_claim_note_r1836',
    jsonb_build_object('note_id', v_id, 'claim_id', p_claim_id, 'requires_action', p_requires_action));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_engineer_health_claim_note_r1836(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_engineer_health_claim_note_r1836(uuid, text, boolean) TO authenticated;

-- ============================================================================
-- RPC 5: mark_paid
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_engineer_health_claim_paid_r1836(
  p_claim_id uuid,
  p_payout_rupees bigint
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

  UPDATE public.engineer_health_insurance_claims_r1836
  SET status = 'paid',
      payout_rupees = p_payout_rupees,
      decided_at = COALESCE(decided_at, now()),
      updated_at = now()
  WHERE id = p_claim_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_engineer_health_claim_paid_r1836',
    jsonb_build_object('claim_id', p_claim_id, 'payout_rupees', p_payout_rupees));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_engineer_health_claim_paid_r1836(uuid, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_engineer_health_claim_paid_r1836(uuid, bigint) TO authenticated;

-- ============================================================================
-- RPC 6: claims_summary_per_engineer
-- ============================================================================
CREATE OR REPLACE FUNCTION public.engineer_health_claims_summary_per_engineer_r1836()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_claims int,
  filed_count int,
  processing_count int,
  approved_count int,
  rejected_count int,
  paid_count int,
  total_claimed_rupees bigint,
  total_payout_rupees bigint
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
    c.engineer_user_id,
    p.email::text AS engineer_email,
    (COUNT(*))::int AS total_claims,
    (COUNT(*) FILTER (WHERE c.status = 'filed'))::int AS filed_count,
    (COUNT(*) FILTER (WHERE c.status = 'processing'))::int AS processing_count,
    (COUNT(*) FILTER (WHERE c.status = 'approved'))::int AS approved_count,
    (COUNT(*) FILTER (WHERE c.status = 'rejected'))::int AS rejected_count,
    (COUNT(*) FILTER (WHERE c.status = 'paid'))::int AS paid_count,
    COALESCE(SUM(c.claim_amount_rupees), 0)::bigint AS total_claimed_rupees,
    COALESCE(SUM(c.payout_rupees), 0)::bigint AS total_payout_rupees
  FROM public.engineer_health_insurance_claims_r1836 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  GROUP BY c.engineer_user_id, p.email
  ORDER BY total_claims DESC, total_payout_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_health_claims_summary_per_engineer_r1836() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_health_claims_summary_per_engineer_r1836() TO authenticated;

-- ============================================================================
-- RPC 7: recent_claims
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_engineer_health_claims_r1836(
  p_days int DEFAULT 30
)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  claim_date date,
  claim_amount_rupees bigint,
  claim_type text,
  insurer_name text,
  status text,
  payout_rupees bigint,
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
    c.id,
    c.engineer_user_id,
    p.email::text AS engineer_email,
    c.claim_date,
    c.claim_amount_rupees,
    c.claim_type,
    c.insurer_name,
    c.status,
    c.payout_rupees,
    c.created_at
  FROM public.engineer_health_insurance_claims_r1836 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.created_at >= (now() - (COALESCE(p_days, 30) || ' days')::interval)
  ORDER BY c.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_engineer_health_claims_r1836(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_engineer_health_claims_r1836(int) TO authenticated;

COMMIT;