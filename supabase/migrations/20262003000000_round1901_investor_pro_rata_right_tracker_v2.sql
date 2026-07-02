BEGIN;

-- Table 1: investor_pro_rata_rights_v2_r1901
CREATE TABLE IF NOT EXISTS public.investor_pro_rata_rights_v2_r1901 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  round_label text NOT NULL,
  max_pro_rata_pct numeric(6,3) NOT NULL DEFAULT 0,
  pro_rata_share_count bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expiring','exercised','declined','waived')),
  expiry_date date,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iprrv2_r1901_investor ON public.investor_pro_rata_rights_v2_r1901(investor_id);
CREATE INDEX IF NOT EXISTS idx_iprrv2_r1901_status ON public.investor_pro_rata_rights_v2_r1901(status);
CREATE INDEX IF NOT EXISTS idx_iprrv2_r1901_expiry ON public.investor_pro_rata_rights_v2_r1901(expiry_date);

ALTER TABLE public.investor_pro_rata_rights_v2_r1901 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iprrv2_r1901_founder_all ON public.investor_pro_rata_rights_v2_r1901;
CREATE POLICY iprrv2_r1901_founder_all ON public.investor_pro_rata_rights_v2_r1901
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Table 2: investor_pro_rata_decisions_v2_r1901
CREATE TABLE IF NOT EXISTS public.investor_pro_rata_decisions_v2_r1901 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  right_id uuid REFERENCES public.investor_pro_rata_rights_v2_r1901(id) ON DELETE CASCADE,
  decision text NOT NULL CHECK (decision IN ('exercise','waive','partial_exercise')),
  decision_at timestamptz NOT NULL DEFAULT now(),
  decision_note text,
  founder_action_taken text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iprdv2_r1901_right ON public.investor_pro_rata_decisions_v2_r1901(right_id);
CREATE INDEX IF NOT EXISTS idx_iprdv2_r1901_decision ON public.investor_pro_rata_decisions_v2_r1901(decision);
CREATE INDEX IF NOT EXISTS idx_iprdv2_r1901_decided_at ON public.investor_pro_rata_decisions_v2_r1901(decision_at DESC);

ALTER TABLE public.investor_pro_rata_decisions_v2_r1901 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iprdv2_r1901_founder_all ON public.investor_pro_rata_decisions_v2_r1901;
CREATE POLICY iprdv2_r1901_founder_all ON public.investor_pro_rata_decisions_v2_r1901
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_rights
CREATE OR REPLACE FUNCTION public.list_pro_rata_rights_v2_r1901()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  investor_email text,
  round_label text,
  max_pro_rata_pct numeric,
  pro_rata_share_count bigint,
  status text,
  expiry_date date,
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
  SELECT r.id, r.investor_id, p.email::text, r.round_label, r.max_pro_rata_pct,
         r.pro_rata_share_count, r.status, r.expiry_date, r.decided_at, r.created_at
  FROM public.investor_pro_rata_rights_v2_r1901 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY r.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pro_rata_rights_v2_r1901() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pro_rata_rights_v2_r1901() TO authenticated;

