BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_biomed_staff_r2235 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  staff_name text NOT NULL,
  staff_email text,
  staff_phone text,
  role_title text NOT NULL,
  seniority text NOT NULL DEFAULT 'junior' CHECK (seniority IN ('junior','mid','senior','head','director')),
  is_primary_contact boolean NOT NULL DEFAULT false,
  is_decision_maker boolean NOT NULL DEFAULT false,
  joined_at date,
  left_at date,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','notice_period','left','transferred','on_leave')),
  departure_reason text,
  next_employer text,
  relationship_strength int NOT NULL DEFAULT 3 CHECK (relationship_strength BETWEEN 1 AND 5),
  amc_value_rupees bigint NOT NULL DEFAULT 0,
  risk_score int NOT NULL DEFAULT 0,
  handover_complete boolean NOT NULL DEFAULT false,
  notes text,
  created_by_email text NOT NULL DEFAULT (auth.jwt()->>'email'),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_biomed_staff_r2235_hospital ON public.hospital_biomed_staff_r2235(hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_biomed_staff_r2235_status ON public.hospital_biomed_staff_r2235(status);
CREATE INDEX IF NOT EXISTS idx_biomed_staff_r2235_risk ON public.hospital_biomed_staff_r2235(risk_score DESC);

ALTER TABLE public.hospital_biomed_staff_r2235 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.hospital_biomed_staff_r2235;
CREATE POLICY founder_all ON public.hospital_biomed_staff_r2235 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_biomed_transitions_r2235 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id uuid REFERENCES public.hospital_biomed_staff_r2235(id) ON DELETE CASCADE,
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  hospital_name text NOT NULL,
  staff_name text NOT NULL,
  transition_type text NOT NULL CHECK (transition_type IN ('joined','left','promoted','transferred','notice_given','rehired')),
  transition_date date NOT NULL DEFAULT CURRENT_DATE,
  reason text,
  prior_employer text,
  new_employer text,
  exposure_rupees bigint NOT NULL DEFAULT 0,
  mitigation_plan text,
  mitigation_status text NOT NULL DEFAULT 'pending' CHECK (mitigation_status IN ('pending','in_progress','complete','at_risk')),
  founder_briefed boolean NOT NULL DEFAULT false,
  logged_by_email text NOT NULL DEFAULT (auth.jwt()->>'email'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_biomed_trans_r2235_staff ON public.hospital_biomed_transitions_r2235(staff_id);
CREATE INDEX IF NOT EXISTS idx_biomed_trans_r2235_date ON public.hospital_biomed_transitions_r2235(transition_date DESC);
CREATE INDEX IF NOT EXISTS idx_biomed_trans_r2235_type ON public.hospital_biomed_transitions_r2235(transition_type);

ALTER TABLE public.hospital_biomed_transitions_r2235 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.hospital_biomed_transitions_r2235;
CREATE POLICY founder_all ON public.hospital_biomed_transitions_r2235 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.founder_biomed_turnover_kpis_r2235()
RETURNS TABLE(metric text, value text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT 'Active Staff Tracked'::text, COUNT(*)::text FROM public.hospital_biomed_staff_r2235 WHERE status = 'active'
  UNION ALL
  SELECT 'On Notice Period', COUNT(*)::text FROM public.hospital_biomed_staff_r2235 WHERE status = 'notice_period'
  UNION ALL
  SELECT 'Departures (90d)', COUNT(*)::text FROM public.hospital_biomed_transitions_r2235 WHERE transition_type = 'left' AND transition_date >= CURRENT_DATE - 90
  UNION ALL
  SELECT 'High Risk Contacts', (COUNT(*) FILTER (WHERE risk_score >= 70))::int::text FROM public.hospital_biomed_staff_r2235 WHERE status IN ('active','notice_period')
  UNION ALL
  SELECT 'AMC Exposure (Lakh)', COALESCE(SUM(amc_value_rupees) FILTER (WHERE risk_score >= 70), 0)::text FROM public.hospital_biomed_staff_r2235 WHERE status IN ('active','notice_period')
  UNION ALL
  SELECT 'Unmitigated Departures', (COUNT(*) FILTER (WHERE mitigation_status IN ('pending','at_risk')))::int::text FROM public.hospital_biomed_transitions_r2235 WHERE transition_type = 'left';
END $$;

CREATE OR REPLACE FUNCTION public.founder_biomed_high_risk_staff_r2235()
RETURNS TABLE(hospital text, staff text, role text, risk int, amc_rupees bigint, status text, is_primary boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT hospital_name, staff_name, role_title, risk_score, amc_value_rupees, s.status, is_primary_contact
  FROM public.hospital_biomed_staff_r2235 s
  WHERE s.status IN ('active','notice_period')
  ORDER BY risk_score DESC, amc_value_rupees DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_biomed_recent_transitions_r2235()
RETURNS TABLE(when_date date, hospital text, staff text, transition text, reason text, exposure bigint, mitigation text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT transition_date, hospital_name, staff_name, transition_type, reason, exposure_rupees, mitigation_status
  FROM public.hospital_biomed_transitions_r2235
  ORDER BY transition_date DESC, created_at DESC
  LIMIT 60;
END $$;

CREATE OR REPLACE FUNCTION public.founder_biomed_by_hospital_r2235()
RETURNS TABLE(hospital text, total_staff int, active int, departed_90d int, max_risk int, amc_at_risk bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    s.hospital_name,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE s.status IN ('active','notice_period')))::int,
    (SELECT COUNT(*) FROM public.hospital_biomed_transitions_r2235 t WHERE t.hospital_name = s.hospital_name AND t.transition_type = 'left' AND t.transition_date >= CURRENT_DATE - 90)::int,
    COALESCE(MAX(s.risk_score), 0),
    COALESCE(SUM(s.amc_value_rupees) FILTER (WHERE s.risk_score >= 70 AND s.status IN ('active','notice_period')), 0)
  FROM public.hospital_biomed_staff_r2235 s
  GROUP BY s.hospital_name
  ORDER BY MAX(s.risk_score) DESC NULLS LAST
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_biomed_departure_reasons_r2235()
RETURNS TABLE(reason text, count int, total_exposure bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(reason, 'unspecified'), COUNT(*)::int, COALESCE(SUM(exposure_rupees), 0)
  FROM public.hospital_biomed_transitions_r2235
  WHERE transition_type = 'left'
  GROUP BY reason
  ORDER BY COUNT(*) DESC
  LIMIT 20;
END $$;

CREATE OR REPLACE FUNCTION public.founder_biomed_primary_contacts_r2235()
RETURNS TABLE(hospital text, staff text, role text, relationship int, amc_rupees bigint, status text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT hospital_name, staff_name, role_title, relationship_strength, amc_value_rupees, s.status
  FROM public.hospital_biomed_staff_r2235 s
  WHERE is_primary_contact = true
  ORDER BY amc_value_rupees DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_biomed_handover_gaps_r2235()
RETURNS TABLE(hospital text, staff text, transition text, when_date date, exposure bigint, mitigation text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.hospital_name, t.staff_name, t.transition_type, t.transition_date, t.exposure_rupees, t.mitigation_status
  FROM public.hospital_biomed_transitions_r2235 t
  WHERE t.transition_type IN ('left','notice_given','transferred')
    AND t.mitigation_status IN ('pending','at_risk')
  ORDER BY t.exposure_rupees DESC, t.transition_date DESC
  LIMIT 40;
END $$;

REVOKE ALL ON FUNCTION public.founder_biomed_turnover_kpis_r2235() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_biomed_high_risk_staff_r2235() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_biomed_recent_transitions_r2235() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_biomed_by_hospital_r2235() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_biomed_departure_reasons_r2235() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_biomed_primary_contacts_r2235() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.founder_biomed_handover_gaps_r2235() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_biomed_turnover_kpis_r2235() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_biomed_high_risk_staff_r2235() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_biomed_recent_transitions_r2235() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_biomed_by_hospital_r2235() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_biomed_departure_reasons_r2235() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_biomed_primary_contacts_r2235() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_biomed_handover_gaps_r2235() TO authenticated;

COMMIT;
