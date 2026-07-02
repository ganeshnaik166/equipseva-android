BEGIN;

-- ============================================================================
-- Round 2242: Engineer transport-claim audit
-- Engineers submit travel claims (taxi/fuel/parking/toll), founder approves,
-- queries or rejects with fraud heuristics (duplicate, high amount/km, weekend)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.engineer_transport_claims_r2242 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid REFERENCES public.repair_jobs(id) ON DELETE SET NULL,
  claim_date date NOT NULL,
  mode text NOT NULL CHECK (mode IN ('taxi','fuel','parking','toll','metro','bus','auto','other')),
  amount_rupees numeric(12,2) NOT NULL CHECK (amount_rupees >= 0),
  distance_km numeric(8,2) CHECK (distance_km IS NULL OR distance_km >= 0),
  origin text,
  destination text,
  receipt_url text,
  notes text,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','queried','approved','rejected','paid')),
  fraud_score int NOT NULL DEFAULT 0,
  fraud_flags text[] NOT NULL DEFAULT '{}',
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewer_note text,
  approved_amount_rupees numeric(12,2),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etc_r2242_engineer ON public.engineer_transport_claims_r2242(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_etc_r2242_status ON public.engineer_transport_claims_r2242(status);
CREATE INDEX IF NOT EXISTS idx_etc_r2242_date ON public.engineer_transport_claims_r2242(claim_date DESC);
CREATE INDEX IF NOT EXISTS idx_etc_r2242_fraud ON public.engineer_transport_claims_r2242(fraud_score DESC);

ALTER TABLE public.engineer_transport_claims_r2242 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_etc_r2242 ON public.engineer_transport_claims_r2242;
CREATE POLICY founder_all_etc_r2242 ON public.engineer_transport_claims_r2242
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.engineer_transport_claim_events_r2242 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.engineer_transport_claims_r2242(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('submitted','queried','approved','rejected','paid','note')),
  actor_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_email text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_etce_r2242_claim ON public.engineer_transport_claim_events_r2242(claim_id, created_at DESC);

ALTER TABLE public.engineer_transport_claim_events_r2242 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_etce_r2242 ON public.engineer_transport_claim_events_r2242;
CREATE POLICY founder_all_etce_r2242 ON public.engineer_transport_claim_events_r2242
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());


-- ============================================================================
-- RPC 1: queue summary
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_summary()
RETURNS TABLE(
  submitted_count int,
  queried_count int,
  approved_count int,
  rejected_count int,
  paid_count int,
  submitted_amount_rupees numeric,
  approved_amount_rupees numeric,
  high_fraud_count int,
  avg_amount_rupees numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*) FILTER (WHERE status = 'submitted'))::int,
    (COUNT(*) FILTER (WHERE status = 'queried'))::int,
    (COUNT(*) FILTER (WHERE status = 'approved'))::int,
    (COUNT(*) FILTER (WHERE status = 'rejected'))::int,
    (COUNT(*) FILTER (WHERE status = 'paid'))::int,
    COALESCE(SUM(amount_rupees) FILTER (WHERE status = 'submitted'), 0),
    COALESCE(SUM(approved_amount_rupees) FILTER (WHERE status IN ('approved','paid')), 0),
    (COUNT(*) FILTER (WHERE fraud_score >= 60 AND status IN ('submitted','queried')))::int,
    COALESCE(ROUND(AVG(amount_rupees), 2), 0)
  FROM public.engineer_transport_claims_r2242;
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_summary() TO authenticated;


