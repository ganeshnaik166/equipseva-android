-- r2643 hospital chain quarterly clinical outcome link

CREATE TABLE IF NOT EXISTS public.chain_clinical_outcome_link_r2643 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  quarter_label text NOT NULL,
  equipment_kind text NOT NULL,
  our_uptime_pct numeric NOT NULL DEFAULT 0,
  clinical_outcome_kind text NOT NULL CHECK (clinical_outcome_kind IN ('life_saved','treatment_completed','diagnosis_accelerated','complication_avoided')),
  value_estimate_rupees bigint NOT NULL DEFAULT 0,
  story_md text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('draft','in_review','approved','published','archived')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.clinical_outcome_proof_log_r2643 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  outcome_id uuid NOT NULL REFERENCES public.chain_clinical_outcome_link_r2643(id) ON DELETE CASCADE,
  proof_at timestamptz NOT NULL DEFAULT now(),
  proof_kind text NOT NULL CHECK (proof_kind IN ('case_study','peer_review','conference','board_pack','investor_share')),
  reach int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_clinical_outcome_link_r2643 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_outcome_proof_log_r2643 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_clinical_outcome_link_r2643;
CREATE POLICY founder_all ON public.chain_clinical_outcome_link_r2643
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.clinical_outcome_proof_log_r2643;
CREATE POLICY founder_all ON public.clinical_outcome_proof_log_r2643
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.chain_clinical_outcome_link_r2643
  (chain_name, quarter_label, equipment_kind, our_uptime_pct, clinical_outcome_kind, value_estimate_rupees, story_md, owner_email, status, notes)
VALUES
  ('Apollo Group', '2026-Q1', 'ventilator', 99.7, 'life_saved', 8500000, 'ICU ventilator uptime kept 12 critical patients on support during peak crisis week', 'founder@equipseva.in', 'published', 'Strong story for board pack'),
  ('Manipal Hospitals', '2026-Q1', 'mri_scanner', 98.2, 'diagnosis_accelerated', 4200000, 'MRI uptime cut average diagnosis lead time from 6 days to 2 days across the quarter', 'founder@equipseva.in', 'approved', 'Pending publication clearance'),
  ('Fortis Healthcare', '2026-Q2', 'cath_lab', 99.4, 'life_saved', 12000000, 'Cath lab uninterrupted during cardiac emergency surge in Bangalore', 'founder@equipseva.in', 'in_review', 'Legal reviewing patient consent'),
  ('Yashoda Hospitals', '2026-Q2', 'dialysis_unit', 99.1, 'treatment_completed', 6500000, 'Zero downtime quarter on dialysis units kept 180 chronic patients on schedule', 'founder@equipseva.in', 'draft', 'Need outcome data from clinical lead'),
  ('Aster DM Healthcare', '2026-Q2', 'ct_scanner', 97.8, 'complication_avoided', 3100000, 'CT scanner kept available during trauma window avoided two surgical complications', 'founder@equipseva.in', 'approved', 'Approved for conference share');

INSERT INTO public.clinical_outcome_proof_log_r2643
  (outcome_id, proof_at, proof_kind, reach, owner_email, status, notes)
SELECT id, '2026-04-10 11:00:00+05:30'::timestamptz, 'board_pack', 8, 'founder@equipseva.in', 'done', 'Featured in April board update'
FROM public.chain_clinical_outcome_link_r2643 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.clinical_outcome_proof_log_r2643
  (outcome_id, proof_at, proof_kind, reach, owner_email, status, notes)
SELECT id, '2026-05-18 15:00:00+05:30'::timestamptz, 'investor_share', 22, 'founder@equipseva.in', 'done', 'Shared with seed investors via newsletter'
FROM public.chain_clinical_outcome_link_r2643 WHERE chain_name='Apollo Group' LIMIT 1;

INSERT INTO public.clinical_outcome_proof_log_r2643
  (outcome_id, proof_at, proof_kind, reach, owner_email, status, notes)
SELECT id, '2026-06-02 10:00:00+05:30'::timestamptz, 'case_study', 1200, 'founder@equipseva.in', 'done', 'Published as blog case study'
FROM public.chain_clinical_outcome_link_r2643 WHERE chain_name='Manipal Hospitals' LIMIT 1;

INSERT INTO public.clinical_outcome_proof_log_r2643
  (outcome_id, proof_at, proof_kind, reach, owner_email, status, notes)
SELECT id, '2026-07-15 09:00:00+05:30'::timestamptz, 'conference', 350, 'founder@equipseva.in', 'planned', 'AHPI annual conference slot booked'
FROM public.chain_clinical_outcome_link_r2643 WHERE chain_name='Aster DM Healthcare' LIMIT 1;

