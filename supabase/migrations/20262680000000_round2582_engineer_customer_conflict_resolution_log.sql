-- Round 2582: Engineer Customer Conflict Resolution Log
-- Tracks engineer-customer conflicts, resolution paths, outcomes, repair actions, lessons

CREATE TABLE IF NOT EXISTS public.engineer_conflicts_r2582 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  conflict_at timestamptz NOT NULL DEFAULT now(),
  conflict_kind text NOT NULL CHECK (conflict_kind IN ('billing_dispute','SLA_breach','quality_complaint','communication_misalign','personal_clash')),
  severity text NOT NULL CHECK (severity IN ('low','medium','high','critical')),
  resolution_path_md text,
  outcome_kind text NOT NULL CHECK (outcome_kind IN ('resolved','escalated','lost_customer','improved_relationship')),
  repair_action_md text,
  lesson_md text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','resolved','dropped')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.conflict_repair_followups_r2582 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  conflict_id uuid NOT NULL REFERENCES public.engineer_conflicts_r2582(id) ON DELETE CASCADE,
  followup_at timestamptz NOT NULL DEFAULT now(),
  followup_kind text NOT NULL CHECK (followup_kind IN ('call','visit','gift','discount','escalation')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.engineer_conflicts_r2582 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conflict_repair_followups_r2582 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_conflicts_r2582;
CREATE POLICY founder_all ON public.engineer_conflicts_r2582
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.conflict_repair_followups_r2582;
CREATE POLICY founder_all ON public.conflict_repair_followups_r2582
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed engineers + hospitals
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_c1 uuid;
  v_c2 uuid;
  v_c3 uuid;
  v_c4 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at DESC LIMIT 1;
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at DESC LIMIT 1;

  IF v_eng1 IS NOT NULL AND v_hosp1 IS NOT NULL THEN
    INSERT INTO public.engineer_conflicts_r2582 (engineer_user_id, hospital_user_id, conflict_at, conflict_kind, severity, resolution_path_md, outcome_kind, repair_action_md, lesson_md, owner_email, status, notes)
    VALUES (v_eng1, v_hosp1, now() - interval '14 days', 'billing_dispute', 'high',
      '- Hospital flagged extra service charge of Rs 4200\n- Reviewed invoice trail\n- Engineer waived charge with founder approval',
      'resolved',
      'Refund issued; engineer coached on quoting transparency',
      'Quote in writing before site visit ends',
      'founder@equipseva.in', 'resolved', 'Recovered NPS from -1 to +8')
    RETURNING id INTO v_c1;
  END IF;

  IF v_eng2 IS NOT NULL AND v_hosp2 IS NOT NULL THEN
    INSERT INTO public.engineer_conflicts_r2582 (engineer_user_id, hospital_user_id, conflict_at, conflict_kind, severity, resolution_path_md, outcome_kind, repair_action_md, lesson_md, owner_email, status, notes)
    VALUES (v_eng2, v_hosp2, now() - interval '21 days', 'SLA_breach', 'critical',
      '- 14h response vs 4h SLA\n- Escalated to founder\n- Free service voucher offered',
      'escalated',
      'Voucher issued; SLA bot alerting added',
      'Tier-2 SLA needs auto-escalation at 75 percent of window',
      'ops@equipseva.in', 'in_progress', 'Hospital still cautious')
    RETURNING id INTO v_c2;
  END IF;

  IF v_eng3 IS NOT NULL AND v_hosp3 IS NOT NULL THEN
    INSERT INTO public.engineer_conflicts_r2582 (engineer_user_id, hospital_user_id, conflict_at, conflict_kind, severity, resolution_path_md, outcome_kind, repair_action_md, lesson_md, owner_email, status, notes)
    VALUES (v_eng3, v_hosp3, now() - interval '40 days', 'quality_complaint', 'medium',
      '- Repair re-failed within 7 days\n- Sent senior engineer for re-work',
      'improved_relationship',
      'Re-work at no cost; root cause logged',
      'Always test under load before sign-off',
      'qa@equipseva.in', 'resolved', 'Hospital signed AMC after recovery')
    RETURNING id INTO v_c3;
  END IF;

  IF v_eng1 IS NOT NULL AND v_hosp2 IS NOT NULL THEN
    INSERT INTO public.engineer_conflicts_r2582 (engineer_user_id, hospital_user_id, conflict_at, conflict_kind, severity, resolution_path_md, outcome_kind, repair_action_md, lesson_md, owner_email, status, notes)
    VALUES (v_eng1, v_hosp2, now() - interval '60 days', 'personal_clash', 'low',
      '- Engineer-hospital admin tone clash on phone\n- Re-assigned to alt engineer',
      'lost_customer',
      'Re-assignment too late; hospital exited 1 month later',
      'Personal-fit signal at job-3 mark is a churn predictor',
      'founder@equipseva.in', 'dropped', 'Cannot recover; lesson archived')
    RETURNING id INTO v_c4;
  END IF;

  -- Followups
  IF v_c1 IS NOT NULL THEN
    INSERT INTO public.conflict_repair_followups_r2582 (conflict_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES (v_c1, now() - interval '7 days', 'call', 'positive', 'founder@equipseva.in', 'done', 'Hospital admin pleased with refund speed');
  END IF;

  IF v_c2 IS NOT NULL THEN
    INSERT INTO public.conflict_repair_followups_r2582 (conflict_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES (v_c2, now() - interval '10 days', 'visit', 'neutral', 'ops@equipseva.in', 'done', 'In-person meeting; voucher delivered');
    INSERT INTO public.conflict_repair_followups_r2582 (conflict_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES (v_c2, now() - interval '3 days', 'discount', 'pending', 'ops@equipseva.in', 'open', 'Offered 15 percent on next AMC renewal');
  END IF;

  IF v_c3 IS NOT NULL THEN
    INSERT INTO public.conflict_repair_followups_r2582 (conflict_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES (v_c3, now() - interval '30 days', 'gift', 'positive', 'qa@equipseva.in', 'done', 'Diwali sweet box; AMC signed within 7 days');
  END IF;

  IF v_c4 IS NOT NULL THEN
    INSERT INTO public.conflict_repair_followups_r2582 (conflict_id, followup_at, followup_kind, outcome, owner_email, status, notes)
    VALUES (v_c4, now() - interval '45 days', 'escalation', 'negative', 'founder@equipseva.in', 'done', 'Hospital exited despite re-assignment');
  END IF;
END;
$seed$;

-- RPC 1: list_conflicts_r2582
CREATE OR REPLACE FUNCTION public.list_conflicts_r2582()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  conflict_at timestamptz,
  conflict_kind text,
  severity text,
  resolution_path_md text,
  outcome_kind text,
  repair_action_md text,
  lesson_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.engineer_user_id, c.hospital_user_id, c.conflict_at, c.conflict_kind, c.severity,
           c.resolution_path_md, c.outcome_kind, c.repair_action_md, c.lesson_md, c.owner_email, c.status, c.notes
    FROM public.engineer_conflicts_r2582 c
    ORDER BY c.conflict_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_conflicts_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_conflicts_r2582() TO authenticated;

-- RPC 2: list_repair_followups_r2582
CREATE OR REPLACE FUNCTION public.list_repair_followups_r2582()
RETURNS TABLE (
  id uuid,
  conflict_id uuid,
  followup_at timestamptz,
  followup_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.id, f.conflict_id, f.followup_at, f.followup_kind, f.outcome, f.owner_email, f.status, f.notes
    FROM public.conflict_repair_followups_r2582 f
    ORDER BY f.followup_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_repair_followups_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_repair_followups_r2582() TO authenticated;

-- RPC 3: top_severity_focus_r2582
CREATE OR REPLACE FUNCTION public.top_severity_focus_r2582()
RETURNS TABLE (
  severity text,
  conflict_count bigint,
  open_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.severity,
           count(*)::bigint AS conflict_count,
           count(*) FILTER (WHERE c.status IN ('open','in_progress'))::bigint AS open_count,
           count(*) FILTER (WHERE c.status = 'resolved')::bigint AS resolved_count
    FROM public.engineer_conflicts_r2582 c
    GROUP BY c.severity
    ORDER BY
      CASE c.severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 ELSE 5 END ASC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_severity_focus_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_severity_focus_r2582() TO authenticated;

-- RPC 4: conflict_kind_breakdown_r2582
CREATE OR REPLACE FUNCTION public.conflict_kind_breakdown_r2582()
RETURNS TABLE (
  conflict_kind text,
  conflict_count bigint,
  critical_or_high bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.conflict_kind,
           count(*)::bigint AS conflict_count,
           count(*) FILTER (WHERE c.severity IN ('critical','high'))::bigint AS critical_or_high
    FROM public.engineer_conflicts_r2582 c
    GROUP BY c.conflict_kind
    ORDER BY conflict_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.conflict_kind_breakdown_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.conflict_kind_breakdown_r2582() TO authenticated;

-- RPC 5: outcome_distribution_r2582
CREATE OR REPLACE FUNCTION public.outcome_distribution_r2582()
RETURNS TABLE (
  outcome_kind text,
  conflict_count bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT count(*)::bigint INTO v_total FROM public.engineer_conflicts_r2582;
  IF v_total = 0 THEN v_total := 1; END IF;
  RETURN QUERY
    SELECT c.outcome_kind,
           count(*)::bigint AS conflict_count,
           round((count(*)::numeric * 100.0) / v_total, 1) AS share_pct
    FROM public.engineer_conflicts_r2582 c
    GROUP BY c.outcome_kind
    ORDER BY conflict_count DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.outcome_distribution_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.outcome_distribution_r2582() TO authenticated;

-- RPC 6: monthly_conflict_trend_r2582
CREATE OR REPLACE FUNCTION public.monthly_conflict_trend_r2582()
RETURNS TABLE (
  month_start timestamptz,
  conflict_count bigint,
  critical_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', c.conflict_at) AS month_start,
           count(*)::bigint AS conflict_count,
           count(*) FILTER (WHERE c.severity = 'critical')::bigint AS critical_count,
           count(*) FILTER (WHERE c.status = 'resolved')::bigint AS resolved_count
    FROM public.engineer_conflicts_r2582 c
    GROUP BY date_trunc('month', c.conflict_at)
    ORDER BY month_start DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_conflict_trend_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_conflict_trend_r2582() TO authenticated;

-- RPC 7: lessons_summary_r2582
CREATE OR REPLACE FUNCTION public.lessons_summary_r2582()
RETURNS TABLE (
  id uuid,
  conflict_at timestamptz,
  conflict_kind text,
  severity text,
  outcome_kind text,
  lesson_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.conflict_at, c.conflict_kind, c.severity, c.outcome_kind, c.lesson_md
    FROM public.engineer_conflicts_r2582 c
    WHERE c.lesson_md IS NOT NULL AND length(c.lesson_md) > 0
    ORDER BY c.conflict_at DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.lessons_summary_r2582() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.lessons_summary_r2582() TO authenticated;
