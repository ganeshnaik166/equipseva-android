BEGIN;

-- =========================================================================
-- r1629 — Founder Investor Allocation Final
-- Final per-investor allocation decisions; signed allocations + capacity;
-- commitment letter queue.
-- =========================================================================

-- ---------- Tables ------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.founder_investor_allocations_final (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text,
  round_label text NOT NULL DEFAULT 'seed',
  committed_amount_rupees bigint NOT NULL CHECK (committed_amount_rupees >= 0),
  allocated_amount_rupees bigint NOT NULL CHECK (allocated_amount_rupees >= 0),
  pre_money_valuation_rupees bigint,
  ownership_pct numeric(6,4),
  decision text NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending','allocated','waitlist','declined','signed')),
  signed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fial_decision ON public.founder_investor_allocations_final (decision);
CREATE INDEX IF NOT EXISTS idx_fial_round ON public.founder_investor_allocations_final (round_label);

ALTER TABLE public.founder_investor_allocations_final ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fial_founder_only ON public.founder_investor_allocations_final;
CREATE POLICY fial_founder_only ON public.founder_investor_allocations_final
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_commitment_letter_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  allocation_id uuid NOT NULL REFERENCES public.founder_investor_allocations_final(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','countersigned','withdrawn')),
  queued_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  countersigned_at timestamptz,
  template_version text NOT NULL DEFAULT 'v1',
  notes text
);

CREATE INDEX IF NOT EXISTS idx_fclq_status ON public.founder_commitment_letter_queue (status);
CREATE INDEX IF NOT EXISTS idx_fclq_allocation ON public.founder_commitment_letter_queue (allocation_id);

ALTER TABLE public.founder_commitment_letter_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fclq_founder_only ON public.founder_commitment_letter_queue;
CREATE POLICY fclq_founder_only ON public.founder_commitment_letter_queue
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ---------- READ RPCs ---------------------------------------------------

CREATE OR REPLACE FUNCTION public.founder_investor_allocation_final_summary()
RETURNS TABLE (
  total_investors bigint,
  total_committed_rupees bigint,
  total_allocated_rupees bigint,
  signed_count bigint,
  pending_count bigint,
  waitlist_count bigint,
  capacity_remaining_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_target bigint := 250000000; -- ₹2.5 Cr target round
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COALESCE(SUM(committed_amount_rupees),0)::bigint,
    COALESCE(SUM(allocated_amount_rupees),0)::bigint,
    COUNT(*) FILTER (WHERE decision = 'signed')::bigint,
    COUNT(*) FILTER (WHERE decision = 'pending')::bigint,
    COUNT(*) FILTER (WHERE decision = 'waitlist')::bigint,
    GREATEST(v_target - COALESCE(SUM(allocated_amount_rupees) FILTER (WHERE decision IN ('allocated','signed')),0),0)::bigint
  FROM founder_investor_allocations_final;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_investor_allocation_final_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_allocation_final_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_investor_allocation_final_list()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  round_label text,
  committed_amount_rupees bigint,
  allocated_amount_rupees bigint,
  pre_money_valuation_rupees bigint,
  ownership_pct numeric,
  decision text,
  signed_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.investor_name, a.investor_email, a.round_label,
         a.committed_amount_rupees, a.allocated_amount_rupees,
         a.pre_money_valuation_rupees, a.ownership_pct,
         a.decision, a.signed_at, a.created_at
  FROM founder_investor_allocations_final a
  ORDER BY
    CASE a.decision WHEN 'signed' THEN 1 WHEN 'allocated' THEN 2 WHEN 'pending' THEN 3 WHEN 'waitlist' THEN 4 ELSE 5 END,
    a.allocated_amount_rupees DESC NULLS LAST,
    a.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_investor_allocation_final_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_allocation_final_list() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_investor_allocation_capacity()
RETURNS TABLE (
  round_label text,
  committed_rupees bigint,
  allocated_rupees bigint,
  signed_rupees bigint,
  investor_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    a.round_label,
    COALESCE(SUM(a.committed_amount_rupees),0)::bigint,
    COALESCE(SUM(a.allocated_amount_rupees),0)::bigint,
    COALESCE(SUM(a.allocated_amount_rupees) FILTER (WHERE a.decision = 'signed'),0)::bigint,
    COUNT(*)::bigint
  FROM founder_investor_allocations_final a
  GROUP BY a.round_label
  ORDER BY a.round_label;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_investor_allocation_capacity() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_allocation_capacity() TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_commitment_letter_queue_list()
RETURNS TABLE (
  id uuid,
  allocation_id uuid,
  investor_name text,
  allocated_amount_rupees bigint,
  status text,
  queued_at timestamptz,
  sent_at timestamptz,
  countersigned_at timestamptz,
  template_version text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.allocation_id, a.investor_name, a.allocated_amount_rupees,
         q.status, q.queued_at, q.sent_at, q.countersigned_at, q.template_version
  FROM founder_commitment_letter_queue q
  JOIN founder_investor_allocations_final a ON a.id = q.allocation_id
  ORDER BY
    CASE q.status WHEN 'queued' THEN 1 WHEN 'sent' THEN 2 WHEN 'countersigned' THEN 3 ELSE 4 END,
    q.queued_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_commitment_letter_queue_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_commitment_letter_queue_list() TO authenticated;

-- ---------- WRITE RPCs (VOLATILE) --------------------------------------

CREATE OR REPLACE FUNCTION public.founder_investor_allocation_upsert(
  p_id uuid,
  p_investor_name text,
  p_investor_email text,
  p_round_label text,
  p_committed_rupees bigint,
  p_allocated_rupees bigint,
  p_pre_money_rupees bigint,
  p_ownership_pct numeric,
  p_decision text
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO founder_investor_allocations_final (
      investor_name, investor_email, round_label,
      committed_amount_rupees, allocated_amount_rupees,
      pre_money_valuation_rupees, ownership_pct, decision
    ) VALUES (
      p_investor_name, p_investor_email, COALESCE(p_round_label,'seed'),
      COALESCE(p_committed_rupees,0), COALESCE(p_allocated_rupees,0),
      p_pre_money_rupees, p_ownership_pct, COALESCE(p_decision,'pending')
    ) RETURNING id INTO v_id;
  ELSE
    UPDATE founder_investor_allocations_final
      SET investor_name = p_investor_name,
          investor_email = p_investor_email,
          round_label = COALESCE(p_round_label, round_label),
          committed_amount_rupees = COALESCE(p_committed_rupees, committed_amount_rupees),
          allocated_amount_rupees = COALESCE(p_allocated_rupees, allocated_amount_rupees),
          pre_money_valuation_rupees = p_pre_money_rupees,
          ownership_pct = p_ownership_pct,
          decision = COALESCE(p_decision, decision),
          updated_at = now()
      WHERE id = p_id
      RETURNING id INTO v_id;
  END IF;
  PERFORM log_founder_allocation_upsert(v_id, p_investor_name, p_allocated_rupees);
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_investor_allocation_upsert(uuid,text,text,text,bigint,bigint,bigint,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_allocation_upsert(uuid,text,text,text,bigint,bigint,bigint,numeric,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_investor_allocation_sign(
  p_id uuid
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE founder_investor_allocations_final
    SET decision = 'signed', signed_at = now(), updated_at = now()
    WHERE id = p_id;
  PERFORM log_founder_allocation_sign(p_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_investor_allocation_sign(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_investor_allocation_sign(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.founder_commitment_letter_queue_advance(
  p_id uuid,
  p_next_status text
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_next_status NOT IN ('queued','sent','countersigned','withdrawn') THEN
    RAISE EXCEPTION 'invalid status %', p_next_status;
  END IF;
  UPDATE founder_commitment_letter_queue
    SET status = p_next_status,
        sent_at = CASE WHEN p_next_status = 'sent' THEN now() ELSE sent_at END,
        countersigned_at = CASE WHEN p_next_status = 'countersigned' THEN now() ELSE countersigned_at END
    WHERE id = p_id;
  PERFORM log_founder_letter_advance(p_id, p_next_status);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_commitment_letter_queue_advance(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_commitment_letter_queue_advance(uuid,text) TO authenticated;

-- ---------- LOG HELPERS (founder-only) ---------------------------------

CREATE OR REPLACE FUNCTION public.log_founder_allocation_upsert(
  p_id uuid, p_name text, p_amount bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_investor_allocation_upsert',
          jsonb_build_object('id', p_id, 'investor_name', p_name, 'allocated_rupees', p_amount), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_allocation_upsert(uuid,text,bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_allocation_upsert(uuid,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_allocation_sign(p_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_investor_allocation_sign',
          jsonb_build_object('id', p_id), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_allocation_sign(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_allocation_sign(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.log_founder_letter_advance(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'founder_commitment_letter_queue_advance',
          jsonb_build_object('id', p_id, 'status', p_status), now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_letter_advance(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_letter_advance(uuid,text) TO authenticated;

COMMIT;