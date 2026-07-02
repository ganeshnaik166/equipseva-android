-- Round 2540: customer-equipment-cybersecurity-posture
-- Tables: equipment_cybersecurity_posture_r2540, cybersecurity_remediation_plans_r2540
-- RPCs: list_postures_r2540, list_remediation_plans_r2540, critical_focus_r2540,
--       os_kind_breakdown_r2540, top_vulnerable_hospitals_r2540, nabh_compliance_summary_r2540,
--       monthly_remediation_trend_r2540

BEGIN;

CREATE TABLE IF NOT EXISTS public.equipment_cybersecurity_posture_r2540 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text NOT NULL,
  equipment_kind text NOT NULL,
  os_kind text NOT NULL CHECK (os_kind IN ('windows_xp','windows_10','windows_iot','linux','proprietary','macOS')),
  os_patch_level text,
  vulnerability_count int NOT NULL DEFAULT 0 CHECK (vulnerability_count >= 0),
  air_gapped boolean NOT NULL DEFAULT false,
  nabh_compliant boolean NOT NULL DEFAULT false,
  remediation_due_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'at_risk' CHECK (status IN ('secure','at_risk','critical','quarantined')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cybersecurity_remediation_plans_r2540 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  posture_id uuid NOT NULL REFERENCES public.equipment_cybersecurity_posture_r2540(id) ON DELETE CASCADE,
  plan_kind text NOT NULL CHECK (plan_kind IN ('patch_install','network_isolate','firmware_upgrade','replace','document_only')),
  planned_at timestamptz,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.equipment_cybersecurity_posture_r2540 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cybersecurity_remediation_plans_r2540 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.equipment_cybersecurity_posture_r2540;
CREATE POLICY founder_all ON public.equipment_cybersecurity_posture_r2540
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.cybersecurity_remediation_plans_r2540;
CREATE POLICY founder_all ON public.cybersecurity_remediation_plans_r2540
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed postures (single-row INSERTs to capture RETURNING ids safely)
DO $seed$
DECLARE
  p1 uuid;
  p2 uuid;
  p3 uuid;
  p4 uuid;
  p5 uuid;
BEGIN
  INSERT INTO public.equipment_cybersecurity_posture_r2540
    (equipment_label, equipment_kind, os_kind, os_patch_level, vulnerability_count,
     air_gapped, nabh_compliant, remediation_due_at, owner_email, status, notes)
  VALUES
    ('Apollo CT-Scanner #4', 'CT_scanner', 'windows_xp', 'SP3 unpatched 2014', 47,
     false, false, '2026-07-15'::timestamptz, 'biomed@apollo.in', 'critical',
     'XP box on hospital LAN. 47 known CVEs. NABH audit fails. Replace OS or air-gap.')
  RETURNING id INTO p1;

  INSERT INTO public.equipment_cybersecurity_posture_r2540
    (equipment_label, equipment_kind, os_kind, os_patch_level, vulnerability_count,
     air_gapped, nabh_compliant, remediation_due_at, owner_email, status, notes)
  VALUES
    ('Yashoda MRI-1.5T', 'MRI_scanner', 'windows_10', '22H2 patched 2026-05', 3,
     true, true, NULL, 'it@yashoda.in', 'secure',
     'Air-gapped + patched. Clean.')
  RETURNING id INTO p2;

  INSERT INTO public.equipment_cybersecurity_posture_r2540
    (equipment_label, equipment_kind, os_kind, os_patch_level, vulnerability_count,
     air_gapped, nabh_compliant, remediation_due_at, owner_email, status, notes)
  VALUES
    ('Kims Ultrasound #7', 'ultrasound', 'windows_iot', 'IoT LTSC 2021', 8,
     false, false, '2026-07-01'::timestamptz, 'biomed@kims.in', 'at_risk',
     'Win IoT on WiFi. Patch behind. Owner aware.')
  RETURNING id INTO p3;

  INSERT INTO public.equipment_cybersecurity_posture_r2540
    (equipment_label, equipment_kind, os_kind, os_patch_level, vulnerability_count,
     air_gapped, nabh_compliant, remediation_due_at, owner_email, status, notes)
  VALUES
    ('Care Dialysis #2', 'dialysis_machine', 'proprietary', 'OEM firmware v3.2', 0,
     true, true, NULL, 'biomed@care.in', 'secure',
     'Proprietary stack + air-gapped. Documented exception.')
  RETURNING id INTO p4;

  INSERT INTO public.equipment_cybersecurity_posture_r2540
    (equipment_label, equipment_kind, os_kind, os_patch_level, vulnerability_count,
     air_gapped, nabh_compliant, remediation_due_at, owner_email, status, notes)
  VALUES
    ('Manipal Ventilator #11', 'ventilator', 'linux', 'kernel 4.19 EOL', 22,
     false, false, '2026-06-30'::timestamptz, 'biomed@manipal.in', 'quarantined',
     'Pulled from clinical LAN. Vendor refused firmware refresh. Replace path.')
  RETURNING id INTO p5;

  -- Seed remediation plans (single-row INSERTs)
  INSERT INTO public.cybersecurity_remediation_plans_r2540
    (posture_id, plan_kind, planned_at, owner_email, status, outcome, notes)
  VALUES (p1, 'network_isolate', '2026-07-01'::timestamptz, 'biomed@apollo.in',
          'in_progress', 'pending',
          'Move CT-scanner to dedicated VLAN. Block internet egress.');

  INSERT INTO public.cybersecurity_remediation_plans_r2540
    (posture_id, plan_kind, planned_at, owner_email, status, outcome, notes)
  VALUES (p1, 'replace', '2026-09-30'::timestamptz, 'biomed@apollo.in',
          'open', 'pending',
          'Long-term: replace XP workstation with Win10 IoT image.');

  INSERT INTO public.cybersecurity_remediation_plans_r2540
    (posture_id, plan_kind, planned_at, owner_email, status, outcome, notes)
  VALUES (p3, 'patch_install', '2026-06-25'::timestamptz, 'biomed@kims.in',
          'open', 'pending',
          'Push IoT LTSC quarterly rollup.');

  INSERT INTO public.cybersecurity_remediation_plans_r2540
    (posture_id, plan_kind, planned_at, owner_email, status, outcome, notes)
  VALUES (p5, 'replace', '2026-08-15'::timestamptz, 'biomed@manipal.in',
          'in_progress', 'pending',
          'New ventilator unit on order. Old one quarantined until swap.');

  INSERT INTO public.cybersecurity_remediation_plans_r2540
    (posture_id, plan_kind, planned_at, owner_email, status, outcome, notes)
  VALUES (p2, 'document_only', '2026-05-15'::timestamptz, 'it@yashoda.in',
          'done', 'positive',
          'NABH evidence pack archived. No action needed.');

  INSERT INTO public.cybersecurity_remediation_plans_r2540
    (posture_id, plan_kind, planned_at, owner_email, status, outcome, notes)
  VALUES (p4, 'firmware_upgrade', '2026-04-01'::timestamptz, 'biomed@care.in',
          'done', 'positive',
          'OEM firmware v3.2 applied. Air-gap retained.');
END
$seed$;

CREATE OR REPLACE FUNCTION public.list_postures_r2540()
RETURNS TABLE (id uuid, hospital_user_id uuid, equipment_label text, equipment_kind text,
               os_kind text, os_patch_level text, vulnerability_count int,
               air_gapped boolean, nabh_compliant boolean,
               remediation_due_at timestamptz, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.hospital_user_id, p.equipment_label, p.equipment_kind,
           p.os_kind, p.os_patch_level, p.vulnerability_count,
           p.air_gapped, p.nabh_compliant, p.remediation_due_at,
           p.owner_email, p.status, p.notes
    FROM public.equipment_cybersecurity_posture_r2540 p
    ORDER BY
      CASE p.status WHEN 'critical' THEN 0 WHEN 'quarantined' THEN 1
                    WHEN 'at_risk' THEN 2 ELSE 3 END,
      p.vulnerability_count DESC,
      p.created_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_postures_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_postures_r2540() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_remediation_plans_r2540()
RETURNS TABLE (id uuid, posture_id uuid, equipment_label text, plan_kind text,
               planned_at timestamptz, owner_email text, status text,
               outcome text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.posture_id, p.equipment_label, r.plan_kind,
           r.planned_at, r.owner_email, r.status, r.outcome, r.notes
    FROM public.cybersecurity_remediation_plans_r2540 r
    LEFT JOIN public.equipment_cybersecurity_posture_r2540 p ON p.id = r.posture_id
    ORDER BY
      CASE r.status WHEN 'in_progress' THEN 0 WHEN 'open' THEN 1
                    WHEN 'done' THEN 2 ELSE 3 END,
      r.planned_at ASC NULLS LAST;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_remediation_plans_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_remediation_plans_r2540() TO authenticated;

CREATE OR REPLACE FUNCTION public.critical_focus_r2540()
RETURNS TABLE (id uuid, equipment_label text, equipment_kind text, os_kind text,
               vulnerability_count int, air_gapped boolean, nabh_compliant boolean,
               status text, remediation_due_at timestamptz, owner_email text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.equipment_label, p.equipment_kind, p.os_kind,
           p.vulnerability_count, p.air_gapped, p.nabh_compliant,
           p.status, p.remediation_due_at, p.owner_email
    FROM public.equipment_cybersecurity_posture_r2540 p
    WHERE p.status IN ('critical','quarantined')
       OR p.vulnerability_count >= 10
       OR p.os_kind = 'windows_xp'
    ORDER BY p.vulnerability_count DESC, p.remediation_due_at ASC NULLS LAST
    LIMIT 20;
END;$$;
REVOKE EXECUTE ON FUNCTION public.critical_focus_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.critical_focus_r2540() TO authenticated;

CREATE OR REPLACE FUNCTION public.os_kind_breakdown_r2540()
RETURNS TABLE (os_kind text, equipment_count bigint, total_vulns bigint,
               air_gapped_count bigint, nabh_compliant_count bigint,
               critical_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.os_kind,
           count(*)::bigint,
           sum(p.vulnerability_count)::bigint,
           sum(CASE WHEN p.air_gapped THEN 1 ELSE 0 END)::bigint,
           sum(CASE WHEN p.nabh_compliant THEN 1 ELSE 0 END)::bigint,
           sum(CASE WHEN p.status IN ('critical','quarantined') THEN 1 ELSE 0 END)::bigint
    FROM public.equipment_cybersecurity_posture_r2540 p
    GROUP BY p.os_kind
    ORDER BY sum(p.vulnerability_count) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.os_kind_breakdown_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.os_kind_breakdown_r2540() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_vulnerable_hospitals_r2540()
RETURNS TABLE (hospital_user_id uuid, owner_email text, equipment_count bigint,
               total_vulns bigint, critical_count bigint,
               nabh_compliant_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.hospital_user_id,
           max(p.owner_email) AS owner_email,
           count(*)::bigint,
           sum(p.vulnerability_count)::bigint,
           sum(CASE WHEN p.status IN ('critical','quarantined') THEN 1 ELSE 0 END)::bigint,
           sum(CASE WHEN p.nabh_compliant THEN 1 ELSE 0 END)::bigint
    FROM public.equipment_cybersecurity_posture_r2540 p
    GROUP BY p.hospital_user_id
    ORDER BY sum(p.vulnerability_count) DESC
    LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_vulnerable_hospitals_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_vulnerable_hospitals_r2540() TO authenticated;

CREATE OR REPLACE FUNCTION public.nabh_compliance_summary_r2540()
RETURNS TABLE (total_equipment bigint, nabh_compliant bigint, nabh_noncompliant bigint,
               air_gapped_total bigint, critical_total bigint, quarantined_total bigint,
               total_vulns bigint, avg_vulns numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::bigint FROM public.equipment_cybersecurity_posture_r2540),
      (SELECT count(*)::bigint FROM public.equipment_cybersecurity_posture_r2540 WHERE nabh_compliant),
      (SELECT count(*)::bigint FROM public.equipment_cybersecurity_posture_r2540 WHERE NOT nabh_compliant),
      (SELECT count(*)::bigint FROM public.equipment_cybersecurity_posture_r2540 WHERE air_gapped),
      (SELECT count(*)::bigint FROM public.equipment_cybersecurity_posture_r2540 WHERE status = 'critical'),
      (SELECT count(*)::bigint FROM public.equipment_cybersecurity_posture_r2540 WHERE status = 'quarantined'),
      (SELECT coalesce(sum(vulnerability_count),0)::bigint FROM public.equipment_cybersecurity_posture_r2540),
      (SELECT coalesce(round(avg(vulnerability_count)::numeric, 2), 0::numeric)
         FROM public.equipment_cybersecurity_posture_r2540);
END;$$;
REVOKE EXECUTE ON FUNCTION public.nabh_compliance_summary_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nabh_compliance_summary_r2540() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_remediation_trend_r2540()
RETURNS TABLE (month_label text, plans_count bigint, done_count bigint,
               positive_count bigint, negative_count bigint, pending_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', coalesce(r.planned_at, r.created_at)), 'YYYY-MM') AS month_label,
           count(*)::bigint,
           sum(CASE WHEN r.status = 'done' THEN 1 ELSE 0 END)::bigint,
           sum(CASE WHEN r.outcome = 'positive' THEN 1 ELSE 0 END)::bigint,
           sum(CASE WHEN r.outcome = 'negative' THEN 1 ELSE 0 END)::bigint,
           sum(CASE WHEN r.outcome = 'pending' THEN 1 ELSE 0 END)::bigint
    FROM public.cybersecurity_remediation_plans_r2540 r
    GROUP BY date_trunc('month', coalesce(r.planned_at, r.created_at))
    ORDER BY date_trunc('month', coalesce(r.planned_at, r.created_at)) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_remediation_trend_r2540() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_remediation_trend_r2540() TO authenticated;

