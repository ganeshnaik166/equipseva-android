BEGIN;

-- =========================================================================
-- r2410: Engineer on-call after-hours tracker
-- After-hours pings, who answered, response minutes, extra comp, rotation.
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.on_call_pings_r2410 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  ping_arrived_at timestamptz NOT NULL DEFAULT now(),
  ping_kind text NOT NULL
    CHECK (ping_kind IN ('phone_call','sms','app_push','whatsapp','hospital_call','code_red')),
  severity text NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low','medium','high','critical')),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  equipment_label text,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','answered','escalated','missed')),
  answered_at timestamptz,
  answered_by_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  resolve_at timestamptz,
  extra_comp_rupees int NOT NULL DEFAULT 0 CHECK (extra_comp_rupees >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pings_r2410_arrived
  ON public.on_call_pings_r2410 (ping_arrived_at DESC);
CREATE INDEX IF NOT EXISTS idx_pings_r2410_engineer
  ON public.on_call_pings_r2410 (engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_pings_r2410_status
  ON public.on_call_pings_r2410 (status);

CREATE TABLE IF NOT EXISTS public.rotation_slots_r2410 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  slot_start_at timestamptz NOT NULL,
  slot_end_at timestamptz NOT NULL,
  is_primary boolean NOT NULL DEFAULT true,
  is_backup boolean NOT NULL DEFAULT false,
  swapped_from_engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (slot_end_at > slot_start_at)
);

CREATE INDEX IF NOT EXISTS idx_slots_r2410_engineer
  ON public.rotation_slots_r2410 (engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_slots_r2410_window
  ON public.rotation_slots_r2410 (slot_start_at, slot_end_at);

ALTER TABLE public.on_call_pings_r2410 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rotation_slots_r2410 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.on_call_pings_r2410;
CREATE POLICY founder_all ON public.on_call_pings_r2410
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.rotation_slots_r2410;
CREATE POLICY founder_all ON public.rotation_slots_r2410
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPC 1: list pings (recent)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.list_pings_r2410(p_limit int DEFAULT 200)
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  ping_arrived_at timestamptz,
  ping_kind text,
  severity text,
  hospital_user_id uuid,
  hospital_email text,
  equipment_label text,
  status text,
  answered_at timestamptz,
  responder_email text,
  resolve_at timestamptz,
  response_minutes int,
  extra_comp_rupees int,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.id,
      p.engineer_user_id,
      pe.email::text AS engineer_email,
      p.ping_arrived_at,
      p.ping_kind,
      p.severity,
      p.hospital_user_id,
      ph.email::text AS hospital_email,
      p.equipment_label,
      p.status,
      p.answered_at,
      pr.email::text AS responder_email,
      p.resolve_at,
      CASE
        WHEN p.answered_at IS NOT NULL
          THEN GREATEST(0, (EXTRACT(EPOCH FROM (p.answered_at - p.ping_arrived_at)) / 60)::int)
        ELSE NULL
      END AS response_minutes,
      p.extra_comp_rupees,
      p.notes
    FROM public.on_call_pings_r2410 p
    LEFT JOIN public.engineers e ON e.id = p.engineer_user_id
    LEFT JOIN public.profiles pe ON pe.id = e.user_id
    LEFT JOIN public.profiles ph ON ph.id = p.hospital_user_id
    LEFT JOIN public.engineers er ON er.id = p.answered_by_engineer_user_id
    LEFT JOIN public.profiles pr ON pr.id = er.user_id
    ORDER BY p.ping_arrived_at DESC
    LIMIT GREATEST(1, p_limit);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_pings_r2410(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_pings_r2410(int) TO authenticated;

-- =========================================================================
-- RPC 2: weekly response summary (last 12 weeks)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.weekly_response_summary_r2410(p_weeks int DEFAULT 12)
RETURNS TABLE (
  week_start date,
  total_pings int,
  answered int,
  missed int,
  escalated int,
  avg_response_minutes numeric,
  total_extra_comp_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (date_trunc('week', p.ping_arrived_at)::date) AS week_start,
      COUNT(*)::int AS total_pings,
      COUNT(*) FILTER (WHERE p.status = 'answered')::int AS answered,
      COUNT(*) FILTER (WHERE p.status = 'missed')::int AS missed,
      COUNT(*) FILTER (WHERE p.status = 'escalated')::int AS escalated,
      ROUND(AVG(
        CASE WHEN p.answered_at IS NOT NULL
          THEN EXTRACT(EPOCH FROM (p.answered_at - p.ping_arrived_at)) / 60
          ELSE NULL
        END
      )::numeric, 1) AS avg_response_minutes,
      COALESCE(SUM(p.extra_comp_rupees), 0)::bigint AS total_extra_comp_rupees
    FROM public.on_call_pings_r2410 p
    WHERE p.ping_arrived_at >= now() - (GREATEST(1, p_weeks) || ' weeks')::interval
    GROUP BY 1
    ORDER BY 1 DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.weekly_response_summary_r2410(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_response_summary_r2410(int) TO authenticated;

-- =========================================================================
-- RPC 3: top responders (best responders by answered count + speed)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.top_responders_r2410(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  answered_count int,
  avg_response_minutes numeric,
  total_extra_comp_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.answered_by_engineer_user_id AS engineer_user_id,
      pr.email::text AS engineer_email,
      COUNT(*)::int AS answered_count,
      ROUND(AVG(EXTRACT(EPOCH FROM (p.answered_at - p.ping_arrived_at)) / 60)::numeric, 1) AS avg_response_minutes,
      COALESCE(SUM(p.extra_comp_rupees), 0)::bigint AS total_extra_comp_rupees
    FROM public.on_call_pings_r2410 p
    LEFT JOIN public.engineers er ON er.id = p.answered_by_engineer_user_id
    LEFT JOIN public.profiles pr ON pr.id = er.user_id
    WHERE p.answered_by_engineer_user_id IS NOT NULL
      AND p.answered_at IS NOT NULL
    GROUP BY p.answered_by_engineer_user_id, pr.email
    ORDER BY answered_count DESC, avg_response_minutes ASC
    LIMIT GREATEST(1, p_limit);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_responders_r2410(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_responders_r2410(int) TO authenticated;

-- =========================================================================
-- RPC 4: miss offenders (engineers with most missed pings)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.miss_offenders_r2410(p_limit int DEFAULT 20)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  total_pings int,
  missed_count int,
  miss_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.engineer_user_id,
      pr.email::text AS engineer_email,
      COUNT(*)::int AS total_pings,
      COUNT(*) FILTER (WHERE p.status = 'missed')::int AS missed_count,
      ROUND(
        (COUNT(*) FILTER (WHERE p.status = 'missed'))::numeric
          / NULLIF(COUNT(*), 0) * 100,
        1
      ) AS miss_pct
    FROM public.on_call_pings_r2410 p
    LEFT JOIN public.engineers e ON e.id = p.engineer_user_id
    LEFT JOIN public.profiles pr ON pr.id = e.user_id
    GROUP BY p.engineer_user_id, pr.email
    HAVING COUNT(*) FILTER (WHERE p.status = 'missed') > 0
    ORDER BY missed_count DESC, miss_pct DESC
    LIMIT GREATEST(1, p_limit);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.miss_offenders_r2410(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.miss_offenders_r2410(int) TO authenticated;

-- =========================================================================
-- RPC 5: current on-call slot (active right now)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.current_oncall_slot_r2410()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  slot_start_at timestamptz,
  slot_end_at timestamptz,
  is_primary boolean,
  is_backup boolean,
  hours_remaining numeric,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      s.id,
      s.engineer_user_id,
      pr.email::text AS engineer_email,
      s.slot_start_at,
      s.slot_end_at,
      s.is_primary,
      s.is_backup,
      ROUND(EXTRACT(EPOCH FROM (s.slot_end_at - now())) / 3600, 1)::numeric AS hours_remaining,
      s.notes
    FROM public.rotation_slots_r2410 s
    LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
    LEFT JOIN public.profiles pr ON pr.id = e.user_id
    WHERE s.slot_start_at <= now() AND s.slot_end_at >= now()
    ORDER BY s.is_primary DESC, s.slot_start_at ASC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.current_oncall_slot_r2410() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_oncall_slot_r2410() TO authenticated;

-- =========================================================================
-- RPC 6: rotation load balance (hours assigned per engineer last 90d)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.rotation_load_balance_r2410(p_days int DEFAULT 90)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  slot_count int,
  total_hours numeric,
  primary_hours numeric,
  backup_hours numeric,
  swap_count int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      s.engineer_user_id,
      pr.email::text AS engineer_email,
      COUNT(*)::int AS slot_count,
      ROUND(SUM(EXTRACT(EPOCH FROM (s.slot_end_at - s.slot_start_at)) / 3600)::numeric, 1) AS total_hours,
      ROUND(SUM(
        CASE WHEN s.is_primary THEN EXTRACT(EPOCH FROM (s.slot_end_at - s.slot_start_at)) / 3600 ELSE 0 END
      )::numeric, 1) AS primary_hours,
      ROUND(SUM(
        CASE WHEN s.is_backup THEN EXTRACT(EPOCH FROM (s.slot_end_at - s.slot_start_at)) / 3600 ELSE 0 END
      )::numeric, 1) AS backup_hours,
      COUNT(*) FILTER (WHERE s.swapped_from_engineer_user_id IS NOT NULL)::int AS swap_count
    FROM public.rotation_slots_r2410 s
    LEFT JOIN public.engineers e ON e.id = s.engineer_user_id
    LEFT JOIN public.profiles pr ON pr.id = e.user_id
    WHERE s.slot_start_at >= now() - (GREATEST(1, p_days) || ' days')::interval
    GROUP BY s.engineer_user_id, pr.email
    ORDER BY total_hours DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.rotation_load_balance_r2410(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rotation_load_balance_r2410(int) TO authenticated;

-- =========================================================================
-- RPC 7: extra comp owed (unpaid extra comp per engineer)
-- =========================================================================
CREATE OR REPLACE FUNCTION public.extra_comp_owed_r2410(p_days int DEFAULT 30)
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  pings_answered int,
  total_extra_comp_rupees bigint,
  avg_per_ping numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.answered_by_engineer_user_id AS engineer_user_id,
      pr.email::text AS engineer_email,
      COUNT(*)::int AS pings_answered,
      COALESCE(SUM(p.extra_comp_rupees), 0)::bigint AS total_extra_comp_rupees,
      ROUND(AVG(p.extra_comp_rupees)::numeric, 0) AS avg_per_ping
    FROM public.on_call_pings_r2410 p
    LEFT JOIN public.engineers er ON er.id = p.answered_by_engineer_user_id
    LEFT JOIN public.profiles pr ON pr.id = er.user_id
    WHERE p.answered_by_engineer_user_id IS NOT NULL
      AND p.extra_comp_rupees > 0
      AND p.ping_arrived_at >= now() - (GREATEST(1, p_days) || ' days')::interval
    GROUP BY p.answered_by_engineer_user_id, pr.email
    ORDER BY total_extra_comp_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.extra_comp_owed_r2410(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.extra_comp_owed_r2410(int) TO authenticated;

-- =========================================================================
-- Seed example data
-- =========================================================================
DO $$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_hosp uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO v_hosp FROM public.profiles WHERE role = 'hospital_admin' LIMIT 1;

  IF v_eng1 IS NOT NULL THEN
    INSERT INTO public.on_call_pings_r2410
      (engineer_user_id, ping_arrived_at, ping_kind, severity, hospital_user_id, equipment_label, status, answered_at, answered_by_engineer_user_id, resolve_at, extra_comp_rupees, notes)
    VALUES
      (v_eng1, now() - interval '6 days 22 hours', 'phone_call', 'critical', v_hosp, 'GE Vivid E95 Echo', 'answered', now() - interval '6 days 21 hours 53 minutes', v_eng1, now() - interval '6 days 20 hours', 1500, 'Probe disconnect, talked through reseat');

    INSERT INTO public.on_call_pings_r2410
      (engineer_user_id, ping_arrived_at, ping_kind, severity, hospital_user_id, equipment_label, status, answered_at, answered_by_engineer_user_id, extra_comp_rupees, notes)
    VALUES
      (v_eng1, now() - interval '4 days 3 hours', 'whatsapp', 'high', v_hosp, 'Mindray BeneHeart D6', 'answered', now() - interval '4 days 2 hours 48 minutes', COALESCE(v_eng2, v_eng1), 800, 'Backup answered, primary missed');

    INSERT INTO public.on_call_pings_r2410
      (engineer_user_id, ping_arrived_at, ping_kind, severity, hospital_user_id, equipment_label, status, extra_comp_rupees, notes)
    VALUES
      (v_eng1, now() - interval '2 days 1 hour', 'hospital_call', 'high', v_hosp, 'Drager Evita V300', 'missed', 0, 'No response 45 min, escalated to founder');

    INSERT INTO public.on_call_pings_r2410
      (engineer_user_id, ping_arrived_at, ping_kind, severity, hospital_user_id, equipment_label, status, answered_at, answered_by_engineer_user_id, resolve_at, extra_comp_rupees, notes)
    VALUES
      (COALESCE(v_eng2, v_eng1), now() - interval '18 hours', 'code_red', 'critical', v_hosp, 'Philips IntelliVue MX800', 'answered', now() - interval '17 hours 55 minutes', COALESCE(v_eng2, v_eng1), now() - interval '15 hours', 2500, 'Code red, on-site within 90 min');

    INSERT INTO public.on_call_pings_r2410
      (engineer_user_id, ping_arrived_at, ping_kind, severity, hospital_user_id, equipment_label, status, extra_comp_rupees, notes)
    VALUES
      (COALESCE(v_eng3, v_eng1), now() - interval '3 hours', 'app_push', 'medium', v_hosp, 'Mindray Anesthesia A7', 'escalated', 0, 'Escalated to senior, ongoing');

    INSERT INTO public.rotation_slots_r2410
      (engineer_user_id, slot_start_at, slot_end_at, is_primary, is_backup, notes)
    VALUES
      (v_eng1, now() - interval '7 days', now() - interval '5 days', true, false, 'Week 1 primary');

    INSERT INTO public.rotation_slots_r2410
      (engineer_user_id, slot_start_at, slot_end_at, is_primary, is_backup, swapped_from_engineer_user_id, notes)
    VALUES
      (COALESCE(v_eng2, v_eng1), now() - interval '5 days', now() - interval '3 days', true, false, v_eng1, 'Swapped due to family emergency');

    INSERT INTO public.rotation_slots_r2410
      (engineer_user_id, slot_start_at, slot_end_at, is_primary, is_backup, notes)
    VALUES
      (COALESCE(v_eng3, v_eng1), now() - interval '12 hours', now() + interval '36 hours', true, false, 'Current primary on-call');

    INSERT INTO public.rotation_slots_r2410
      (engineer_user_id, slot_start_at, slot_end_at, is_primary, is_backup, notes)
    VALUES
      (COALESCE(v_eng2, v_eng1), now() - interval '12 hours', now() + interval '36 hours', false, true, 'Current backup');
  END IF;
END $$;

COMMENT ON TABLE public.on_call_pings_r2410 IS 'r2410: After-hours pings to on-call engineers with response tracking and extra comp.';
COMMENT ON TABLE public.rotation_slots_r2410 IS 'r2410: On-call rotation slot schedule with primary/backup roles and swap tracking.';
COMMENT ON FUNCTION public.list_pings_r2410(int) IS 'r2410: List recent on-call pings with response minutes computed.';
COMMENT ON FUNCTION public.weekly_response_summary_r2410(int) IS 'r2410: Weekly rollup of pings, answered/missed/escalated counts, avg response.';
COMMENT ON FUNCTION public.top_responders_r2410(int) IS 'r2410: Best responders ranked by answered count and avg response speed.';
COMMENT ON FUNCTION public.miss_offenders_r2410(int) IS 'r2410: Engineers with most missed pings — coaching targets.';
COMMENT ON FUNCTION public.current_oncall_slot_r2410() IS 'r2410: Who is on-call right now (primary + backup) with hours remaining.';
COMMENT ON FUNCTION public.rotation_load_balance_r2410(int) IS 'r2410: Rotation hour load per engineer to spot imbalance and burnout.';
COMMENT ON FUNCTION public.extra_comp_owed_r2410(int) IS 'r2410: Extra after-hours comp owed per engineer for payroll dispatch.';

