-- Round 2555: hospital-chain-equipment-handover-quality-scorecard
-- Chain x equipment handover x completeness x engineer x CSAT x dispute risk

CREATE TABLE IF NOT EXISTS public.chain_handover_quality_r2555 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  handover_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  completeness_pct int NOT NULL DEFAULT 0 CHECK (completeness_pct BETWEEN 0 AND 100),
  csat_score int NOT NULL DEFAULT 0 CHECK (csat_score BETWEEN 0 AND 10),
  dispute_risk_kind text NOT NULL DEFAULT 'none' CHECK (dispute_risk_kind IN ('none','low','medium','high','critical')),
  top_gap text,
  owner_email text,
  status text NOT NULL DEFAULT 'green' CHECK (status IN ('green','amber','red')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.handover_dispute_resolution_r2555 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  handover_id uuid NOT NULL REFERENCES public.chain_handover_quality_r2555(id) ON DELETE CASCADE,
  dispute_kind text NOT NULL CHECK (dispute_kind IN ('missing_parts','calibration_wrong','training_gap','documentation_missing','safety_check')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolution_summary text,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text
);

ALTER TABLE public.chain_handover_quality_r2555 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.handover_dispute_resolution_r2555 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_handover_quality_r2555;
CREATE POLICY founder_all ON public.chain_handover_quality_r2555
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.handover_dispute_resolution_r2555;
CREATE POLICY founder_all ON public.handover_dispute_resolution_r2555
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed handovers
INSERT INTO public.chain_handover_quality_r2555
  (chain_name, equipment_label, handover_at, completeness_pct, csat_score, dispute_risk_kind, top_gap, owner_email, status, notes)
VALUES
  ('Apollo Hospitals', 'GE Logiq P9 ultrasound — Hyd ICU-3', '2026-05-12 11:00:00'::timestamptz, 96, 9, 'none', NULL, 'ganesh@equipseva.in', 'green', 'Clean handover; CSAT 9/10'),
  ('Yashoda Hospitals', 'Mindray BeneVision N17 monitor — Sec OT-2', '2026-05-20 14:30:00'::timestamptz, 78, 7, 'medium', 'Calibration certificate delayed by 48h', 'ganesh@equipseva.in', 'amber', 'Cert chased and delivered; CSAT bumped post-cert'),
  ('KIMS Hospitals', 'Drager Evita V300 ventilator — Sec ICU-1', '2026-05-28 09:15:00'::timestamptz, 62, 5, 'high', 'Spare parts kit short by 3 SKUs', 'ganesh@equipseva.in', 'red', 'Escalated to chain CXO; partial refund offered'),
  ('Care Hospitals', 'Philips IntelliVue MX800 — Bnj OT-4', '2026-06-04 16:00:00'::timestamptz, 88, 8, 'low', 'User-manual translation missing for Telugu', 'ganesh@equipseva.in', 'amber', 'Translation queued; nurse training rescheduled'),
  ('Continental Hospitals', 'Siemens Acuson Sequoia — Gachibowli Radiology', '2026-06-15 10:45:00'::timestamptz, 45, 3, 'critical', 'Safety-check sign-off missing; engineer rotated mid-handover', 'ganesh@equipseva.in', 'red', 'Re-handover scheduled with senior engineer');

-- Seed disputes
INSERT INTO public.handover_dispute_resolution_r2555
  (handover_id, dispute_kind, opened_at, resolved_at, resolution_summary, owner_email, status, notes)
SELECT id, 'calibration_wrong', '2026-05-22 09:00:00'::timestamptz, '2026-05-24 17:00:00'::timestamptz, 'Re-calibrated on-site; cert reissued', 'ganesh@equipseva.in', 'closed', 'Closed in 2 days'
  FROM public.chain_handover_quality_r2555 WHERE chain_name='Yashoda Hospitals';

INSERT INTO public.handover_dispute_resolution_r2555
  (handover_id, dispute_kind, opened_at, resolved_at, resolution_summary, owner_email, status, notes)
SELECT id, 'missing_parts', '2026-05-29 10:00:00'::timestamptz, NULL, 'Sourcing 3 missing SKUs from supplier B', 'ganesh@equipseva.in', 'in_progress', 'ETA 5 days'
  FROM public.chain_handover_quality_r2555 WHERE chain_name='KIMS Hospitals';

INSERT INTO public.handover_dispute_resolution_r2555
  (handover_id, dispute_kind, opened_at, resolved_at, resolution_summary, owner_email, status, notes)
SELECT id, 'documentation_missing', '2026-06-05 11:00:00'::timestamptz, NULL, 'Telugu manual being translated by vendor', 'ganesh@equipseva.in', 'open', 'Vendor SLA 7 days'
  FROM public.chain_handover_quality_r2555 WHERE chain_name='Care Hospitals';

INSERT INTO public.handover_dispute_resolution_r2555
  (handover_id, dispute_kind, opened_at, resolved_at, resolution_summary, owner_email, status, notes)
SELECT id, 'safety_check', '2026-06-16 09:30:00'::timestamptz, NULL, 'Senior engineer assigned; re-handover scheduled', 'ganesh@equipseva.in', 'in_progress', 'High visibility — chain CXO watching'
  FROM public.chain_handover_quality_r2555 WHERE chain_name='Continental Hospitals';

INSERT INTO public.handover_dispute_resolution_r2555
  (handover_id, dispute_kind, opened_at, resolved_at, resolution_summary, owner_email, status, notes)
SELECT id, 'training_gap', '2026-06-17 14:00:00'::timestamptz, NULL, 'Refresher training for 4 ICU nurses scheduled', 'ganesh@equipseva.in', 'open', 'Training slot booked next Tuesday'
  FROM public.chain_handover_quality_r2555 WHERE chain_name='Continental Hospitals';

-- RPC 1: list_handover_quality_r2555
CREATE OR REPLACE FUNCTION public.list_handover_quality_r2555()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  handover_at timestamptz,
  completeness_pct int,
  csat_score int,
  dispute_risk_kind text,
  top_gap text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.id, h.chain_name, h.equipment_label, h.handover_at,
         h.completeness_pct, h.csat_score, h.dispute_risk_kind,
         h.top_gap, h.owner_email, h.status, h.notes, h.created_at
  FROM public.chain_handover_quality_r2555 h
  ORDER BY h.handover_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_handover_quality_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_handover_quality_r2555() TO authenticated;

-- RPC 2: list_dispute_resolutions_r2555
CREATE OR REPLACE FUNCTION public.list_dispute_resolutions_r2555()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  dispute_kind text,
  opened_at timestamptz,
  resolved_at timestamptz,
  resolution_summary text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, h.chain_name, h.equipment_label, d.dispute_kind,
         d.opened_at, d.resolved_at, d.resolution_summary, d.owner_email,
         d.status, d.notes
  FROM public.handover_dispute_resolution_r2555 d
  JOIN public.chain_handover_quality_r2555 h ON h.id = d.handover_id
  ORDER BY d.opened_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_dispute_resolutions_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_dispute_resolutions_r2555() TO authenticated;

-- RPC 3: low_completeness_focus_r2555
CREATE OR REPLACE FUNCTION public.low_completeness_focus_r2555()
RETURNS TABLE (
  chain_name text,
  equipment_label text,
  completeness_pct int,
  csat_score int,
  dispute_risk_kind text,
  top_gap text,
  status text,
  handover_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.chain_name, h.equipment_label, h.completeness_pct, h.csat_score,
         h.dispute_risk_kind, h.top_gap, h.status, h.handover_at
  FROM public.chain_handover_quality_r2555 h
  WHERE h.completeness_pct < 80
  ORDER BY h.completeness_pct ASC NULLS LAST, h.handover_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.low_completeness_focus_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.low_completeness_focus_r2555() TO authenticated;

-- RPC 4: dispute_kind_breakdown_r2555
CREATE OR REPLACE FUNCTION public.dispute_kind_breakdown_r2555()
RETURNS TABLE (
  dispute_kind text,
  total_count bigint,
  open_count bigint,
  closed_count bigint,
  avg_days_to_resolve numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.dispute_kind,
         COUNT(*)::bigint AS total_count,
         COUNT(*) FILTER (WHERE d.status IN ('open','in_progress'))::bigint AS open_count,
         COUNT(*) FILTER (WHERE d.status = 'closed')::bigint AS closed_count,
         ROUND(AVG(EXTRACT(EPOCH FROM (d.resolved_at - d.opened_at)) / 86400.0)::numeric, 2) AS avg_days_to_resolve
  FROM public.handover_dispute_resolution_r2555 d
  GROUP BY d.dispute_kind
  ORDER BY total_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.dispute_kind_breakdown_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dispute_kind_breakdown_r2555() TO authenticated;

-- RPC 5: top_chains_by_quality_r2555
CREATE OR REPLACE FUNCTION public.top_chains_by_quality_r2555()
RETURNS TABLE (
  chain_name text,
  handover_count bigint,
  avg_completeness numeric,
  avg_csat numeric,
  red_count bigint,
  critical_risk_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.chain_name,
         COUNT(*)::bigint AS handover_count,
         ROUND(AVG(h.completeness_pct)::numeric, 1) AS avg_completeness,
         ROUND(AVG(h.csat_score)::numeric, 1) AS avg_csat,
         COUNT(*) FILTER (WHERE h.status = 'red')::bigint AS red_count,
         COUNT(*) FILTER (WHERE h.dispute_risk_kind = 'critical')::bigint AS critical_risk_count
  FROM public.chain_handover_quality_r2555 h
  GROUP BY h.chain_name
  ORDER BY avg_completeness DESC NULLS LAST, avg_csat DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_chains_by_quality_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_chains_by_quality_r2555() TO authenticated;

-- RPC 6: monthly_quality_trend_r2555
CREATE OR REPLACE FUNCTION public.monthly_quality_trend_r2555()
RETURNS TABLE (
  month_label text,
  handover_count bigint,
  avg_completeness numeric,
  avg_csat numeric,
  red_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', h.handover_at), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS handover_count,
         ROUND(AVG(h.completeness_pct)::numeric, 1) AS avg_completeness,
         ROUND(AVG(h.csat_score)::numeric, 1) AS avg_csat,
         COUNT(*) FILTER (WHERE h.status = 'red')::bigint AS red_count
  FROM public.chain_handover_quality_r2555 h
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_quality_trend_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_quality_trend_r2555() TO authenticated;

-- RPC 7: engineer_quality_summary_r2555
CREATE OR REPLACE FUNCTION public.engineer_quality_summary_r2555()
RETURNS TABLE (
  engineer_user_id uuid,
  cached_highest_tier text,
  handover_count bigint,
  avg_completeness numeric,
  avg_csat numeric,
  red_count bigint,
  critical_risk_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT h.engineer_user_id,
         e.cached_highest_tier,
         COUNT(*)::bigint AS handover_count,
         ROUND(AVG(h.completeness_pct)::numeric, 1) AS avg_completeness,
         ROUND(AVG(h.csat_score)::numeric, 1) AS avg_csat,
         COUNT(*) FILTER (WHERE h.status = 'red')::bigint AS red_count,
         COUNT(*) FILTER (WHERE h.dispute_risk_kind = 'critical')::bigint AS critical_risk_count
  FROM public.chain_handover_quality_r2555 h
  LEFT JOIN public.engineers e ON e.id = h.engineer_user_id
  GROUP BY h.engineer_user_id, e.cached_highest_tier
  ORDER BY handover_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_quality_summary_r2555() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engineer_quality_summary_r2555() TO authenticated;
