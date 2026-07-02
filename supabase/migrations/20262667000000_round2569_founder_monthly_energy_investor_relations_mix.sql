-- Round 2569: founder-monthly-energy-investor-relations-mix
-- Monthly IR time × dilution × leverage × stalling × ROI per investor hour

CREATE TABLE IF NOT EXISTS public.founder_monthly_ir_mix_r2569 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  month_label text NOT NULL,
  ir_hours numeric NOT NULL DEFAULT 0,
  dilution_pct numeric NOT NULL DEFAULT 0,
  leverage_score int NOT NULL DEFAULT 0 CHECK (leverage_score BETWEEN 0 AND 100),
  stalling_count int NOT NULL DEFAULT 0,
  roi_per_hour_rupees bigint NOT NULL DEFAULT 0,
  top_high_leverage_investor text,
  top_drain_investor text,
  owner_email text,
  status text NOT NULL DEFAULT 'monitoring' CHECK (status IN ('monitoring','optimizing','scaled_back','maxed')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.ir_hour_reallocation_actions_r2569 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  mix_id uuid NOT NULL REFERENCES public.founder_monthly_ir_mix_r2569(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('delegate','automate','eliminate','reduce_cadence','escalate')),
  action_summary text NOT NULL,
  expected_impact_md text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  notes text
);

ALTER TABLE public.founder_monthly_ir_mix_r2569 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ir_hour_reallocation_actions_r2569 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_monthly_ir_mix_r2569;
CREATE POLICY founder_all ON public.founder_monthly_ir_mix_r2569
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.ir_hour_reallocation_actions_r2569;
CREATE POLICY founder_all ON public.ir_hour_reallocation_actions_r2569
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed
INSERT INTO public.founder_monthly_ir_mix_r2569
  (month_label, ir_hours, dilution_pct, leverage_score, stalling_count, roi_per_hour_rupees, top_high_leverage_investor, top_drain_investor, owner_email, status, notes)
VALUES
  ('2026-03', 42.5, 0.0, 38, 4, 0, 'Blume Ventures', 'Tourist Angel #7', 'founder@equipseva.in', 'monitoring', 'Pre-term sheet; lots of intro calls'),
  ('2026-04', 56.0, 0.0, 47, 6, 0, 'Accel India', 'Family Office X', 'founder@equipseva.in', 'optimizing', 'Term sheet draft circulating'),
  ('2026-05', 38.0, 8.5, 72, 2, 12500000, 'Accel India', 'Tourist Angel #7', 'founder@equipseva.in', 'optimizing', 'Closed seed; ₹5Cr at 8.5% dilution'),
  ('2026-06', 22.0, 8.5, 81, 1, 22700000, 'Accel India', 'WhatsApp Group Lurker', 'founder@equipseva.in', 'scaled_back', 'Post-close; only board + power-users');

INSERT INTO public.ir_hour_reallocation_actions_r2569
  (mix_id, action_at, action_kind, action_summary, expected_impact_md, status, outcome, owner_email, notes)
VALUES
  ((SELECT id FROM public.founder_monthly_ir_mix_r2569 WHERE month_label='2026-04' LIMIT 1),
   '2026-04-15T10:00:00+05:30'::timestamptz, 'eliminate',
   'Stopped responding to cold WhatsApp DMs from tourist angels',
   'Recover ~6h/month, zero downside (none ever wired)', 'done', 'positive',
   'founder@equipseva.in', 'Auto-reply pointing to public deck'),
  ((SELECT id FROM public.founder_monthly_ir_mix_r2569 WHERE month_label='2026-05' LIMIT 1),
   '2026-05-10T11:00:00+05:30'::timestamptz, 'automate',
   'Investor update auto-generated from board pack pipeline',
   'Save 4h/month writing monthly memo', 'in_progress', 'pending',
   'founder@equipseva.in', 'Hooked into existing weekly board pack'),
  ((SELECT id FROM public.founder_monthly_ir_mix_r2569 WHERE month_label='2026-06' LIMIT 1),
   '2026-06-05T09:30:00+05:30'::timestamptz, 'reduce_cadence',
   'Board calls moved from weekly to monthly post-close',
   'Recover 8h/month; board agreed', 'done', 'positive',
   'founder@equipseva.in', 'Slack channel for async'),
  ((SELECT id FROM public.founder_monthly_ir_mix_r2569 WHERE month_label='2026-06' LIMIT 1),
   '2026-06-12T14:00:00+05:30'::timestamptz, 'delegate',
   'CoS handles inbound family-office intros, only escalate Tier-1',
   'Recover 5h/month, no quality loss', 'planned', 'pending',
   'founder@equipseva.in', 'Need to hire CoS first');

