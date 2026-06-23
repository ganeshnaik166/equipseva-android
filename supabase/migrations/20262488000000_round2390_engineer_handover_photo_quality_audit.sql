BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_handover_audits_r2390 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  repair_job_id uuid,
  hospital_org_name text NOT NULL,
  equipment_label text NOT NULL,
  handover_completed_at timestamptz NOT NULL DEFAULT now(),
  photo_count int NOT NULL DEFAULT 0,
  photos_blurry_count int NOT NULL DEFAULT 0,
  photos_dark_count int NOT NULL DEFAULT 0,
  photos_missing_serial_count int NOT NULL DEFAULT 0,
  customer_signoff_captured boolean NOT NULL DEFAULT false,
  customer_signoff_name text,
  customer_signoff_designation text,
  quality_score numeric(5,2) NOT NULL DEFAULT 0,
  quality_band text NOT NULL DEFAULT 'pending' CHECK (quality_band IN ('excellent','good','marginal','poor','pending')),
  dispute_risk_flag boolean NOT NULL DEFAULT false,
  dispute_raised boolean NOT NULL DEFAULT false,
  reviewer_notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehqa_r2390_engineer ON public.engineer_handover_audits_r2390(engineer_id);
CREATE INDEX IF NOT EXISTS idx_ehqa_r2390_band ON public.engineer_handover_audits_r2390(quality_band);
CREATE INDEX IF NOT EXISTS idx_ehqa_r2390_completed ON public.engineer_handover_audits_r2390(handover_completed_at DESC);

ALTER TABLE public.engineer_handover_audits_r2390 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_handover_audits_r2390;
CREATE POLICY founder_all ON public.engineer_handover_audits_r2390
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.engineer_handover_photo_findings_r2390 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  audit_id uuid NOT NULL REFERENCES public.engineer_handover_audits_r2390(id) ON DELETE CASCADE,
  finding_category text NOT NULL CHECK (finding_category IN ('blurry','dark','missing_serial','missing_angle','wrong_equipment','no_signoff','metadata_missing')),
  severity text NOT NULL DEFAULT 'medium' CHECK (severity IN ('low','medium','high','critical')),
  description text NOT NULL,
  occurrences int NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ehpf_r2390_audit ON public.engineer_handover_photo_findings_r2390(audit_id);
CREATE INDEX IF NOT EXISTS idx_ehpf_r2390_category ON public.engineer_handover_photo_findings_r2390(finding_category);

ALTER TABLE public.engineer_handover_photo_findings_r2390 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_handover_photo_findings_r2390;
CREATE POLICY founder_all ON public.engineer_handover_photo_findings_r2390
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.handover_audit_overview_r2390()
RETURNS TABLE (
  total_audits bigint,
  excellent_count bigint,
  good_count bigint,
  marginal_count bigint,
  poor_count bigint,
  dispute_risk_count bigint,
  disputes_raised bigint,
  signoff_capture_rate numeric,
  avg_quality_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE a.quality_band = 'excellent')::bigint,
    COUNT(*) FILTER (WHERE a.quality_band = 'good')::bigint,
    COUNT(*) FILTER (WHERE a.quality_band = 'marginal')::bigint,
    COUNT(*) FILTER (WHERE a.quality_band = 'poor')::bigint,
    COUNT(*) FILTER (WHERE a.dispute_risk_flag)::bigint,
    COUNT(*) FILTER (WHERE a.dispute_raised)::bigint,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE a.customer_signoff_captured)::numeric
      / NULLIF(COUNT(*), 0), 2
    ),
    ROUND(AVG(a.quality_score)::numeric, 2)
  FROM public.engineer_handover_audits_r2390 a;
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_overview_r2390() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_overview_r2390() TO authenticated;