INSERT INTO public.clinical_outcome_proof_log_r2643
  (outcome_id, proof_at, proof_kind, reach, owner_email, status, notes)
SELECT id, '2026-06-20 14:00:00+05:30'::timestamptz, 'peer_review', 15, 'founder@equipseva.in', 'planned', 'Under preparation with chief cardiologist'
FROM public.chain_clinical_outcome_link_r2643 WHERE chain_name='Fortis Healthcare' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_outcomes_r2643()
RETURNS SETOF public.chain_clinical_outcome_link_r2643
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.chain_clinical_outcome_link_r2643 ORDER BY quarter_label DESC, value_estimate_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_outcomes_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_outcomes_r2643() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_proof_log_r2643()
RETURNS TABLE(
  id uuid,
  outcome_id uuid,
  chain_name text,
  proof_at timestamptz,
  proof_kind text,
  reach int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.outcome_id, o.chain_name, p.proof_at, p.proof_kind, p.reach, p.owner_email, p.status, p.notes
  FROM public.clinical_outcome_proof_log_r2643 p
  JOIN public.chain_clinical_outcome_link_r2643 o ON o.id = p.outcome_id
  ORDER BY p.proof_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_proof_log_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_proof_log_r2643() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_value_focus_r2643()
RETURNS TABLE(
  id uuid,
  chain_name text,
  quarter_label text,
  equipment_kind text,
  clinical_outcome_kind text,
  value_estimate_rupees bigint,
  our_uptime_pct numeric,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.chain_name, t.quarter_label, t.equipment_kind, t.clinical_outcome_kind, t.value_estimate_rupees, t.our_uptime_pct, t.status
  FROM public.chain_clinical_outcome_link_r2643 t
  WHERE t.status IN ('draft','in_review','approved')
  ORDER BY t.value_estimate_rupees DESC
  LIMIT 10;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_value_focus_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_value_focus_r2643() TO authenticated;

CREATE OR REPLACE FUNCTION public.outcome_kind_distribution_r2643()
RETURNS TABLE(
  clinical_outcome_kind text,
  outcome_count bigint,
  total_value_rupees bigint,
  avg_uptime numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.clinical_outcome_kind,
         COUNT(*)::bigint AS outcome_count,
         COALESCE(SUM(t.value_estimate_rupees),0)::bigint AS total_value_rupees,
         COALESCE(ROUND(AVG(t.our_uptime_pct)::numeric, 2), 0) AS avg_uptime
  FROM public.chain_clinical_outcome_link_r2643 t
  GROUP BY t.clinical_outcome_kind
  ORDER BY total_value_rupees DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.outcome_kind_distribution_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outcome_kind_distribution_r2643() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2643()
RETURNS TABLE(
  status text,
  outcome_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.status,
         COUNT(*)::bigint AS outcome_count,
         COALESCE(SUM(t.value_estimate_rupees),0)::bigint AS total_value_rupees
  FROM public.chain_clinical_outcome_link_r2643 t
  GROUP BY t.status
  ORDER BY outcome_count DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2643() TO authenticated;

CREATE OR REPLACE FUNCTION public.quarterly_outcome_trend_r2643()
RETURNS TABLE(
  quarter_label text,
  outcome_count bigint,
  total_value_rupees bigint,
  published_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.quarter_label,
         COUNT(*)::bigint AS outcome_count,
         COALESCE(SUM(t.value_estimate_rupees),0)::bigint AS total_value_rupees,
         COUNT(*) FILTER (WHERE t.status = 'published')::bigint AS published_count
  FROM public.chain_clinical_outcome_link_r2643 t
  GROUP BY t.quarter_label
  ORDER BY t.quarter_label DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.quarterly_outcome_trend_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.quarterly_outcome_trend_r2643() TO authenticated;

CREATE OR REPLACE FUNCTION public.total_value_summary_r2643()
RETURNS TABLE(
  total_outcomes bigint,
  total_value_rupees bigint,
  published_value_rupees bigint,
  avg_uptime numeric,
  total_proof_events bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint AS total_outcomes,
    COALESCE(SUM(t.value_estimate_rupees),0)::bigint AS total_value_rupees,
    COALESCE(SUM(t.value_estimate_rupees) FILTER (WHERE t.status='published'),0)::bigint AS published_value_rupees,
    COALESCE(ROUND(AVG(t.our_uptime_pct)::numeric, 2), 0) AS avg_uptime,
    (SELECT COUNT(*)::bigint FROM public.clinical_outcome_proof_log_r2643) AS total_proof_events
  FROM public.chain_clinical_outcome_link_r2643 t;
END; $$;
REVOKE EXECUTE ON FUNCTION public.total_value_summary_r2643() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_value_summary_r2643() TO authenticated;
