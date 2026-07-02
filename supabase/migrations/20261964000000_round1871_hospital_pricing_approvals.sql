BEGIN;

-- Round 1871: Hospital Multi-Stakeholder Pricing Approvals

CREATE TABLE IF NOT EXISTS public.hospital_pricing_approvals_r1871 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  quote_id text NOT NULL,
  total_quote_rupees bigint NOT NULL DEFAULT 0,
  requires_approvals text[] NOT NULL DEFAULT ARRAY[]::text[],
  obtained_approvals text[] NOT NULL DEFAULT ARRAY[]::text[],
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','in_progress','approved','declined','expired')),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_pricing_approval_log_r1871 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  approval_id uuid NOT NULL REFERENCES public.hospital_pricing_approvals_r1871(id) ON DELETE CASCADE,
  approver_role text NOT NULL
    CHECK (approver_role IN ('cfo','cmo','procurement_head','ceo','board')),
  decision text NOT NULL
    CHECK (decision IN ('approve','decline','needs_changes')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  decision_note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hpa_r1871_status ON public.hospital_pricing_approvals_r1871(status);
CREATE INDEX IF NOT EXISTS idx_hpa_r1871_hospital ON public.hospital_pricing_approvals_r1871(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hpal_r1871_approval ON public.hospital_pricing_approval_log_r1871(approval_id);

ALTER TABLE public.hospital_pricing_approvals_r1871 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_pricing_approval_log_r1871 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hpa_r1871_founder_all ON public.hospital_pricing_approvals_r1871;
CREATE POLICY hpa_r1871_founder_all ON public.hospital_pricing_approvals_r1871
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hpal_r1871_founder_all ON public.hospital_pricing_approval_log_r1871;
CREATE POLICY hpal_r1871_founder_all ON public.hospital_pricing_approval_log_r1871
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_approvals
CREATE OR REPLACE FUNCTION public.list_pricing_approvals_r1871()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  quote_id text,
  total_quote_rupees bigint,
  requires_approvals text[],
  obtained_approvals text[],
  status text,
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
  SELECT a.id, a.hospital_user_id, p.email::text, a.quote_id, a.total_quote_rupees,
         a.requires_approvals, a.obtained_approvals, a.status, a.decided_at, a.created_at
  FROM public.hospital_pricing_approvals_r1871 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY a.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. log_approval_request (write)
CREATE OR REPLACE FUNCTION public.log_pricing_approval_request_r1871(
  p_hospital_user_id uuid,
  p_quote_id text,
  p_total_quote_rupees bigint,
  p_requires_approvals text[]
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
  INSERT INTO public.hospital_pricing_approvals_r1871(
    hospital_user_id, quote_id, total_quote_rupees, requires_approvals, status
  ) VALUES (
    p_hospital_user_id, p_quote_id, p_total_quote_rupees, p_requires_approvals, 'pending'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pricing_approval_request_r1871',
    jsonb_build_object('approval_id', v_id, 'hospital_user_id', p_hospital_user_id,
                       'quote_id', p_quote_id, 'total_quote_rupees', p_total_quote_rupees));
  RETURN v_id;
END;
$$;

-- 3. list_log
CREATE OR REPLACE FUNCTION public.list_pricing_approval_log_r1871(p_approval_id uuid)
RETURNS TABLE (
  id uuid,
  approval_id uuid,
  approver_role text,
  decision text,
  decided_at timestamptz,
  decision_note text
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
  SELECT l.id, l.approval_id, l.approver_role, l.decision, l.decided_at, l.decision_note
  FROM public.hospital_pricing_approval_log_r1871 l
  WHERE l.approval_id = p_approval_id
  ORDER BY l.decided_at DESC;
END;
$$;

-- 4. log_decision (write)
CREATE OR REPLACE FUNCTION public.log_pricing_approval_decision_r1871(
  p_approval_id uuid,
  p_approver_role text,
  p_decision text,
  p_decision_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_pricing_approval_log_r1871(
    approval_id, approver_role, decision, decision_note
  ) VALUES (
    p_approval_id, p_approver_role, p_decision, p_decision_note
  ) RETURNING id INTO v_log_id;

  IF p_decision = 'approve' THEN
    UPDATE public.hospital_pricing_approvals_r1871
    SET obtained_approvals = array_append(COALESCE(obtained_approvals, ARRAY[]::text[]), p_approver_role),
        status = 'in_progress',
        updated_at = now()
    WHERE id = p_approval_id;
  ELSIF p_decision = 'decline' THEN
    UPDATE public.hospital_pricing_approvals_r1871
    SET status = 'declined', decided_at = now(), updated_at = now()
    WHERE id = p_approval_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pricing_approval_decision_r1871',
    jsonb_build_object('approval_id', p_approval_id, 'approver_role', p_approver_role,
                       'decision', p_decision, 'log_id', v_log_id));
  RETURN v_log_id;
END;
$$;

-- 5. mark_complete (write)
CREATE OR REPLACE FUNCTION public.mark_pricing_approval_complete_r1871(p_approval_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.hospital_pricing_approvals_r1871
  SET status = 'approved', decided_at = now(), updated_at = now()
  WHERE id = p_approval_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_pricing_approval_complete_r1871',
    jsonb_build_object('approval_id', p_approval_id));
  RETURN p_approval_id;
END;
$$;

-- 6. top_pending_value
CREATE OR REPLACE FUNCTION public.top_pending_pricing_approvals_r1871()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  quote_id text,
  total_quote_rupees bigint,
  status text,
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
  SELECT a.id, a.hospital_user_id, a.quote_id, a.total_quote_rupees, a.status, a.created_at
  FROM public.hospital_pricing_approvals_r1871 a
  WHERE a.status IN ('pending','in_progress')
  ORDER BY a.total_quote_rupees DESC
  LIMIT 20;
END;
$$;

-- 7. recent_decisions
CREATE OR REPLACE FUNCTION public.recent_pricing_approval_decisions_r1871()
RETURNS TABLE (
  log_id uuid,
  approval_id uuid,
  quote_id text,
  approver_role text,
  decision text,
  decided_at timestamptz,
  decision_note text
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
  SELECT l.id, l.approval_id, a.quote_id, l.approver_role, l.decision, l.decided_at, l.decision_note
  FROM public.hospital_pricing_approval_log_r1871 l
  JOIN public.hospital_pricing_approvals_r1871 a ON a.id = l.approval_id
  ORDER BY l.decided_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pricing_approvals_r1871() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pricing_approval_request_r1871(uuid, text, bigint, text[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_pricing_approval_log_r1871(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_pricing_approval_decision_r1871(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_pricing_approval_complete_r1871(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_pending_pricing_approvals_r1871() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_pricing_approval_decisions_r1871() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_pricing_approvals_r1871() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pricing_approval_request_r1871(uuid, text, bigint, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pricing_approval_log_r1871(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_pricing_approval_decision_r1871(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_pricing_approval_complete_r1871(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_pending_pricing_approvals_r1871() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_pricing_approval_decisions_r1871() TO authenticated;

COMMIT;