-- RPC 2: log_right
CREATE OR REPLACE FUNCTION public.log_pro_rata_right_v2_r1901(
  p_investor_id uuid,
  p_round_label text,
  p_max_pct numeric,
  p_share_count bigint,
  p_expiry date
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
  INSERT INTO public.investor_pro_rata_rights_v2_r1901(investor_id, round_label, max_pro_rata_pct, pro_rata_share_count, expiry_date)
  VALUES (p_investor_id, p_round_label, p_max_pct, p_share_count, p_expiry)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pro_rata_right_v2_r1901',
          jsonb_build_object('right_id', v_id, 'investor_id', p_investor_id, 'round_label', p_round_label));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_pro_rata_right_v2_r1901(uuid, text, numeric, bigint, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_pro_rata_right_v2_r1901(uuid, text, numeric, bigint, date) TO authenticated;

-- RPC 3: list_decisions
CREATE OR REPLACE FUNCTION public.list_pro_rata_decisions_v2_r1901()
RETURNS TABLE (
  id uuid,
  right_id uuid,
  round_label text,
  investor_email text,
  decision text,
  decision_at timestamptz,
  decision_note text,
  founder_action_taken text
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
  SELECT d.id, d.right_id, r.round_label, p.email::text, d.decision, d.decision_at, d.decision_note, d.founder_action_taken
  FROM public.investor_pro_rata_decisions_v2_r1901 d
  LEFT JOIN public.investor_pro_rata_rights_v2_r1901 r ON r.id = d.right_id
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  ORDER BY d.decision_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pro_rata_decisions_v2_r1901() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pro_rata_decisions_v2_r1901() TO authenticated;

-- RPC 4: log_decision
CREATE OR REPLACE FUNCTION public.log_pro_rata_decision_v2_r1901(
  p_right_id uuid,
  p_decision text,
  p_note text,
  p_founder_action text
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
  INSERT INTO public.investor_pro_rata_decisions_v2_r1901(right_id, decision, decision_note, founder_action_taken)
  VALUES (p_right_id, p_decision, p_note, p_founder_action)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_pro_rata_decision_v2_r1901',
          jsonb_build_object('decision_id', v_id, 'right_id', p_right_id, 'decision', p_decision));
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_pro_rata_decision_v2_r1901(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_pro_rata_decision_v2_r1901(uuid, text, text, text) TO authenticated;

-- RPC 5: mark_decision (update right status after decision)
CREATE OR REPLACE FUNCTION public.mark_pro_rata_decision_v2_r1901(
  p_right_id uuid,
  p_new_status text
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
  IF p_new_status NOT IN ('active','expiring','exercised','declined','waived') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.investor_pro_rata_rights_v2_r1901
  SET status = p_new_status, decided_at = now(), updated_at = now()
  WHERE id = p_right_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_pro_rata_decision_v2_r1901',
          jsonb_build_object('right_id', p_right_id, 'new_status', p_new_status));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_pro_rata_decision_v2_r1901(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_pro_rata_decision_v2_r1901(uuid, text) TO authenticated;

-- RPC 6: expiring_soon
CREATE OR REPLACE FUNCTION public.expiring_pro_rata_rights_v2_r1901()
RETURNS TABLE (
  id uuid,
  investor_email text,
  round_label text,
  max_pro_rata_pct numeric,
  expiry_date date,
  days_left int,
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
  SELECT r.id, p.email::text, r.round_label, r.max_pro_rata_pct, r.expiry_date,
         (r.expiry_date - CURRENT_DATE)::int AS days_left,
         r.status
  FROM public.investor_pro_rata_rights_v2_r1901 r
  LEFT JOIN public.profiles p ON p.id = r.investor_id
  WHERE r.expiry_date IS NOT NULL
    AND r.expiry_date >= CURRENT_DATE
    AND r.expiry_date <= CURRENT_DATE + INTERVAL '30 days'
    AND r.status IN ('active','expiring')
  ORDER BY r.expiry_date ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.expiring_pro_rata_rights_v2_r1901() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_pro_rata_rights_v2_r1901() TO authenticated;

-- RPC 7: recent_decisions (last 30 days summary)
CREATE OR REPLACE FUNCTION public.recent_pro_rata_decisions_v2_r1901()
RETURNS TABLE (
  decision text,
  decision_count int,
  last_decision_at timestamptz
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
  SELECT d.decision,
         (COUNT(*))::int AS decision_count,
         MAX(d.decision_at) AS last_decision_at
  FROM public.investor_pro_rata_decisions_v2_r1901 d
  WHERE d.decision_at >= now() - INTERVAL '30 days'
  GROUP BY d.decision
  ORDER BY decision_count DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_pro_rata_decisions_v2_r1901() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_pro_rata_decisions_v2_r1901() TO authenticated;

COMMIT;
