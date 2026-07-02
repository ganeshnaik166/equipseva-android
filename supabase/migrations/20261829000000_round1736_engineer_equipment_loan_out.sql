BEGIN;

-- ============================================================================
-- Round 1736: Engineer Equipment Loan Out
-- Track tools/diagnostics loaned engineer-to-engineer
-- ============================================================================

-- Table 1: engineer_equipment_loans_r1736
CREATE TABLE IF NOT EXISTS public.engineer_equipment_loans_r1736 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lender_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  borrower_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  loaned_at timestamptz NOT NULL DEFAULT now(),
  expected_return_at timestamptz,
  returned_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','returned','overdue','lost')),
  founder_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eel_r1736_lender ON public.engineer_equipment_loans_r1736(lender_user_id);
CREATE INDEX IF NOT EXISTS idx_eel_r1736_borrower ON public.engineer_equipment_loans_r1736(borrower_user_id);
CREATE INDEX IF NOT EXISTS idx_eel_r1736_status ON public.engineer_equipment_loans_r1736(status);
CREATE INDEX IF NOT EXISTS idx_eel_r1736_expected ON public.engineer_equipment_loans_r1736(expected_return_at);

ALTER TABLE public.engineer_equipment_loans_r1736 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_loans_r1736 ON public.engineer_equipment_loans_r1736;
CREATE POLICY founder_all_loans_r1736 ON public.engineer_equipment_loans_r1736
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: engineer_loan_return_log_r1736
CREATE TABLE IF NOT EXISTS public.engineer_loan_return_log_r1736 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id uuid NOT NULL REFERENCES public.engineer_equipment_loans_r1736(id) ON DELETE CASCADE,
  returned_condition text NOT NULL CHECK (returned_condition IN ('pristine','wear','damaged','lost')),
  returned_at timestamptz NOT NULL DEFAULT now(),
  dispute_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_elrl_r1736_loan ON public.engineer_loan_return_log_r1736(loan_id);
CREATE INDEX IF NOT EXISTS idx_elrl_r1736_condition ON public.engineer_loan_return_log_r1736(returned_condition);

