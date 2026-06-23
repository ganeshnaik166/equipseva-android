-- Round 2532: Customer Quarterly Business Review — Stakeholder Attendance
-- hospital × QBR × stakeholders × influence × follow-up commitments

-- ============================================================================
-- TABLE 1: customer_qbr_stakeholder_attendance_r2532
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.customer_qbr_stakeholder_attendance_r2532 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  qbr_quarter text NOT NULL,
  held_on timestamptz NOT NULL,
  stakeholder_name text NOT NULL,
  stakeholder_role text NOT NULL,
  attended boolean NOT NULL DEFAULT false,
  influence_score int NOT NULL DEFAULT 50 CHECK (influence_score BETWEEN 0 AND 100),
  engagement_level text NOT NULL DEFAULT 'passive' CHECK (engagement_level IN ('passive','active','highly_engaged')),
  follow_up_commitments_md text,
  owner_email text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qbr_attend_r2532_hospital
  ON public.customer_qbr_stakeholder_attendance_r2532(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_qbr_attend_r2532_quarter
  ON public.customer_qbr_stakeholder_attendance_r2532(qbr_quarter);
CREATE INDEX IF NOT EXISTS idx_qbr_attend_r2532_held
  ON public.customer_qbr_stakeholder_attendance_r2532(held_on DESC);

ALTER TABLE public.customer_qbr_stakeholder_attendance_r2532 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.customer_qbr_stakeholder_attendance_r2532;
CREATE POLICY founder_all ON public.customer_qbr_stakeholder_attendance_r2532
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- TABLE 2: qbr_followup_commitments_r2532
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.qbr_followup_commitments_r2532 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attendance_id uuid NOT NULL REFERENCES public.customer_qbr_stakeholder_attendance_r2532(id) ON DELETE CASCADE,
  commitment_text text NOT NULL,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_qbr_commit_r2532_attendance
  ON public.qbr_followup_commitments_r2532(attendance_id);
CREATE INDEX IF NOT EXISTS idx_qbr_commit_r2532_status
  ON public.qbr_followup_commitments_r2532(status);
CREATE INDEX IF NOT EXISTS idx_qbr_commit_r2532_due
  ON public.qbr_followup_commitments_r2532(due_at);

ALTER TABLE public.qbr_followup_commitments_r2532 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.qbr_followup_commitments_r2532;
CREATE POLICY founder_all ON public.qbr_followup_commitments_r2532
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- SEED DATA
-- ============================================================================
DO $seed$
DECLARE
  v_hospital uuid;
  v_att1 uuid;
  v_att2 uuid;
  v_att3 uuid;
  v_att4 uuid;
BEGIN
  SELECT id INTO v_hospital
  FROM public.profiles
  WHERE role = 'hospital_admin'
  ORDER BY created_at
  LIMIT 1;

  IF v_hospital IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.customer_qbr_stakeholder_attendance_r2532
    (hospital_user_id, qbr_quarter, held_on, stakeholder_name, stakeholder_role, attended, influence_score, engagement_level, follow_up_commitments_md, owner_email, notes)
  VALUES
    (v_hospital, 'Q1-2026', '2026-03-15T10:00:00Z'::timestamptz, 'Dr. Anil Verma', 'CMO', true, 90, 'highly_engaged',
     '- Approve AMC renewal expansion\n- Sponsor 24/7 SLA upgrade', 'cmo@apollo.example', 'Champion sponsor')
  RETURNING id INTO v_att1;

  INSERT INTO public.customer_qbr_stakeholder_attendance_r2532
    (hospital_user_id, qbr_quarter, held_on, stakeholder_name, stakeholder_role, attended, influence_score, engagement_level, follow_up_commitments_md, owner_email, notes)
  VALUES
    (v_hospital, 'Q1-2026', '2026-03-15T10:00:00Z'::timestamptz, 'Sunita Rao', 'Procurement Head', true, 75, 'active',
     '- Issue PO for spare bundle\n- Confirm payment terms', 'procurement@apollo.example', 'Decision maker on commercials')
  RETURNING id INTO v_att2;

  INSERT INTO public.customer_qbr_stakeholder_attendance_r2532
    (hospital_user_id, qbr_quarter, held_on, stakeholder_name, stakeholder_role, attended, influence_score, engagement_level, follow_up_commitments_md, owner_email, notes)
  VALUES
    (v_hospital, 'Q4-2025', '2025-12-12T11:00:00Z'::timestamptz, 'Rajesh Iyer', 'Biomedical Engineer', true, 50, 'active',
     '- Share uptime dashboard access\n- Schedule training', 'biomed@apollo.example', 'Day-to-day operator')
  RETURNING id INTO v_att3;

  INSERT INTO public.customer_qbr_stakeholder_attendance_r2532
    (hospital_user_id, qbr_quarter, held_on, stakeholder_name, stakeholder_role, attended, influence_score, engagement_level, follow_up_commitments_md, owner_email, notes)
  VALUES
    (v_hospital, 'Q1-2026', '2026-03-15T10:00:00Z'::timestamptz, 'Vikram Shah', 'CFO', false, 85, 'passive',
     '- Reschedule budget review separately', 'cfo@apollo.example', 'Skipped; sent delegate')
  RETURNING id INTO v_att4;

  -- Follow-up commitments
  INSERT INTO public.qbr_followup_commitments_r2532
    (attendance_id, commitment_text, owner_email, due_at, status, outcome, closed_at, notes)
  VALUES
    (v_att1, 'Approve AMC renewal expansion to 12 sites', 'cmo@apollo.example', '2026-04-30T17:00:00Z'::timestamptz, 'done', 'positive', '2026-04-22T14:00:00Z'::timestamptz, 'Approved across all 12 sites'),
    (v_att1, 'Sponsor 24/7 SLA upgrade pilot', 'cmo@apollo.example', '2026-05-15T17:00:00Z'::timestamptz, 'in_progress', 'pending', NULL, 'Pilot drafted'),
    (v_att2, 'Issue PO for spare bundle Q2', 'procurement@apollo.example', '2026-04-10T17:00:00Z'::timestamptz, 'done', 'positive', '2026-04-08T11:00:00Z'::timestamptz, 'PO 4521 issued'),
    (v_att2, 'Confirm 30-day payment terms', 'procurement@apollo.example', '2026-04-05T17:00:00Z'::timestamptz, 'dropped', 'negative', '2026-04-15T09:00:00Z'::timestamptz, 'Switched to 45-day terms'),
    (v_att3, 'Share uptime dashboard access', 'biomed@apollo.example', '2026-01-15T17:00:00Z'::timestamptz, 'done', 'positive', '2026-01-08T10:00:00Z'::timestamptz, 'Access granted'),
    (v_att4, 'Reschedule budget review separately', 'cfo@apollo.example', '2026-04-20T17:00:00Z'::timestamptz, 'open', 'pending', NULL, 'Awaiting calendar slot');
END
$seed$;

-- ============================================================================
-- RPC 1: list_attendance_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_attendance_r2532()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  qbr_quarter text,
  held_on timestamptz,
  stakeholder_name text,
  stakeholder_role text,
  attended boolean,
  influence_score int,
  engagement_level text,
  follow_up_commitments_md text,
  owner_email text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.hospital_user_id, p.email, a.qbr_quarter, a.held_on,
         a.stakeholder_name, a.stakeholder_role, a.attended, a.influence_score,
         a.engagement_level, a.follow_up_commitments_md, a.owner_email, a.notes, a.created_at
  FROM public.customer_qbr_stakeholder_attendance_r2532 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  ORDER BY a.held_on DESC, a.influence_score DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_attendance_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_attendance_r2532() TO authenticated;

-- ============================================================================
-- RPC 2: list_followup_commitments_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_followup_commitments_r2532()
RETURNS TABLE (
  id uuid,
  attendance_id uuid,
  stakeholder_name text,
  qbr_quarter text,
  commitment_text text,
  owner_email text,
  due_at timestamptz,
  status text,
  outcome text,
  closed_at timestamptz,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.attendance_id, a.stakeholder_name, a.qbr_quarter,
         c.commitment_text, c.owner_email, c.due_at, c.status, c.outcome,
         c.closed_at, c.notes, c.created_at
  FROM public.qbr_followup_commitments_r2532 c
  JOIN public.customer_qbr_stakeholder_attendance_r2532 a ON a.id = c.attendance_id
  ORDER BY
    CASE c.status WHEN 'open' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'done' THEN 2 ELSE 3 END,
    c.due_at NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_followup_commitments_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_commitments_r2532() TO authenticated;

-- ============================================================================
-- RPC 3: high_influence_attendees_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.high_influence_attendees_r2532()
RETURNS TABLE (
  id uuid,
  qbr_quarter text,
  held_on timestamptz,
  stakeholder_name text,
  stakeholder_role text,
  influence_score int,
  attended boolean,
  engagement_level text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.qbr_quarter, a.held_on, a.stakeholder_name, a.stakeholder_role,
         a.influence_score, a.attended, a.engagement_level
  FROM public.customer_qbr_stakeholder_attendance_r2532 a
  WHERE a.influence_score >= 70
  ORDER BY a.influence_score DESC, a.held_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.high_influence_attendees_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.high_influence_attendees_r2532() TO authenticated;

-- ============================================================================
-- RPC 4: engagement_distribution_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.engagement_distribution_r2532()
RETURNS TABLE (
  engagement_level text,
  attendee_count bigint,
  avg_influence numeric,
  attended_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.engagement_level,
         COUNT(*)::bigint,
         ROUND(AVG(a.influence_score)::numeric, 1),
         COUNT(*) FILTER (WHERE a.attended)::bigint
  FROM public.customer_qbr_stakeholder_attendance_r2532 a
  GROUP BY a.engagement_level
  ORDER BY
    CASE a.engagement_level WHEN 'highly_engaged' THEN 0 WHEN 'active' THEN 1 ELSE 2 END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engagement_distribution_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.engagement_distribution_r2532() TO authenticated;

-- ============================================================================
-- RPC 5: commitment_completion_rate_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.commitment_completion_rate_r2532()
RETURNS TABLE (
  total_commitments bigint,
  done_count bigint,
  in_progress_count bigint,
  open_count bigint,
  dropped_count bigint,
  positive_outcome_count bigint,
  negative_outcome_count bigint,
  completion_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE c.status = 'done')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'in_progress')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'open')::bigint,
    COUNT(*) FILTER (WHERE c.status = 'dropped')::bigint,
    COUNT(*) FILTER (WHERE c.outcome = 'positive')::bigint,
    COUNT(*) FILTER (WHERE c.outcome = 'negative')::bigint,
    CASE WHEN COUNT(*) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE c.status = 'done')::numeric / COUNT(*)::numeric, 1)
    END
  FROM public.qbr_followup_commitments_r2532 c;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.commitment_completion_rate_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commitment_completion_rate_r2532() TO authenticated;

