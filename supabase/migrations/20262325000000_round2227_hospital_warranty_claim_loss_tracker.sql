BEGIN;

-- Table 1: warranty claim loss records
CREATE TABLE IF NOT EXISTS public.warranty_claim_losses_r2227 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_ref text NOT NULL,
  hospital_org_id uuid,
  equipment_label text NOT NULL,
  vendor_name text NOT NULL,
  claim_opened_at timestamptz NOT NULL DEFAULT now(),
  claim_closed_at timestamptz,
  parts_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  labour_cost_rupees numeric(12,2) NOT NULL DEFAULT 0,
  service_revenue_rupees numeric(12,2) NOT NULL DEFAULT 0,
  loss_rupees numeric(12,2) GENERATED ALWAYS AS (parts_cost_rupees + labour_cost_rupees - service_revenue_rupees) STORED,
  root_cause text NOT NULL DEFAULT 'pending_analysis',
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','analyzing','recovering','recovered','written_off')),
  created_by_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_warranty_loss_r2227_status ON public.warranty_claim_losses_r2227(status, claim_opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_warranty_loss_r2227_vendor ON public.warranty_claim_losses_r2227(vendor_name);

ALTER TABLE public.warranty_claim_losses_r2227 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_claim_losses_r2227;
CREATE POLICY founder_all ON public.warranty_claim_losses_r2227
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Table 2: vendor recovery log entries
CREATE TABLE IF NOT EXISTS public.warranty_vendor_recoveries_r2227 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loss_id uuid NOT NULL REFERENCES public.warranty_claim_losses_r2227(id) ON DELETE CASCADE,
  vendor_name text NOT NULL,
  recovery_action text NOT NULL,
  amount_claimed_rupees numeric(12,2) NOT NULL DEFAULT 0,
  amount_recovered_rupees numeric(12,2) NOT NULL DEFAULT 0,
  recovery_status text NOT NULL DEFAULT 'requested' CHECK (recovery_status IN ('requested','negotiating','partial','full','denied')),
  contact_email text,
  notes text,
  logged_by_user_id uuid REFERENCES public.profiles(id),
  logged_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vendor_recovery_r2227_loss ON public.warranty_vendor_recoveries_r2227(loss_id);
CREATE INDEX IF NOT EXISTS idx_vendor_recovery_r2227_status ON public.warranty_vendor_recoveries_r2227(recovery_status);

ALTER TABLE public.warranty_vendor_recoveries_r2227 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.warranty_vendor_recoveries_r2227;
CREATE POLICY founder_all ON public.warranty_vendor_recoveries_r2227
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list loss records
DROP FUNCTION IF EXISTS public.r2227_list_losses(text);
CREATE OR REPLACE FUNCTION public.r2227_list_losses(p_status text DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  claim_ref text,
  equipment_label text,
  vendor_name text,
  parts_cost_rupees numeric,
  labour_cost_rupees numeric,
  service_revenue_rupees numeric,
  loss_rupees numeric,
  root_cause text,
  severity text,
  status text,
  claim_opened_at timestamptz,
  claim_closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.claim_ref, l.equipment_label, l.vendor_name,
           l.parts_cost_rupees, l.labour_cost_rupees, l.service_revenue_rupees,
           l.loss_rupees, l.root_cause, l.severity, l.status,
           l.claim_opened_at, l.claim_closed_at
    FROM public.warranty_claim_losses_r2227 l
    WHERE (p_status IS NULL OR l.status = p_status)
    ORDER BY l.loss_rupees DESC, l.claim_opened_at DESC
    LIMIT 500;
END $$;

REVOKE ALL ON FUNCTION public.r2227_list_losses(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_list_losses(text) TO authenticated;

-- RPC 2: vendor loss leaderboard
DROP FUNCTION IF EXISTS public.r2227_vendor_leaderboard();
CREATE OR REPLACE FUNCTION public.r2227_vendor_leaderboard()
RETURNS TABLE (
  vendor_name text,
  claim_count int,
  open_count int,
  total_loss_rupees numeric,
  total_recovered_rupees numeric,
  net_loss_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.vendor_name,
           (COUNT(*))::int AS claim_count,
           (COUNT(*) FILTER (WHERE l.status IN ('open','analyzing','recovering')))::int AS open_count,
           COALESCE(SUM(l.loss_rupees),0)::numeric AS total_loss_rupees,
           COALESCE((SELECT SUM(v.amount_recovered_rupees) FROM public.warranty_vendor_recoveries_r2227 v WHERE v.vendor_name = l.vendor_name),0)::numeric AS total_recovered_rupees,
           (COALESCE(SUM(l.loss_rupees),0) - COALESCE((SELECT SUM(v.amount_recovered_rupees) FROM public.warranty_vendor_recoveries_r2227 v WHERE v.vendor_name = l.vendor_name),0))::numeric AS net_loss_rupees
    FROM public.warranty_claim_losses_r2227 l
    GROUP BY l.vendor_name
    ORDER BY net_loss_rupees DESC
    LIMIT 100;
END $$;

REVOKE ALL ON FUNCTION public.r2227_vendor_leaderboard() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_vendor_leaderboard() TO authenticated;

-- RPC 3: root cause breakdown
DROP FUNCTION IF EXISTS public.r2227_root_cause_breakdown();
CREATE OR REPLACE FUNCTION public.r2227_root_cause_breakdown()
RETURNS TABLE (
  root_cause text,
  claim_count int,
  total_loss_rupees numeric,
  avg_loss_rupees numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.root_cause,
           (COUNT(*))::int AS claim_count,
           COALESCE(SUM(l.loss_rupees),0)::numeric AS total_loss_rupees,
           COALESCE(AVG(l.loss_rupees),0)::numeric AS avg_loss_rupees
    FROM public.warranty_claim_losses_r2227 l
    GROUP BY l.root_cause
    ORDER BY total_loss_rupees DESC;
END $$;

REVOKE ALL ON FUNCTION public.r2227_root_cause_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_root_cause_breakdown() TO authenticated;

-- RPC 4: KPI summary
DROP FUNCTION IF EXISTS public.r2227_kpi_summary();
CREATE OR REPLACE FUNCTION public.r2227_kpi_summary()
RETURNS TABLE (
  total_claims int,
  open_claims int,
  total_loss_rupees numeric,
  total_recovered_rupees numeric,
  net_outstanding_rupees numeric,
  critical_open int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*)::int FROM public.warranty_claim_losses_r2227),
      (SELECT (COUNT(*) FILTER (WHERE status IN ('open','analyzing','recovering')))::int FROM public.warranty_claim_losses_r2227),
      COALESCE((SELECT SUM(loss_rupees) FROM public.warranty_claim_losses_r2227),0)::numeric,
      COALESCE((SELECT SUM(amount_recovered_rupees) FROM public.warranty_vendor_recoveries_r2227),0)::numeric,
      (COALESCE((SELECT SUM(loss_rupees) FROM public.warranty_claim_losses_r2227),0) - COALESCE((SELECT SUM(amount_recovered_rupees) FROM public.warranty_vendor_recoveries_r2227),0))::numeric,
      (SELECT (COUNT(*) FILTER (WHERE severity = 'critical' AND status IN ('open','analyzing','recovering')))::int FROM public.warranty_claim_losses_r2227);
END $$;

REVOKE ALL ON FUNCTION public.r2227_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_kpi_summary() TO authenticated;

-- RPC 5: list recoveries for a loss
DROP FUNCTION IF EXISTS public.r2227_list_recoveries(uuid);
CREATE OR REPLACE FUNCTION public.r2227_list_recoveries(p_loss_id uuid)
RETURNS TABLE (
  id uuid,
  loss_id uuid,
  vendor_name text,
  recovery_action text,
  amount_claimed_rupees numeric,
  amount_recovered_rupees numeric,
  recovery_status text,
  contact_email text,
  notes text,
  logged_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.loss_id, v.vendor_name, v.recovery_action,
           v.amount_claimed_rupees, v.amount_recovered_rupees,
           v.recovery_status, v.contact_email, v.notes, v.logged_at
    FROM public.warranty_vendor_recoveries_r2227 v
    WHERE (p_loss_id IS NULL OR v.loss_id = p_loss_id)
    ORDER BY v.logged_at DESC
    LIMIT 500;
END $$;

REVOKE ALL ON FUNCTION public.r2227_list_recoveries(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_list_recoveries(uuid) TO authenticated;

-- RPC 6: record loss
DROP FUNCTION IF EXISTS public.r2227_record_loss(text, text, text, numeric, numeric, numeric, text, text);
CREATE OR REPLACE FUNCTION public.r2227_record_loss(
  p_claim_ref text,
  p_equipment_label text,
  p_vendor_name text,
  p_parts_cost numeric,
  p_labour_cost numeric,
  p_service_rev numeric,
  p_root_cause text,
  p_severity text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.warranty_claim_losses_r2227(
    claim_ref, equipment_label, vendor_name,
    parts_cost_rupees, labour_cost_rupees, service_revenue_rupees,
    root_cause, severity, created_by_user_id
  ) VALUES (
    p_claim_ref, p_equipment_label, p_vendor_name,
    COALESCE(p_parts_cost,0), COALESCE(p_labour_cost,0), COALESCE(p_service_rev,0),
    COALESCE(p_root_cause,'pending_analysis'),
    COALESCE(p_severity,'medium'),
    auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.jwt()->>'email', 'r2227_record_loss', jsonb_build_object('id', v_id, 'claim_ref', p_claim_ref, 'vendor', p_vendor_name));

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.r2227_record_loss(text, text, text, numeric, numeric, numeric, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_record_loss(text, text, text, numeric, numeric, numeric, text, text) TO authenticated;

-- RPC 7: log vendor recovery
DROP FUNCTION IF EXISTS public.r2227_log_recovery(uuid, text, numeric, numeric, text, text, text);
CREATE OR REPLACE FUNCTION public.r2227_log_recovery(
  p_loss_id uuid,
  p_recovery_action text,
  p_amount_claimed numeric,
  p_amount_recovered numeric,
  p_recovery_status text,
  p_contact_email text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_vendor text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT vendor_name INTO v_vendor FROM public.warranty_claim_losses_r2227 WHERE id = p_loss_id;
  IF v_vendor IS NULL THEN RAISE EXCEPTION 'loss_not_found'; END IF;

  INSERT INTO public.warranty_vendor_recoveries_r2227(
    loss_id, vendor_name, recovery_action,
    amount_claimed_rupees, amount_recovered_rupees,
    recovery_status, contact_email, notes, logged_by_user_id
  ) VALUES (
    p_loss_id, v_vendor, p_recovery_action,
    COALESCE(p_amount_claimed,0), COALESCE(p_amount_recovered,0),
    COALESCE(p_recovery_status,'requested'),
    p_contact_email, p_notes, auth.uid()
  ) RETURNING id INTO v_id;

  -- bump loss status if fully recovered
  IF COALESCE(p_recovery_status,'') = 'full' THEN
    UPDATE public.warranty_claim_losses_r2227 SET status = 'recovered', claim_closed_at = COALESCE(claim_closed_at, now()) WHERE id = p_loss_id;
  ELSIF COALESCE(p_recovery_status,'') IN ('negotiating','partial') THEN
    UPDATE public.warranty_claim_losses_r2227 SET status = 'recovering' WHERE id = p_loss_id AND status IN ('open','analyzing');
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), auth.jwt()->>'email', 'r2227_log_recovery', jsonb_build_object('id', v_id, 'loss_id', p_loss_id, 'recovered', p_amount_recovered));

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.r2227_log_recovery(uuid, text, numeric, numeric, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2227_log_recovery(uuid, text, numeric, numeric, text, text, text) TO authenticated;

COMMIT;
