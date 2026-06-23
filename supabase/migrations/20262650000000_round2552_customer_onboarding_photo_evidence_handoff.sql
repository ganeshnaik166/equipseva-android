-- Round 2552: customer-onboarding-photo-evidence-handoff
-- Hospital × onboarding photos × signoff × asset register × handover proof.

BEGIN;

-- ============================================================
-- Table 1: customer_onboarding_photos_r2552
-- ============================================================
CREATE TABLE IF NOT EXISTS public.customer_onboarding_photos_r2552 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  photo_kind text NOT NULL CHECK (photo_kind IN ('install','signoff','calibration','safety','training_proof','asset_tag')),
  photo_url text NOT NULL,
  captured_at timestamptz NOT NULL DEFAULT now(),
  captured_by_email text,
  signed_off_at timestamptz,
  signed_off_by_email text,
  asset_register_ref text,
  status text NOT NULL CHECK (status IN ('captured','under_review','signed_off','rejected')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_onboarding_photos_r2552 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_onboarding_photos_r2552;
CREATE POLICY founder_all ON public.customer_onboarding_photos_r2552
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Table 2: handover_proof_packets_r2552
-- ============================================================
CREATE TABLE IF NOT EXISTS public.handover_proof_packets_r2552 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_label text NOT NULL,
  packet_ready_at timestamptz,
  photo_count int NOT NULL DEFAULT 0,
  signoff_count int NOT NULL DEFAULT 0,
  asset_register_synced boolean NOT NULL DEFAULT false,
  founder_review_required boolean NOT NULL DEFAULT false,
  founder_reviewed_at timestamptz,
  status text NOT NULL CHECK (status IN ('pending','complete','escalated')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.handover_proof_packets_r2552 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.handover_proof_packets_r2552;
CREATE POLICY founder_all ON public.handover_proof_packets_r2552
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================
-- Seed Data
-- ============================================================
DO $seed$
DECLARE
  v_hosp_a uuid;
  v_hosp_b uuid;
  v_hosp_c uuid;
BEGIN
  SELECT id INTO v_hosp_a FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC NULLS LAST LIMIT 1;
  SELECT id INTO v_hosp_b FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_hosp_a, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at ASC NULLS LAST LIMIT 1;
  SELECT id INTO v_hosp_c FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_hosp_a, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_hosp_b, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at ASC NULLS LAST LIMIT 1;

  IF v_hosp_a IS NULL THEN
    SELECT id INTO v_hosp_a FROM public.profiles ORDER BY created_at ASC NULLS LAST LIMIT 1;
  END IF;
  IF v_hosp_b IS NULL THEN v_hosp_b := v_hosp_a; END IF;
  IF v_hosp_c IS NULL THEN v_hosp_c := v_hosp_a; END IF;

  IF v_hosp_a IS NOT NULL THEN
    INSERT INTO public.customer_onboarding_photos_r2552 (hospital_user_id, equipment_label, photo_kind, photo_url, captured_at, captured_by_email, signed_off_at, signed_off_by_email, asset_register_ref, status, notes) VALUES
      (v_hosp_a, 'Ventilator V60 - ICU-3', 'install', 'https://cdn.equipseva.in/onboard/v60-install-01.jpg', '2026-06-12 09:15:00'::timestamptz, 'biomed@apollohyd.in', '2026-06-12 14:20:00'::timestamptz, 'founder@equipseva.in', 'AR-APL-2026-0412', 'signed_off', 'install photo verified'),
      (v_hosp_b, 'Defibrillator R-Series', 'safety', 'https://cdn.equipseva.in/onboard/rseries-safety-02.jpg', '2026-06-14 11:00:00'::timestamptz, 'engineer1@equipseva.in', NULL, NULL, 'AR-CARE-2026-0517', 'under_review', 'awaiting biomed signoff'),
      (v_hosp_c, 'C-Arm Cios Alpha', 'calibration', 'https://cdn.equipseva.in/onboard/carm-calib-03.jpg', '2026-06-15 16:45:00'::timestamptz, 'engineer2@equipseva.in', NULL, NULL, NULL, 'captured', 'calibration log pending upload'),
      (v_hosp_a, 'Anesthesia Workstation', 'training_proof', 'https://cdn.equipseva.in/onboard/anes-train-04.jpg', '2026-06-16 10:30:00'::timestamptz, 'engineer3@equipseva.in', '2026-06-16 18:00:00'::timestamptz, 'matron@apollohyd.in', 'AR-APL-2026-0419', 'signed_off', 'training attendance attached'),
      (v_hosp_b, 'Patient Monitor IntelliVue', 'asset_tag', 'https://cdn.equipseva.in/onboard/intellivue-tag-05.jpg', '2026-06-17 08:50:00'::timestamptz, 'engineer1@equipseva.in', NULL, NULL, NULL, 'rejected', 'tag image blurred - retake');

    INSERT INTO public.handover_proof_packets_r2552 (hospital_user_id, equipment_label, packet_ready_at, photo_count, signoff_count, asset_register_synced, founder_review_required, founder_reviewed_at, status, notes) VALUES
      (v_hosp_a, 'Ventilator V60 - ICU-3', '2026-06-12 18:00:00'::timestamptz, 6, 6, true, false, '2026-06-12 19:30:00'::timestamptz, 'complete', 'first complete packet of the quarter'),
      (v_hosp_b, 'Defibrillator R-Series', NULL, 4, 2, false, true, NULL, 'pending', 'waiting on biomed signoff + asset sync'),
      (v_hosp_c, 'C-Arm Cios Alpha', NULL, 3, 0, false, true, NULL, 'escalated', 'calibration overdue - founder review'),
      (v_hosp_a, 'Anesthesia Workstation', '2026-06-16 20:00:00'::timestamptz, 5, 5, true, false, '2026-06-17 09:00:00'::timestamptz, 'complete', 'training certs included'),
      (v_hosp_b, 'Patient Monitor IntelliVue', NULL, 3, 1, false, true, NULL, 'escalated', 'tag photo rejected - escalate to founder');
  END IF;
END
$seed$;

-- ============================================================
-- RPC 1: list_photos_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_photos_r2552()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  photo_kind text,
  status text,
  photo_url text,
  captured_at timestamptz,
  captured_by_email text,
  signed_off_at timestamptz,
  signed_off_by_email text,
  asset_register_ref text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.equipment_label, p.photo_kind, p.status, p.photo_url,
         p.captured_at, p.captured_by_email, p.signed_off_at, p.signed_off_by_email,
         p.asset_register_ref, p.notes
  FROM public.customer_onboarding_photos_r2552 p
  ORDER BY p.captured_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_photos_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_photos_r2552() TO authenticated;

-- ============================================================
-- RPC 2: list_packets_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_packets_r2552()
RETURNS TABLE (
  id uuid,
  equipment_label text,
  status text,
  photo_count int,
  signoff_count int,
  asset_register_synced boolean,
  founder_review_required boolean,
  packet_ready_at timestamptz,
  founder_reviewed_at timestamptz,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.id, k.equipment_label, k.status, k.photo_count, k.signoff_count,
         k.asset_register_synced, k.founder_review_required,
         k.packet_ready_at, k.founder_reviewed_at, k.notes
  FROM public.handover_proof_packets_r2552 k
  ORDER BY k.packet_ready_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_packets_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_packets_r2552() TO authenticated;

-- ============================================================
-- RPC 3: pending_signoff_focus_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.pending_signoff_focus_r2552()
RETURNS TABLE (
  equipment_label text,
  photo_kind text,
  status text,
  captured_at timestamptz,
  hours_open numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.equipment_label, p.photo_kind, p.status, p.captured_at,
         ROUND(EXTRACT(EPOCH FROM (now() - p.captured_at))::numeric / 3600.0, 1) AS hours_open
  FROM public.customer_onboarding_photos_r2552 p
  WHERE p.status IN ('captured','under_review','rejected')
  ORDER BY p.captured_at ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.pending_signoff_focus_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pending_signoff_focus_r2552() TO authenticated;

-- ============================================================
-- RPC 4: photo_kind_breakdown_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.photo_kind_breakdown_r2552()
RETURNS TABLE (
  photo_kind text,
  total_photos bigint,
  signed_off bigint,
  pending bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.photo_kind,
         COUNT(*)::bigint AS total_photos,
         COUNT(*) FILTER (WHERE p.status = 'signed_off')::bigint AS signed_off,
         COUNT(*) FILTER (WHERE p.status IN ('captured','under_review','rejected'))::bigint AS pending
  FROM public.customer_onboarding_photos_r2552 p
  GROUP BY p.photo_kind
  ORDER BY total_photos DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.photo_kind_breakdown_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.photo_kind_breakdown_r2552() TO authenticated;

-- ============================================================
-- RPC 5: packet_completion_summary_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.packet_completion_summary_r2552()
RETURNS TABLE (
  status text,
  packets bigint,
  total_photos bigint,
  total_signoffs bigint,
  asset_synced bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT k.status,
         COUNT(*)::bigint AS packets,
         COALESCE(SUM(k.photo_count), 0)::bigint AS total_photos,
         COALESCE(SUM(k.signoff_count), 0)::bigint AS total_signoffs,
         COUNT(*) FILTER (WHERE k.asset_register_synced)::bigint AS asset_synced
  FROM public.handover_proof_packets_r2552 k
  GROUP BY k.status
  ORDER BY packets DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.packet_completion_summary_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.packet_completion_summary_r2552() TO authenticated;

-- ============================================================
-- RPC 6: monthly_handoff_trend_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.monthly_handoff_trend_r2552()
RETURNS TABLE (
  month_label text,
  packets bigint,
  complete bigint,
  escalated bigint,
  total_photos bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT to_char(date_trunc('month', COALESCE(k.packet_ready_at, k.created_at)), 'YYYY-MM') AS month_label,
         COUNT(*)::bigint AS packets,
         COUNT(*) FILTER (WHERE k.status = 'complete')::bigint AS complete,
         COUNT(*) FILTER (WHERE k.status = 'escalated')::bigint AS escalated,
         COALESCE(SUM(k.photo_count), 0)::bigint AS total_photos
  FROM public.handover_proof_packets_r2552 k
  GROUP BY 1
  ORDER BY 1 DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_handoff_trend_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_handoff_trend_r2552() TO authenticated;

-- ============================================================
-- RPC 7: owner_load_r2552
-- ============================================================
CREATE OR REPLACE FUNCTION public.owner_load_r2552()
RETURNS TABLE (
  captured_by_email text,
  photos bigint,
  signed_off bigint,
  pending bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(p.captured_by_email, 'unassigned') AS captured_by_email,
         COUNT(*)::bigint AS photos,
         COUNT(*) FILTER (WHERE p.status = 'signed_off')::bigint AS signed_off,
         COUNT(*) FILTER (WHERE p.status IN ('captured','under_review','rejected'))::bigint AS pending
  FROM public.customer_onboarding_photos_r2552 p
  GROUP BY 1
  ORDER BY photos DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2552() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2552() TO authenticated;