-- RPCs
CREATE OR REPLACE FUNCTION public.list_ir_mix_r2569()
RETURNS TABLE (
  id uuid, month_label text, ir_hours numeric, dilution_pct numeric,
  leverage_score int, stalling_count int, roi_per_hour_rupees bigint,
  top_high_leverage_investor text, top_drain_investor text,
  owner_email text, status text, notes text, created_at timestamptz
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.month_label, m.ir_hours, m.dilution_pct,
         m.leverage_score, m.stalling_count, m.roi_per_hour_rupees,
         m.top_high_leverage_investor, m.top_drain_investor,
         m.owner_email, m.status, m.notes, m.created_at
  FROM public.founder_monthly_ir_mix_r2569 m
  ORDER BY m.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_ir_mix_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_ir_mix_r2569() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_reallocation_actions_r2569()
RETURNS TABLE (
  id uuid, mix_id uuid, month_label text, action_at timestamptz,
  action_kind text, action_summary text, expected_impact_md text,
  status text, outcome text, owner_email text, notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.mix_id, m.month_label, a.action_at,
         a.action_kind, a.action_summary, a.expected_impact_md,
         a.status, a.outcome, a.owner_email, a.notes
  FROM public.ir_hour_reallocation_actions_r2569 a
  JOIN public.founder_monthly_ir_mix_r2569 m ON m.id = a.mix_id
  ORDER BY a.action_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_reallocation_actions_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reallocation_actions_r2569() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_leverage_trend_r2569()
RETURNS TABLE (
  month_label text, ir_hours numeric, leverage_score int,
  stalling_count int, roi_per_hour_rupees bigint, status text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.month_label, m.ir_hours, m.leverage_score,
         m.stalling_count, m.roi_per_hour_rupees, m.status
  FROM public.founder_monthly_ir_mix_r2569 m
  ORDER BY m.month_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_leverage_trend_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_leverage_trend_r2569() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_distribution_r2569()
RETURNS TABLE (
  status text, cnt bigint, avg_leverage numeric,
  total_ir_hours numeric, avg_stalling numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.status, COUNT(*)::bigint,
         ROUND(AVG(m.leverage_score)::numeric, 2),
         SUM(m.ir_hours),
         ROUND(AVG(m.stalling_count)::numeric, 2)
  FROM public.founder_monthly_ir_mix_r2569 m
  GROUP BY m.status
  ORDER BY COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_distribution_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_distribution_r2569() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_drain_investors_r2569()
RETURNS TABLE (
  top_drain_investor text, occurrences bigint,
  total_stalling int, avg_leverage numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.top_drain_investor, COUNT(*)::bigint,
         SUM(m.stalling_count)::int,
         ROUND(AVG(m.leverage_score)::numeric, 2)
  FROM public.founder_monthly_ir_mix_r2569 m
  WHERE m.top_drain_investor IS NOT NULL
  GROUP BY m.top_drain_investor
  ORDER BY SUM(m.stalling_count) DESC, COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_drain_investors_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_drain_investors_r2569() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_high_leverage_focus_r2569()
RETURNS TABLE (
  top_high_leverage_investor text, occurrences bigint,
  avg_leverage numeric, total_roi_rupees bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.top_high_leverage_investor, COUNT(*)::bigint,
         ROUND(AVG(m.leverage_score)::numeric, 2),
         SUM(m.roi_per_hour_rupees)::bigint
  FROM public.founder_monthly_ir_mix_r2569 m
  WHERE m.top_high_leverage_investor IS NOT NULL
  GROUP BY m.top_high_leverage_investor
  ORDER BY AVG(m.leverage_score) DESC, COUNT(*) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_high_leverage_focus_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_high_leverage_focus_r2569() TO authenticated;

CREATE OR REPLACE FUNCTION public.action_status_funnel_r2569()
RETURNS TABLE (
  action_kind text, status text, outcome text, cnt bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.action_kind, a.status, a.outcome, COUNT(*)::bigint
  FROM public.ir_hour_reallocation_actions_r2569 a
  GROUP BY a.action_kind, a.status, a.outcome
  ORDER BY COUNT(*) DESC, a.action_kind ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_status_funnel_r2569() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_status_funnel_r2569() TO authenticated;
