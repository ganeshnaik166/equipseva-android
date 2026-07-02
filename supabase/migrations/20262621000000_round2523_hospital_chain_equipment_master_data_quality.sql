-- Round 2523: Hospital Chain Equipment Master Data Quality
-- Tracks equipment master record quality across hospital chains + cleanup actions.

CREATE TABLE IF NOT EXISTS public.chain_equipment_master_quality_r2523 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  completeness_pct int NOT NULL CHECK (completeness_pct BETWEEN 0 AND 100),
  stale_fields_count int NOT NULL DEFAULT 0 CHECK (stale_fields_count >= 0),
  duplicate_record_count int NOT NULL DEFAULT 0 CHECK (duplicate_record_count >= 0),
  last_audit_at timestamptz,
  quality_grade text NOT NULL CHECK (quality_grade IN ('A','B','C','D','F')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('green','amber','red')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_equipment_master_quality_r2523 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_equipment_master_quality_r2523;
CREATE POLICY founder_all ON public.chain_equipment_master_quality_r2523
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.master_data_cleanup_actions_r2523 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quality_id uuid NOT NULL REFERENCES public.chain_equipment_master_quality_r2523(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('merge_dupes','fill_missing','refresh_stale','retire','reassign')),
  action_at timestamptz NOT NULL DEFAULT now(),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.master_data_cleanup_actions_r2523 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.master_data_cleanup_actions_r2523;
CREATE POLICY founder_all ON public.master_data_cleanup_actions_r2523
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed quality rows
INSERT INTO public.chain_equipment_master_quality_r2523
  (chain_name, equipment_label, completeness_pct, stale_fields_count, duplicate_record_count, last_audit_at, quality_grade, owner_email, status, notes)
VALUES
  ('Apollo Chain', 'Ventilator Model X', 92, 1, 0, now() - interval '7 days', 'A', 'data@apollo.example', 'green', 'Clean record, recent audit'),
  ('Yashoda Chain', 'Patient Monitor', 68, 5, 2, now() - interval '45 days', 'C', 'mdm@yashoda.example', 'amber', 'Stale firmware fields + 2 dupes'),
  ('KIMS Chain', 'Defibrillator', 41, 9, 4, now() - interval '120 days', 'F', 'ops@kims.example', 'red', 'Multiple duplicate serials, very stale'),
  ('Care Chain', 'Anesthesia Workstation', 78, 3, 1, now() - interval '21 days', 'B', 'data@carehospitals.example', 'amber', 'Minor gaps in service history'),
  ('Continental Chain', 'Infusion Pump', 55, 7, 3, now() - interval '60 days', 'D', 'mdm@continental.example', 'red', 'Vendor + warranty fields blank');

-- Seed cleanup action rows
INSERT INTO public.master_data_cleanup_actions_r2523
  (quality_id, action_kind, action_at, owner_email, status, outcome, notes)
SELECT id, 'merge_dupes', now() - interval '3 days', 'data@apollo.example', 'done', 'positive', 'No dupes remaining'
FROM public.chain_equipment_master_quality_r2523 WHERE chain_name='Apollo Chain' LIMIT 1;

INSERT INTO public.master_data_cleanup_actions_r2523
  (quality_id, action_kind, action_at, owner_email, status, outcome, notes)
SELECT id, 'refresh_stale', now() - interval '5 days', 'mdm@yashoda.example', 'in_progress', 'pending', 'Firmware refresh batch underway'
FROM public.chain_equipment_master_quality_r2523 WHERE chain_name='Yashoda Chain' LIMIT 1;

INSERT INTO public.master_data_cleanup_actions_r2523
  (quality_id, action_kind, action_at, owner_email, status, outcome, notes)
SELECT id, 'fill_missing', now() - interval '10 days', 'ops@kims.example', 'open', 'pending', 'Need vendor + warranty data'
FROM public.chain_equipment_master_quality_r2523 WHERE chain_name='KIMS Chain' LIMIT 1;

INSERT INTO public.master_data_cleanup_actions_r2523
  (quality_id, action_kind, action_at, owner_email, status, outcome, notes)
SELECT id, 'retire', now() - interval '14 days', 'data@carehospitals.example', 'done', 'positive', 'Retired EOL units cleanly'
FROM public.chain_equipment_master_quality_r2523 WHERE chain_name='Care Chain' LIMIT 1;

INSERT INTO public.master_data_cleanup_actions_r2523
  (quality_id, action_kind, action_at, owner_email, status, outcome, notes)
SELECT id, 'reassign', now() - interval '2 days', 'mdm@continental.example', 'dropped', 'negative', 'Owner not responsive, dropped'
FROM public.chain_equipment_master_quality_r2523 WHERE chain_name='Continental Chain' LIMIT 1;

-- RPC 1: list_master_quality
CREATE OR REPLACE FUNCTION public.list_master_quality_r2523()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  completeness_pct int,
  stale_fields_count int,
  duplicate_record_count int,
  last_audit_at timestamptz,
  quality_grade text,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.chain_name, q.equipment_label, q.completeness_pct, q.stale_fields_count,
         q.duplicate_record_count, q.last_audit_at, q.quality_grade, q.owner_email,
         q.status, q.notes, q.created_at
  FROM public.chain_equipment_master_quality_r2523 q
  ORDER BY q.completeness_pct ASC, q.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_master_quality_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_master_quality_r2523() TO authenticated;

-- RPC 2: list_cleanup_actions
CREATE OR REPLACE FUNCTION public.list_cleanup_actions_r2523()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  action_kind text,
  action_at timestamptz,
  owner_email text,
  status text,
  outcome text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, q.chain_name, q.equipment_label, a.action_kind, a.action_at,
         a.owner_email, a.status, a.outcome, a.notes
  FROM public.master_data_cleanup_actions_r2523 a
  JOIN public.chain_equipment_master_quality_r2523 q ON q.id = a.quality_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_cleanup_actions_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_cleanup_actions_r2523() TO authenticated;

-- RPC 3: top low quality focus
CREATE OR REPLACE FUNCTION public.top_low_quality_focus_r2523()
RETURNS TABLE (
  id uuid,
  chain_name text,
  equipment_label text,
  completeness_pct int,
  quality_grade text,
  duplicate_record_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.chain_name, q.equipment_label, q.completeness_pct, q.quality_grade,
         q.duplicate_record_count, q.status
  FROM public.chain_equipment_master_quality_r2523 q
  WHERE q.status IN ('amber','red') OR q.quality_grade IN ('C','D','F')
  ORDER BY q.completeness_pct ASC, q.duplicate_record_count DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_low_quality_focus_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_low_quality_focus_r2523() TO authenticated;

-- RPC 4: grade distribution
CREATE OR REPLACE FUNCTION public.grade_distribution_r2523()
RETURNS TABLE (
  quality_grade text,
  record_count bigint,
  avg_completeness numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.quality_grade, COUNT(*)::bigint AS record_count,
         ROUND(AVG(q.completeness_pct)::numeric, 1) AS avg_completeness
  FROM public.chain_equipment_master_quality_r2523 q
  GROUP BY q.quality_grade
  ORDER BY q.quality_grade ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.grade_distribution_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.grade_distribution_r2523() TO authenticated;

-- RPC 5: action kind summary
CREATE OR REPLACE FUNCTION public.action_kind_summary_r2523()
RETURNS TABLE (
  action_kind text,
  total_actions bigint,
  positive_outcomes bigint,
  open_or_in_progress bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind,
         COUNT(*)::bigint AS total_actions,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_outcomes,
         COUNT(*) FILTER (WHERE a.status IN ('open','in_progress'))::bigint AS open_or_in_progress
  FROM public.master_data_cleanup_actions_r2523 a
  GROUP BY a.action_kind
  ORDER BY total_actions DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_kind_summary_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_kind_summary_r2523() TO authenticated;

-- RPC 6: weekly cleanup trend
CREATE OR REPLACE FUNCTION public.weekly_cleanup_trend_r2523()
RETURNS TABLE (
  week_start timestamptz,
  actions_taken bigint,
  done_count bigint,
  positive_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', a.action_at) AS week_start,
         COUNT(*)::bigint AS actions_taken,
         COUNT(*) FILTER (WHERE a.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE a.outcome = 'positive')::bigint AS positive_count
  FROM public.master_data_cleanup_actions_r2523 a
  GROUP BY date_trunc('week', a.action_at)
  ORDER BY week_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.weekly_cleanup_trend_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_cleanup_trend_r2523() TO authenticated;

-- RPC 7: owner load
CREATE OR REPLACE FUNCTION public.owner_load_r2523()
RETURNS TABLE (
  owner_email text,
  records_owned bigint,
  avg_completeness numeric,
  open_actions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.owner_email,
         COUNT(DISTINCT q.id)::bigint AS records_owned,
         ROUND(AVG(q.completeness_pct)::numeric, 1) AS avg_completeness,
         COUNT(a.id) FILTER (WHERE a.status IN ('open','in_progress'))::bigint AS open_actions
  FROM public.chain_equipment_master_quality_r2523 q
  LEFT JOIN public.master_data_cleanup_actions_r2523 a ON a.quality_id = q.id
  WHERE q.owner_email IS NOT NULL
  GROUP BY q.owner_email
  ORDER BY records_owned DESC, avg_completeness ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2523() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2523() TO authenticated;