-- ============================================================================
-- RPC 2: pending queue (submitted + queried)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_pending(p_limit int DEFAULT 100)
RETURNS TABLE(
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  claim_date date,
  mode text,
  amount_rupees numeric,
  distance_km numeric,
  status text,
  fraud_score int,
  fraud_flag_count int,
  submitted_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.engineer_user_id,
    COALESCE(p.email, ''),
    c.claim_date,
    c.mode,
    c.amount_rupees,
    c.distance_km,
    c.status,
    c.fraud_score,
    COALESCE(array_length(c.fraud_flags, 1), 0)::int,
    c.submitted_at
  FROM public.engineer_transport_claims_r2242 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.status IN ('submitted','queried')
  ORDER BY c.fraud_score DESC, c.submitted_at ASC
  LIMIT GREATEST(1, COALESCE(p_limit, 100));
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_pending(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_pending(int) TO authenticated;


-- ============================================================================
-- RPC 3: fraud-flagged claims
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_fraud(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_email text,
  claim_date date,
  mode text,
  amount_rupees numeric,
  distance_km numeric,
  rupees_per_km numeric,
  fraud_score int,
  fraud_flags text[],
  status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    COALESCE(p.email, ''),
    c.claim_date,
    c.mode,
    c.amount_rupees,
    c.distance_km,
    CASE WHEN c.distance_km IS NULL OR c.distance_km = 0 THEN NULL
         ELSE ROUND(c.amount_rupees / c.distance_km, 2) END,
    c.fraud_score,
    c.fraud_flags,
    c.status
  FROM public.engineer_transport_claims_r2242 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  WHERE c.fraud_score >= 40
  ORDER BY c.fraud_score DESC, c.submitted_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_fraud(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_fraud(int) TO authenticated;


-- ============================================================================
-- RPC 4: by engineer aggregate
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_by_engineer(p_limit int DEFAULT 30)
RETURNS TABLE(
  engineer_user_id uuid,
  engineer_email text,
  total_claims int,
  submitted_amount numeric,
  approved_amount numeric,
  rejected_count int,
  avg_fraud_score numeric,
  last_claim_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.engineer_user_id,
    COALESCE(p.email, ''),
    (COUNT(*))::int,
    COALESCE(SUM(c.amount_rupees), 0),
    COALESCE(SUM(c.approved_amount_rupees) FILTER (WHERE c.status IN ('approved','paid')), 0),
    (COUNT(*) FILTER (WHERE c.status = 'rejected'))::int,
    COALESCE(ROUND(AVG(c.fraud_score), 1), 0),
    MAX(c.submitted_at)
  FROM public.engineer_transport_claims_r2242 c
  LEFT JOIN public.profiles p ON p.id = c.engineer_user_id
  GROUP BY c.engineer_user_id, p.email
  ORDER BY SUM(c.amount_rupees) DESC NULLS LAST
  LIMIT GREATEST(1, COALESCE(p_limit, 30));
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_by_engineer(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_by_engineer(int) TO authenticated;


-- ============================================================================
-- RPC 5: mode breakdown
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_modes()
RETURNS TABLE(
  mode text,
  claim_count int,
  total_amount numeric,
  avg_amount numeric,
  approval_rate_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.mode,
    (COUNT(*))::int,
    COALESCE(SUM(c.amount_rupees), 0),
    COALESCE(ROUND(AVG(c.amount_rupees), 2), 0),
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(
           (COUNT(*) FILTER (WHERE c.status IN ('approved','paid')))::numeric * 100.0 / COUNT(*),
           1
         ) END
  FROM public.engineer_transport_claims_r2242 c
  GROUP BY c.mode
  ORDER BY SUM(c.amount_rupees) DESC NULLS LAST;
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_modes() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_modes() TO authenticated;


-- ============================================================================
-- RPC 6: recent decisions
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_recent_decisions(p_limit int DEFAULT 50)
RETURNS TABLE(
  id uuid,
  engineer_email text,
  reviewer_email text,
  status text,
  amount_rupees numeric,
  approved_amount_rupees numeric,
  reviewer_note text,
  reviewed_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    COALESCE(pe.email, ''),
    COALESCE(pr.email, ''),
    c.status,
    c.amount_rupees,
    c.approved_amount_rupees,
    c.reviewer_note,
    c.reviewed_at
  FROM public.engineer_transport_claims_r2242 c
  LEFT JOIN public.profiles pe ON pe.id = c.engineer_user_id
  LEFT JOIN public.profiles pr ON pr.id = c.reviewed_by
  WHERE c.reviewed_at IS NOT NULL
  ORDER BY c.reviewed_at DESC
  LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_recent_decisions(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_recent_decisions(int) TO authenticated;


-- ============================================================================
-- RPC 7: decide claim (approve / query / reject)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.r2242_transport_claim_decide(
  p_claim_id uuid,
  p_decision text,
  p_approved_amount numeric DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_email text;
  v_event_type text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_decision NOT IN ('approve','query','reject') THEN
    RAISE EXCEPTION 'invalid decision';
  END IF;

  v_email := auth.jwt()->>'email';
  v_event_type := CASE p_decision
    WHEN 'approve' THEN 'approved'
    WHEN 'query' THEN 'queried'
    WHEN 'reject' THEN 'rejected'
  END;

  UPDATE public.engineer_transport_claims_r2242
  SET
    status = v_event_type,
    reviewed_at = now(),
    reviewer_note = p_note,
    approved_amount_rupees = CASE WHEN p_decision = 'approve'
                                  THEN COALESCE(p_approved_amount, amount_rupees)
                                  ELSE NULL END
  WHERE id = p_claim_id;

  INSERT INTO public.engineer_transport_claim_events_r2242
    (claim_id, event_type, actor_email, payload)
  VALUES
    (p_claim_id, v_event_type, v_email,
     jsonb_build_object('note', p_note, 'approved_amount', p_approved_amount));

  RETURN p_claim_id;
END;
$$;
REVOKE ALL ON FUNCTION public.r2242_transport_claim_decide(uuid, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2242_transport_claim_decide(uuid, text, numeric, text) TO authenticated;


COMMIT;