ALTER TABLE public.engineer_loan_return_log_r1736 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_returns_r1736 ON public.engineer_loan_return_log_r1736;
CREATE POLICY founder_all_returns_r1736 ON public.engineer_loan_return_log_r1736
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_loans
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_loans_r1736();
CREATE OR REPLACE FUNCTION public.list_loans_r1736()
RETURNS TABLE (
  id uuid,
  lender_user_id uuid,
  borrower_user_id uuid,
  lender_email text,
  borrower_email text,
  equipment_name text,
  loaned_at timestamptz,
  expected_return_at timestamptz,
  returned_at timestamptz,
  status text,
  founder_note text,
  days_outstanding int
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
    l.lender_user_id,
    l.borrower_user_id,
    lp.email::text AS lender_email,
    bp.email::text AS borrower_email,
    l.equipment_name,
    l.loaned_at,
    l.expected_return_at,
    l.returned_at,
    l.status,
    l.founder_note,
    GREATEST(0, EXTRACT(day FROM (COALESCE(l.returned_at, now()) - l.loaned_at))::int) AS days_outstanding
  FROM public.engineer_equipment_loans_r1736 l
  LEFT JOIN public.profiles lp ON lp.id = l.lender_user_id
  LEFT JOIN public.profiles bp ON bp.id = l.borrower_user_id
  ORDER BY l.loaned_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_loans_r1736() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loans_r1736() TO authenticated;

-- ============================================================================
-- RPC 2: log_loan
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_loan_r1736(uuid, uuid, text, timestamptz, text);
CREATE OR REPLACE FUNCTION public.log_loan_r1736(
  p_lender_user_id uuid,
  p_borrower_user_id uuid,
  p_equipment_name text,
  p_expected_return_at timestamptz DEFAULT NULL,
  p_founder_note text DEFAULT NULL
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

  INSERT INTO public.engineer_equipment_loans_r1736(
    lender_user_id, borrower_user_id, equipment_name, expected_return_at, founder_note
  ) VALUES (
    p_lender_user_id, p_borrower_user_id, p_equipment_name, p_expected_return_at, p_founder_note
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_loan_r1736',
    jsonb_build_object(
      'loan_id', v_id,
      'lender_user_id', p_lender_user_id,
      'borrower_user_id', p_borrower_user_id,
      'equipment_name', p_equipment_name
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_loan_r1736(uuid, uuid, text, timestamptz, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_loan_r1736(uuid, uuid, text, timestamptz, text) TO authenticated;

-- ============================================================================
-- RPC 3: list_returns
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_returns_r1736();
CREATE OR REPLACE FUNCTION public.list_returns_r1736()
RETURNS TABLE (
  id uuid,
  loan_id uuid,
  equipment_name text,
  borrower_email text,
  returned_condition text,
  returned_at timestamptz,
  dispute_reason text
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
    r.loan_id,
    l.equipment_name,
    bp.email::text AS borrower_email,
    r.returned_condition,
    r.returned_at,
    r.dispute_reason
  FROM public.engineer_loan_return_log_r1736 r
  LEFT JOIN public.engineer_equipment_loans_r1736 l ON l.id = r.loan_id
  LEFT JOIN public.profiles bp ON bp.id = l.borrower_user_id
  ORDER BY r.returned_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_returns_r1736() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_returns_r1736() TO authenticated;

-- ============================================================================
-- RPC 4: record_return
-- ============================================================================
DROP FUNCTION IF EXISTS public.record_return_r1736(uuid, text, text);
CREATE OR REPLACE FUNCTION public.record_return_r1736(
  p_loan_id uuid,
  p_returned_condition text,
  p_dispute_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_new_status text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_loan_return_log_r1736(loan_id, returned_condition, dispute_reason)
  VALUES (p_loan_id, p_returned_condition, p_dispute_reason)
  RETURNING id INTO v_id;

  v_new_status := CASE WHEN p_returned_condition = 'lost' THEN 'lost' ELSE 'returned' END;

  UPDATE public.engineer_equipment_loans_r1736
  SET returned_at = now(),
      status = v_new_status,
      updated_at = now()
  WHERE id = p_loan_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'record_return_r1736',
    jsonb_build_object(
      'return_id', v_id,
      'loan_id', p_loan_id,
      'condition', p_returned_condition,
      'new_status', v_new_status
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_return_r1736(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_return_r1736(uuid, text, text) TO authenticated;

-- ============================================================================
-- RPC 5: mark_overdue
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_overdue_r1736(uuid);
CREATE OR REPLACE FUNCTION public.mark_overdue_r1736(p_loan_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.engineer_equipment_loans_r1736
  SET status = 'overdue',
      updated_at = now()
  WHERE id = p_loan_id
    AND status = 'active';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_overdue_r1736',
    jsonb_build_object('loan_id', p_loan_id)
  );

  RETURN p_loan_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_overdue_r1736(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_overdue_r1736(uuid) TO authenticated;

-- ============================================================================
-- RPC 6: overdue_loans
-- ============================================================================
DROP FUNCTION IF EXISTS public.overdue_loans_r1736();
CREATE OR REPLACE FUNCTION public.overdue_loans_r1736()
RETURNS TABLE (
  id uuid,
  borrower_email text,
  lender_email text,
  equipment_name text,
  loaned_at timestamptz,
  expected_return_at timestamptz,
  days_overdue int,
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
    l.id,
    bp.email::text AS borrower_email,
    lp.email::text AS lender_email,
    l.equipment_name,
    l.loaned_at,
    l.expected_return_at,
    GREATEST(0, EXTRACT(day FROM (now() - l.expected_return_at))::int) AS days_overdue,
    l.status
  FROM public.engineer_equipment_loans_r1736 l
  LEFT JOIN public.profiles bp ON bp.id = l.borrower_user_id
  LEFT JOIN public.profiles lp ON lp.id = l.lender_user_id
  WHERE l.status IN ('active','overdue')
    AND l.expected_return_at IS NOT NULL
    AND l.expected_return_at < now()
  ORDER BY l.expected_return_at ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.overdue_loans_r1736() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_loans_r1736() TO authenticated;

-- ============================================================================
-- RPC 7: top_borrowers
-- ============================================================================
DROP FUNCTION IF EXISTS public.top_borrowers_r1736();
CREATE OR REPLACE FUNCTION public.top_borrowers_r1736()
RETURNS TABLE (
  borrower_user_id uuid,
  borrower_email text,
  total_loans int,
  active_loans int,
  overdue_loans int,
  lost_loans int
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
    l.borrower_user_id,
    bp.email::text AS borrower_email,
    (COUNT(*))::int AS total_loans,
    (COUNT(*) FILTER (WHERE l.status = 'active'))::int AS active_loans,
    (COUNT(*) FILTER (WHERE l.status = 'overdue'))::int AS overdue_loans,
    (COUNT(*) FILTER (WHERE l.status = 'lost'))::int AS lost_loans
  FROM public.engineer_equipment_loans_r1736 l
  LEFT JOIN public.profiles bp ON bp.id = l.borrower_user_id
  GROUP BY l.borrower_user_id, bp.email
  ORDER BY total_loans DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_borrowers_r1736() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_borrowers_r1736() TO authenticated;

COMMIT;