BEGIN;

-- =========================================================================
-- Round 1943 — Hospital Supply Chain Risk Watch
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_supply_chain_risks_r1943 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  risk_label text NOT NULL,
  risk_type text NOT NULL CHECK (risk_type IN ('supplier_failure','import_delay','price_volatility','regulatory_change','quality_issue')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','mitigating','resolved','escalated')),
  identified_at timestamptz NOT NULL DEFAULT now(),
  last_reviewed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hscr_r1943_hospital ON public.hospital_supply_chain_risks_r1943(hospital_id);
CREATE INDEX IF NOT EXISTS idx_hscr_r1943_status ON public.hospital_supply_chain_risks_r1943(status);
CREATE INDEX IF NOT EXISTS idx_hscr_r1943_severity ON public.hospital_supply_chain_risks_r1943(severity);

CREATE TABLE IF NOT EXISTS public.hospital_supply_risk_action_log_r1943 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  risk_id uuid NOT NULL REFERENCES public.hospital_supply_chain_risks_r1943(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('alternate_supplier_qualified','inventory_buffer_added','contract_renegotiated','escalated','resolved')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  outcome_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hsral_r1943_risk ON public.hospital_supply_risk_action_log_r1943(risk_id);
CREATE INDEX IF NOT EXISTS idx_hsral_r1943_taken ON public.hospital_supply_risk_action_log_r1943(taken_at DESC);

ALTER TABLE public.hospital_supply_chain_risks_r1943 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_supply_risk_action_log_r1943 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hscr_r1943_founder_all ON public.hospital_supply_chain_risks_r1943;
CREATE POLICY hscr_r1943_founder_all ON public.hospital_supply_chain_risks_r1943
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hsral_r1943_founder_all ON public.hospital_supply_risk_action_log_r1943;
CREATE POLICY hsral_r1943_founder_all ON public.hospital_supply_risk_action_log_r1943
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================================
-- 1. list_risks
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_supply_risks_r1943()
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_name text,
  risk_label text,
  risk_type text,
  severity text,
  status text,
  identified_at timestamptz,
  last_reviewed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_id,
           COALESCE(o.name, p.email, 'Unknown') AS hospital_name,
           r.risk_label, r.risk_type, r.severity, r.status,
           r.identified_at, r.last_reviewed_at
    FROM public.hospital_supply_chain_risks_r1943 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY
      CASE r.severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
      r.identified_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_supply_risks_r1943() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_supply_risks_r1943() TO authenticated;

-- =========================================================================
-- 2. log_risk
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_supply_risk_r1943(
  p_hospital_id uuid,
  p_risk_label text,
  p_risk_type text,
  p_severity text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_supply_chain_risks_r1943(hospital_id, risk_label, risk_type, severity)
  VALUES (p_hospital_id, p_risk_label, p_risk_type, p_severity)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_supply_risk_r1943',
          jsonb_build_object('risk_id', v_id, 'hospital_id', p_hospital_id, 'risk_label', p_risk_label, 'risk_type', p_risk_type, 'severity', p_severity), now());
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_supply_risk_r1943(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_supply_risk_r1943(uuid, text, text, text) TO authenticated;

-- =========================================================================
-- 3. list_actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_supply_risk_actions_r1943(p_risk_id uuid)
RETURNS TABLE(
  id uuid,
  risk_id uuid,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.risk_id, a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_supply_risk_action_log_r1943 a
    WHERE a.risk_id = p_risk_id
    ORDER BY a.taken_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_supply_risk_actions_r1943(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_supply_risk_actions_r1943(uuid) TO authenticated;

-- =========================================================================
-- 4. log_action
-- =========================================================================
CREATE OR REPLACE FUNCTION public.log_supply_risk_action_r1943(
  p_risk_id uuid,
  p_action_type text,
  p_outcome_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := (auth.jwt()->>'email');
  INSERT INTO public.hospital_supply_risk_action_log_r1943(risk_id, action_type, by_email, outcome_md)
  VALUES (p_risk_id, p_action_type, v_email, p_outcome_md)
  RETURNING id INTO v_id;

  UPDATE public.hospital_supply_chain_risks_r1943
     SET last_reviewed_at = now(), updated_at = now()
   WHERE id = p_risk_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), v_email, 'log_supply_risk_action_r1943',
          jsonb_build_object('action_id', v_id, 'risk_id', p_risk_id, 'action_type', p_action_type), now());
  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_supply_risk_action_r1943(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_supply_risk_action_r1943(uuid, text, text) TO authenticated;

-- =========================================================================
-- 5. mark_status
-- =========================================================================
CREATE OR REPLACE FUNCTION public.mark_supply_risk_status_r1943(
  p_risk_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','mitigating','resolved','escalated') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.hospital_supply_chain_risks_r1943
     SET status = p_status, last_reviewed_at = now(), updated_at = now()
   WHERE id = p_risk_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_supply_risk_status_r1943',
          jsonb_build_object('risk_id', p_risk_id, 'status', p_status), now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_supply_risk_status_r1943(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_supply_risk_status_r1943(uuid, text) TO authenticated;

-- =========================================================================
-- 6. critical_open
-- =========================================================================
CREATE OR REPLACE FUNCTION public.critical_open_supply_risks_r1943()
RETURNS TABLE(
  id uuid,
  hospital_id uuid,
  hospital_name text,
  risk_label text,
  risk_type text,
  severity text,
  status text,
  identified_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.hospital_id,
           COALESCE(o.name, p.email, 'Unknown') AS hospital_name,
           r.risk_label, r.risk_type, r.severity, r.status, r.identified_at
    FROM public.hospital_supply_chain_risks_r1943 r
    LEFT JOIN public.profiles p ON p.id = r.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    WHERE r.severity IN ('critical','high') AND r.status IN ('open','escalated')
    ORDER BY
      CASE r.severity WHEN 'critical' THEN 0 ELSE 1 END,
      r.identified_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.critical_open_supply_risks_r1943() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.critical_open_supply_risks_r1943() TO authenticated;

-- =========================================================================
-- 7. recent_actions
-- =========================================================================
CREATE OR REPLACE FUNCTION public.recent_supply_risk_actions_r1943()
RETURNS TABLE(
  id uuid,
  risk_id uuid,
  risk_label text,
  hospital_name text,
  action_type text,
  taken_at timestamptz,
  by_email text,
  outcome_md text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.risk_id, r.risk_label,
           COALESCE(o.name, p.email, 'Unknown') AS hospital_name,
           a.action_type, a.taken_at, a.by_email, a.outcome_md
    FROM public.hospital_supply_risk_action_log_r1943 a
    JOIN public.hospital_supply_chain_risks_r1943 r ON r.id = a.risk_id
    LEFT JOIN public.profiles p ON p.id = r.hospital_id
    LEFT JOIN public.organizations o ON o.id = p.organization_id
    ORDER BY a.taken_at DESC
    LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recent_supply_risk_actions_r1943() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_supply_risk_actions_r1943() TO authenticated;

COMMIT;