CREATE OR REPLACE FUNCTION public.handover_audit_recent_r2390(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  engineer_email text,
  hospital_org_name text,
  equipment_label text,
  handover_completed_at timestamptz,
  photo_count int,
  quality_score numeric,
  quality_band text,
  customer_signoff_captured boolean,
  dispute_risk_flag boolean,
  dispute_raised boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    a.id,
    p.email,
    a.hospital_org_name,
    a.equipment_label,
    a.handover_completed_at,
    a.photo_count,
    a.quality_score,
    a.quality_band,
    a.customer_signoff_captured,
    a.dispute_risk_flag,
    a.dispute_raised
  FROM public.engineer_handover_audits_r2390 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  ORDER BY a.handover_completed_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_recent_r2390(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_recent_r2390(int) TO authenticated;

CREATE OR REPLACE FUNCTION public.handover_audit_band_breakdown_r2390()
RETURNS TABLE (
  quality_band text,
  audit_count bigint,
  dispute_count bigint,
  avg_quality_score numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    a.quality_band,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE a.dispute_raised)::bigint,
    ROUND(AVG(a.quality_score)::numeric, 2)
  FROM public.engineer_handover_audits_r2390 a
  GROUP BY a.quality_band
  ORDER BY a.quality_band;
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_band_breakdown_r2390() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_band_breakdown_r2390() TO authenticated;

CREATE OR REPLACE FUNCTION public.handover_audit_engineer_leaderboard_r2390()
RETURNS TABLE (
  engineer_email text,
  total_handovers bigint,
  avg_quality_score numeric,
  poor_count bigint,
  dispute_count bigint,
  signoff_rate numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    p.email,
    COUNT(*)::bigint,
    ROUND(AVG(a.quality_score)::numeric, 2),
    COUNT(*) FILTER (WHERE a.quality_band = 'poor')::bigint,
    COUNT(*) FILTER (WHERE a.dispute_raised)::bigint,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE a.customer_signoff_captured)::numeric
      / NULLIF(COUNT(*), 0), 2
    )
  FROM public.engineer_handover_audits_r2390 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  GROUP BY p.email
  ORDER BY ROUND(AVG(a.quality_score)::numeric, 2) DESC NULLS LAST
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_engineer_leaderboard_r2390() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_engineer_leaderboard_r2390() TO authenticated;

CREATE OR REPLACE FUNCTION public.handover_audit_finding_breakdown_r2390()
RETURNS TABLE (
  finding_category text,
  finding_count bigint,
  total_occurrences bigint,
  critical_count bigint,
  high_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    f.finding_category,
    COUNT(*)::bigint,
    SUM(f.occurrences)::bigint,
    COUNT(*) FILTER (WHERE f.severity = 'critical')::bigint,
    COUNT(*) FILTER (WHERE f.severity = 'high')::bigint
  FROM public.engineer_handover_photo_findings_r2390 f
  GROUP BY f.finding_category
  ORDER BY SUM(f.occurrences) DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_finding_breakdown_r2390() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_finding_breakdown_r2390() TO authenticated;

CREATE OR REPLACE FUNCTION public.handover_audit_dispute_watchlist_r2390()
RETURNS TABLE (
  audit_id uuid,
  engineer_email text,
  hospital_org_name text,
  equipment_label text,
  handover_completed_at timestamptz,
  quality_score numeric,
  quality_band text,
  dispute_raised boolean,
  reviewer_notes text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    a.id,
    p.email,
    a.hospital_org_name,
    a.equipment_label,
    a.handover_completed_at,
    a.quality_score,
    a.quality_band,
    a.dispute_raised,
    a.reviewer_notes
  FROM public.engineer_handover_audits_r2390 a
  LEFT JOIN public.profiles p ON p.id = a.engineer_id
  WHERE a.dispute_risk_flag OR a.dispute_raised OR a.quality_band = 'poor'
  ORDER BY a.handover_completed_at DESC
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_dispute_watchlist_r2390() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_dispute_watchlist_r2390() TO authenticated;

CREATE OR REPLACE FUNCTION public.handover_audit_weekly_trend_r2390()
RETURNS TABLE (
  week_start date,
  audit_count bigint,
  avg_quality_score numeric,
  poor_count bigint,
  dispute_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  RETURN QUERY
  SELECT
    date_trunc('week', a.handover_completed_at)::date,
    COUNT(*)::bigint,
    ROUND(AVG(a.quality_score)::numeric, 2),
    COUNT(*) FILTER (WHERE a.quality_band = 'poor')::bigint,
    COUNT(*) FILTER (WHERE a.dispute_raised)::bigint
  FROM public.engineer_handover_audits_r2390 a
  WHERE a.handover_completed_at >= now() - interval '12 weeks'
  GROUP BY date_trunc('week', a.handover_completed_at)
  ORDER BY date_trunc('week', a.handover_completed_at) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.handover_audit_weekly_trend_r2390() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.handover_audit_weekly_trend_r2390() TO authenticated;

COMMIT;
