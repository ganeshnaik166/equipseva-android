-- r2626 engineer-customer-trust-recovery-playbook

CREATE TABLE IF NOT EXISTS public.engineer_trust_recovery_r2626 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  trust_break_at timestamptz NOT NULL DEFAULT now(),
  break_kind text NOT NULL CHECK (break_kind IN ('missed_promise','wrong_diagnosis','lateness','communication','quality')),
  recovery_path_md text NOT NULL DEFAULT '',
  recovery_outcome text NOT NULL DEFAULT 'in_progress' CHECK (recovery_outcome IN ('restored','partial','lost','in_progress')),
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.trust_recovery_steps_r2626 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recovery_id uuid NOT NULL REFERENCES public.engineer_trust_recovery_r2626(id) ON DELETE CASCADE,
  step_at timestamptz NOT NULL DEFAULT now(),
  step_kind text NOT NULL CHECK (step_kind IN ('apology','refund','extra_service','exec_call','handover_swap')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_trust_recovery_r2626 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trust_recovery_steps_r2626 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_trust_recovery_r2626;
CREATE POLICY founder_all ON public.engineer_trust_recovery_r2626
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.trust_recovery_steps_r2626;
CREATE POLICY founder_all ON public.trust_recovery_steps_r2626
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
DO $seed$
DECLARE
  v_eng1 uuid;
  v_eng2 uuid;
  v_eng3 uuid;
  v_hosp1 uuid;
  v_hosp2 uuid;
  v_hosp3 uuid;
  v_rec1 uuid;
  v_rec2 uuid;
  v_rec3 uuid;
  v_rec4 uuid;
BEGIN
  SELECT id INTO v_eng1 FROM public.engineers ORDER BY created_at LIMIT 1;
  SELECT id INTO v_eng2 FROM public.engineers ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_eng3 FROM public.engineers ORDER BY created_at OFFSET 2 LIMIT 1;
  SELECT id INTO v_hosp1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_hosp2 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 1 LIMIT 1;
  SELECT id INTO v_hosp3 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at OFFSET 2 LIMIT 1;

  IF v_eng1 IS NULL OR v_hosp1 IS NULL THEN
    RETURN;
  END IF;

  v_eng2 := COALESCE(v_eng2, v_eng1);
  v_eng3 := COALESCE(v_eng3, v_eng1);
  v_hosp2 := COALESCE(v_hosp2, v_hosp1);
  v_hosp3 := COALESCE(v_hosp3, v_hosp1);

  INSERT INTO public.engineer_trust_recovery_r2626 (engineer_user_id, hospital_user_id, trust_break_at, break_kind, recovery_path_md, recovery_outcome, owner_email, status, notes)
  VALUES (v_eng1, v_hosp1, '2026-06-10 10:00:00'::timestamptz, 'missed_promise', 'Step 1 apology call. Step 2 free maintenance visit. Step 3 follow up after 30 days.', 'restored', 'ops@equipseva.in', 'closed', 'Hospital signed renewal after recovery')
  RETURNING id INTO v_rec1;

  INSERT INTO public.engineer_trust_recovery_r2626 (engineer_user_id, hospital_user_id, trust_break_at, break_kind, recovery_path_md, recovery_outcome, owner_email, status, notes)
  VALUES (v_eng2, v_hosp2, '2026-06-14 09:00:00'::timestamptz, 'wrong_diagnosis', 'Step 1 senior engineer revisit. Step 2 refund partial fee. Step 3 swap primary engineer.', 'in_progress', 'qa@equipseva.in', 'in_progress', 'Senior re-diagnosis booked next week')
  RETURNING id INTO v_rec2;

  INSERT INTO public.engineer_trust_recovery_r2626 (engineer_user_id, hospital_user_id, trust_break_at, break_kind, recovery_path_md, recovery_outcome, owner_email, status, notes)
  VALUES (v_eng3, v_hosp3, '2026-06-16 14:30:00'::timestamptz, 'lateness', 'Step 1 apology. Step 2 priority slot for 60 days. Step 3 exec call.', 'partial', 'ops@equipseva.in', 'in_progress', 'Hospital open to continuing relationship')
  RETURNING id INTO v_rec3;

  INSERT INTO public.engineer_trust_recovery_r2626 (engineer_user_id, hospital_user_id, trust_break_at, break_kind, recovery_path_md, recovery_outcome, owner_email, status, notes)
  VALUES (v_eng1, v_hosp2, '2026-06-18 11:00:00'::timestamptz, 'communication', 'Step 1 written apology. Step 2 monthly review call schedule.', 'in_progress', 'founder@equipseva.in', 'open', 'Awaiting hospital response on call cadence')
  RETURNING id INTO v_rec4;

  INSERT INTO public.trust_recovery_steps_r2626 (recovery_id, step_at, step_kind, outcome, owner_email, status, notes) VALUES
    (v_rec1, '2026-06-11 11:00:00'::timestamptz, 'apology', 'positive', 'ops@equipseva.in', 'done', 'Apology accepted'),
    (v_rec1, '2026-06-14 14:00:00'::timestamptz, 'extra_service', 'positive', 'ops@equipseva.in', 'done', 'Free maintenance done'),
    (v_rec2, '2026-06-15 10:00:00'::timestamptz, 'handover_swap', 'pending', 'qa@equipseva.in', 'open', 'New engineer assigned'),
    (v_rec2, '2026-06-16 12:00:00'::timestamptz, 'refund', 'neutral', 'finance@equipseva.in', 'done', 'Partial refund processed'),
    (v_rec3, '2026-06-17 09:30:00'::timestamptz, 'exec_call', 'positive', 'founder@equipseva.in', 'done', 'Founder spoke with hospital admin'),
    (v_rec4, '2026-06-19 16:00:00'::timestamptz, 'apology', 'pending', 'founder@equipseva.in', 'open', 'Written note delivered');
END;
$seed$;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_recoveries_r2626()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  hospital_user_id uuid,
  trust_break_at timestamptz,
  break_kind text,
  recovery_outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.engineer_user_id, r.hospital_user_id, r.trust_break_at, r.break_kind, r.recovery_outcome, r.owner_email, r.status, r.notes
  FROM public.engineer_trust_recovery_r2626 r
  ORDER BY r.trust_break_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recoveries_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recoveries_r2626() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_recovery_steps_r2626()
RETURNS TABLE (
  id uuid,
  recovery_id uuid,
  step_at timestamptz,
  step_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.recovery_id, s.step_at, s.step_kind, s.outcome, s.owner_email, s.status, s.notes
  FROM public.trust_recovery_steps_r2626 s
  ORDER BY s.step_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_recovery_steps_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_recovery_steps_r2626() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_break_kind_focus_r2626()
RETURNS TABLE (break_kind text, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.break_kind, COUNT(*)::bigint AS total
  FROM public.engineer_trust_recovery_r2626 r
  GROUP BY r.break_kind
  ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_break_kind_focus_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_break_kind_focus_r2626() TO authenticated;

CREATE OR REPLACE FUNCTION public.recovery_outcome_distribution_r2626()
RETURNS TABLE (recovery_outcome text, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.recovery_outcome, COUNT(*)::bigint AS total
  FROM public.engineer_trust_recovery_r2626 r
  GROUP BY r.recovery_outcome
  ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.recovery_outcome_distribution_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recovery_outcome_distribution_r2626() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_funnel_r2626()
RETURNS TABLE (status text, total bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.status, COUNT(*)::bigint AS total
  FROM public.engineer_trust_recovery_r2626 r
  GROUP BY r.status
  ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2626() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_recovery_trend_r2626()
RETURNS TABLE (month_start timestamptz, total bigint, restored bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', r.trust_break_at) AS month_start,
         COUNT(*)::bigint AS total,
         COUNT(*) FILTER (WHERE r.recovery_outcome = 'restored')::bigint AS restored
  FROM public.engineer_trust_recovery_r2626 r
  GROUP BY date_trunc('month', r.trust_break_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_recovery_trend_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_recovery_trend_r2626() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2626()
RETURNS TABLE (owner_email text, total bigint, open_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.owner_email,
         COUNT(*)::bigint AS total,
         COUNT(*) FILTER (WHERE r.status IN ('open','in_progress'))::bigint AS open_count
  FROM public.engineer_trust_recovery_r2626 r
  GROUP BY r.owner_email
  ORDER BY total DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2626() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2626() TO authenticated;