-- ============================================================================
-- RPC 6: top_attended_qbrs_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_attended_qbrs_r2532()
RETURNS TABLE (
  qbr_quarter text,
  held_on timestamptz,
  hospital_email text,
  invited_count bigint,
  attended_count bigint,
  attendance_rate_pct numeric,
  avg_influence numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.qbr_quarter,
         MAX(a.held_on),
         MAX(p.email),
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.attended)::bigint,
         CASE WHEN COUNT(*) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE a.attended)::numeric / COUNT(*)::numeric, 1)
         END,
         ROUND(AVG(a.influence_score)::numeric, 1)
  FROM public.customer_qbr_stakeholder_attendance_r2532 a
  LEFT JOIN public.profiles p ON p.id = a.hospital_user_id
  GROUP BY a.qbr_quarter, a.hospital_user_id
  ORDER BY MAX(a.held_on) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_attended_qbrs_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_attended_qbrs_r2532() TO authenticated;

-- ============================================================================
-- RPC 7: role_attendance_summary_r2532
-- ============================================================================
CREATE OR REPLACE FUNCTION public.role_attendance_summary_r2532()
RETURNS TABLE (
  stakeholder_role text,
  invited_count bigint,
  attended_count bigint,
  attendance_rate_pct numeric,
  avg_influence numeric,
  highly_engaged_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.stakeholder_role,
         COUNT(*)::bigint,
         COUNT(*) FILTER (WHERE a.attended)::bigint,
         CASE WHEN COUNT(*) = 0 THEN 0
              ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE a.attended)::numeric / COUNT(*)::numeric, 1)
         END,
         ROUND(AVG(a.influence_score)::numeric, 1),
         COUNT(*) FILTER (WHERE a.engagement_level = 'highly_engaged')::bigint
  FROM public.customer_qbr_stakeholder_attendance_r2532 a
  GROUP BY a.stakeholder_role
  ORDER BY COUNT(*) FILTER (WHERE a.attended) DESC, AVG(a.influence_score) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.role_attendance_summary_r2532() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.role_attendance_summary_r2532() TO authenticated;
