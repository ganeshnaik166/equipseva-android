BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_promotion_proposals_r1780 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  current_tier text NOT NULL,
  proposed_tier text NOT NULL,
  proposer_email text NOT NULL,
  justification_md text,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','under_review','approved','declined','withdrawn')),
  proposed_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.engineer_promotion_approval_log_r1780 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  proposal_id uuid NOT NULL REFERENCES public.engineer_promotion_proposals_r1780(id) ON DELETE CASCADE,
  approver_email text NOT NULL,
  approver_role text NOT NULL CHECK (approver_role IN ('manager','founder','peer','customer')),
  decision text NOT NULL CHECK (decision IN ('approve','reject','needs_more_info')),
  decision_note text,
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_promotion_proposals_r1780 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.engineer_promotion_approval_log_r1780 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_proposals_r1780 ON public.engineer_promotion_proposals_r1780;
CREATE POLICY founder_all_proposals_r1780 ON public.engineer_promotion_proposals_r1780
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_approval_log_r1780 ON public.engineer_promotion_approval_log_r1780;
CREATE POLICY founder_all_approval_log_r1780 ON public.engineer_promotion_approval_log_r1780
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_promotion_proposals_r1780_status ON public.engineer_promotion_proposals_r1780(status, proposed_at DESC);
CREATE INDEX IF NOT EXISTS idx_promotion_proposals_r1780_engineer ON public.engineer_promotion_proposals_r1780(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_promotion_approval_log_r1780_proposal ON public.engineer_promotion_approval_log_r1780(proposal_id, decided_at DESC);

CREATE OR REPLACE FUNCTION public.list_proposals_r1780()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  current_tier text,
  proposed_tier text,
  proposer_email text,
  status text,
  proposed_at timestamptz,
  decided_at timestamptz,
  approval_count int
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
  SELECT p.id, p.engineer_user_id, pr.email, p.current_tier, p.proposed_tier,
         p.proposer_email, p.status, p.proposed_at, p.decided_at,
         (SELECT COUNT(*) FROM public.engineer_promotion_approval_log_r1780 l WHERE l.proposal_id = p.id)::int
  FROM public.engineer_promotion_proposals_r1780 p
  LEFT JOIN public.profiles pr ON pr.id = p.engineer_user_id
  ORDER BY p.proposed_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.propose_promotion_r1780(
  p_engineer_user_id uuid,
  p_current_tier text,
  p_proposed_tier text,
  p_proposer_email text,
  p_justification_md text
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
  INSERT INTO public.engineer_promotion_proposals_r1780(
    engineer_user_id, current_tier, proposed_tier, proposer_email, justification_md, status
  ) VALUES (
    p_engineer_user_id, p_current_tier, p_proposed_tier, p_proposer_email, p_justification_md, 'proposed'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'propose_promotion_r1780',
    jsonb_build_object('proposal_id', v_id, 'engineer_user_id', p_engineer_user_id, 'proposed_tier', p_proposed_tier));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_approvals_r1780(p_proposal_id uuid)
RETURNS TABLE (
  id uuid,
  proposal_id uuid,
  approver_email text,
  approver_role text,
  decision text,
  decision_note text,
  decided_at timestamptz
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
  SELECT l.id, l.proposal_id, l.approver_email, l.approver_role, l.decision, l.decision_note, l.decided_at
  FROM public.engineer_promotion_approval_log_r1780 l
  WHERE l.proposal_id = p_proposal_id
  ORDER BY l.decided_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_approval_r1780(
  p_proposal_id uuid,
  p_approver_email text,
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
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.engineer_promotion_approval_log_r1780(
    proposal_id, approver_email, approver_role, decision, decision_note
  ) VALUES (
    p_proposal_id, p_approver_email, p_approver_role, p_decision, p_decision_note
  ) RETURNING id INTO v_id;

  UPDATE public.engineer_promotion_proposals_r1780
  SET status = 'under_review', updated_at = now()
  WHERE id = p_proposal_id AND status = 'proposed';

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_approval_r1780',
    jsonb_build_object('approval_id', v_id, 'proposal_id', p_proposal_id, 'decision', p_decision, 'role', p_approver_role));

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.decide_promotion_r1780(
  p_proposal_id uuid,
  p_final_status text,
  p_decision_note text
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
  IF p_final_status NOT IN ('approved','declined','withdrawn') THEN
    RAISE EXCEPTION 'invalid final status';
  END IF;
  UPDATE public.engineer_promotion_proposals_r1780
  SET status = p_final_status, decided_at = now(), updated_at = now()
  WHERE id = p_proposal_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'decide_promotion_r1780',
    jsonb_build_object('proposal_id', p_proposal_id, 'final_status', p_final_status, 'note', p_decision_note));
END;
$$;

CREATE OR REPLACE FUNCTION public.pending_proposals_summary_r1780()
RETURNS TABLE (
  status text,
  proposal_count int,
  oldest_proposed_at timestamptz
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
  SELECT p.status, (COUNT(*))::int, MIN(p.proposed_at)
  FROM public.engineer_promotion_proposals_r1780 p
  GROUP BY p.status
  ORDER BY p.status;
END;
$$;

CREATE OR REPLACE FUNCTION public.approver_workload_r1780()
RETURNS TABLE (
  approver_email text,
  approver_role text,
  total_decisions int,
  approves int,
  rejects int,
  needs_more_info int
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
  SELECT l.approver_email, l.approver_role,
         (COUNT(*))::int,
         (COUNT(*) FILTER (WHERE l.decision = 'approve'))::int,
         (COUNT(*) FILTER (WHERE l.decision = 'reject'))::int,
         (COUNT(*) FILTER (WHERE l.decision = 'needs_more_info'))::int
  FROM public.engineer_promotion_approval_log_r1780 l
  GROUP BY l.approver_email, l.approver_role
  ORDER BY (COUNT(*))::int DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_proposals_r1780() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.propose_promotion_r1780(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_approvals_r1780(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_approval_r1780(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.decide_promotion_r1780(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.pending_proposals_summary_r1780() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.approver_workload_r1780() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_proposals_r1780() TO authenticated;
GRANT EXECUTE ON FUNCTION public.propose_promotion_r1780(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_approvals_r1780(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_approval_r1780(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decide_promotion_r1780(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pending_proposals_summary_r1780() TO authenticated;
GRANT EXECUTE ON FUNCTION public.approver_workload_r1780() TO authenticated;

COMMIT;