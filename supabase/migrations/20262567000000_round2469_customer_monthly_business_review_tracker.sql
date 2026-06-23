-- Round 2469: customer-monthly-business-review-tracker
-- Hospital × MBR meetings × KPIs reviewed × action items × follow-ups × MBR effectiveness score.

BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_mbrs_r2469 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mbr_month text NOT NULL,
  held_on timestamptz,
  attendees_md text,
  kpis_reviewed_md text,
  action_items_count int NOT NULL DEFAULT 0 CHECK (action_items_count >= 0),
  follow_up_count int NOT NULL DEFAULT 0 CHECK (follow_up_count >= 0),
  mbr_effectiveness_score int NOT NULL DEFAULT 0 CHECK (mbr_effectiveness_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','held','cancelled','rescheduled')),
  founder_attended boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customer_mbrs_r2469_hospital ON public.customer_mbrs_r2469(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_customer_mbrs_r2469_month ON public.customer_mbrs_r2469(mbr_month);
CREATE INDEX IF NOT EXISTS idx_customer_mbrs_r2469_status ON public.customer_mbrs_r2469(status);

CREATE TABLE IF NOT EXISTS public.mbr_action_followups_r2469 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mbr_id uuid NOT NULL REFERENCES public.customer_mbrs_r2469(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  closed_at timestamptz,
  closed_by_email text,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mbr_action_followups_r2469_mbr ON public.mbr_action_followups_r2469(mbr_id);
CREATE INDEX IF NOT EXISTS idx_mbr_action_followups_r2469_status ON public.mbr_action_followups_r2469(status);
CREATE INDEX IF NOT EXISTS idx_mbr_action_followups_r2469_due ON public.mbr_action_followups_r2469(due_at);

ALTER TABLE public.customer_mbrs_r2469 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mbr_action_followups_r2469 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_mbrs_r2469;
CREATE POLICY founder_all ON public.customer_mbrs_r2469
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.mbr_action_followups_r2469;
CREATE POLICY founder_all ON public.mbr_action_followups_r2469
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
DO $$
DECLARE
  v_h1 uuid;
  v_h2 uuid;
  v_h3 uuid;
  v_m1 uuid;
  v_m2 uuid;
  v_m3 uuid;
  v_m4 uuid;
BEGIN
  SELECT id INTO v_h1 FROM public.profiles WHERE role = 'hospital_admin' ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h2 FROM public.profiles WHERE role = 'hospital_admin' AND id <> COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid) ORDER BY created_at ASC LIMIT 1;
  SELECT id INTO v_h3 FROM public.profiles WHERE role = 'hospital_admin' AND id NOT IN (COALESCE(v_h1, '00000000-0000-0000-0000-000000000000'::uuid), COALESCE(v_h2, '00000000-0000-0000-0000-000000000000'::uuid)) ORDER BY created_at ASC LIMIT 1;

  IF v_h1 IS NOT NULL THEN
    INSERT INTO public.customer_mbrs_r2469(hospital_user_id, mbr_month, held_on, attendees_md, kpis_reviewed_md, action_items_count, follow_up_count, mbr_effectiveness_score, status, founder_attended, notes)
    VALUES (v_h1, '2026-04', '2026-04-25 11:00:00'::timestamptz, '- CEO\n- Biomed head\n- Founder', '- Uptime 98.2%\n- SLA breach 1\n- AMC renewal pipeline', 5, 3, 82, 'held', true, 'Strong session, founder closed renewal verbally')
    RETURNING id INTO v_m1;

    INSERT INTO public.customer_mbrs_r2469(hospital_user_id, mbr_month, held_on, attendees_md, kpis_reviewed_md, action_items_count, follow_up_count, mbr_effectiveness_score, status, founder_attended, notes)
    VALUES (v_h1, '2026-05', '2026-05-28 14:30:00'::timestamptz, '- CEO\n- Biomed head', '- Uptime 99.1%\n- 0 SLA breach\n- Spare parts inventory', 4, 4, 88, 'held', false, 'Customer satisfied, asked for chain expansion')
    RETURNING id INTO v_m2;
  END IF;

  IF v_h2 IS NOT NULL THEN
    INSERT INTO public.customer_mbrs_r2469(hospital_user_id, mbr_month, held_on, attendees_md, kpis_reviewed_md, action_items_count, follow_up_count, mbr_effectiveness_score, status, founder_attended, notes)
    VALUES (v_h2, '2026-05', '2026-05-15 10:00:00'::timestamptz, '- Procurement head', '- Cost per repair\n- Engineer rotation', 7, 2, 64, 'held', false, 'Pushback on pricing, needs follow-up')
    RETURNING id INTO v_m3;
  END IF;

  IF v_h3 IS NOT NULL THEN
    INSERT INTO public.customer_mbrs_r2469(hospital_user_id, mbr_month, held_on, attendees_md, kpis_reviewed_md, action_items_count, follow_up_count, mbr_effectiveness_score, status, founder_attended, notes)
    VALUES (v_h3, '2026-06', NULL, NULL, NULL, 0, 0, 0, 'scheduled', false, 'Calendar invite sent')
    RETURNING id INTO v_m4;
  END IF;

  IF v_m1 IS NOT NULL THEN
    INSERT INTO public.mbr_action_followups_r2469(mbr_id, action_text, owner_email, due_at, status, closed_at, closed_by_email, outcome, notes)
    VALUES (v_m1, 'Send updated AMC renewal quote', 'founder@equipseva.com', '2026-05-05 18:00:00'::timestamptz, 'done', '2026-05-03 16:00:00'::timestamptz, 'founder@equipseva.com', 'positive', 'Renewed for 2 years');
    INSERT INTO public.mbr_action_followups_r2469(mbr_id, action_text, owner_email, due_at, status, outcome)
    VALUES (v_m1, 'Provide engineer rotation report', 'ops@equipseva.com', '2026-05-10 18:00:00'::timestamptz, 'in_progress', 'pending');
  END IF;

  IF v_m2 IS NOT NULL THEN
    INSERT INTO public.mbr_action_followups_r2469(mbr_id, action_text, owner_email, due_at, status, outcome, notes)
    VALUES (v_m2, 'Scope chain expansion to 3 more units', 'founder@equipseva.com', '2026-06-15 18:00:00'::timestamptz, 'open', 'pending', 'High-value lead');
  END IF;

  IF v_m3 IS NOT NULL THEN
    INSERT INTO public.mbr_action_followups_r2469(mbr_id, action_text, owner_email, due_at, status, outcome, notes)
    VALUES (v_m3, 'Counter-propose pricing tier', 'sales@equipseva.com', '2026-05-25 18:00:00'::timestamptz, 'open', 'pending', 'Risk: may churn');
    INSERT INTO public.mbr_action_followups_r2469(mbr_id, action_text, owner_email, due_at, status, closed_at, outcome, notes)
    VALUES (v_m3, 'Audit engineer rotation last 90d', 'ops@equipseva.com', '2026-05-30 18:00:00'::timestamptz, 'dropped', '2026-05-29 12:00:00'::timestamptz, 'neutral', 'Customer dropped requirement');
  END IF;
END $$;

-- RPC 1: list_mbrs_r2469
CREATE OR REPLACE FUNCTION public.list_mbrs_r2469()
RETURNS TABLE(
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  mbr_month text,
  held_on timestamptz,
  action_items_count int,
  follow_up_count int,
  mbr_effectiveness_score int,
  status text,
  founder_attended boolean,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.hospital_user_id, p.email, m.mbr_month, m.held_on,
         m.action_items_count, m.follow_up_count, m.mbr_effectiveness_score,
         m.status, m.founder_attended, m.notes, m.created_at
  FROM public.customer_mbrs_r2469 m
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  ORDER BY COALESCE(m.held_on, m.created_at) DESC NULLS LAST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_mbrs_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_mbrs_r2469() TO authenticated;

-- RPC 2: list_action_followups_r2469
CREATE OR REPLACE FUNCTION public.list_action_followups_r2469()
RETURNS TABLE(
  id uuid,
  mbr_id uuid,
  mbr_month text,
  hospital_email text,
  action_text text,
  owner_email text,
  due_at timestamptz,
  status text,
  closed_at timestamptz,
  closed_by_email text,
  outcome text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.mbr_id, m.mbr_month, p.email, f.action_text, f.owner_email,
         f.due_at, f.status, f.closed_at, f.closed_by_email, f.outcome, f.notes, f.created_at
  FROM public.mbr_action_followups_r2469 f
  LEFT JOIN public.customer_mbrs_r2469 m ON m.id = f.mbr_id
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  ORDER BY f.created_at DESC
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_action_followups_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_followups_r2469() TO authenticated;

-- RPC 3: overdue_actions_r2469
CREATE OR REPLACE FUNCTION public.overdue_actions_r2469()
RETURNS TABLE(
  id uuid,
  mbr_id uuid,
  hospital_email text,
  action_text text,
  owner_email text,
  due_at timestamptz,
  days_overdue int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.mbr_id, p.email, f.action_text, f.owner_email, f.due_at,
         GREATEST(0, EXTRACT(DAY FROM (now() - f.due_at))::int) AS days_overdue,
         f.status
  FROM public.mbr_action_followups_r2469 f
  LEFT JOIN public.customer_mbrs_r2469 m ON m.id = f.mbr_id
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  WHERE f.status IN ('open','in_progress')
    AND f.due_at IS NOT NULL
    AND f.due_at < now()
  ORDER BY f.due_at ASC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION public.overdue_actions_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.overdue_actions_r2469() TO authenticated;

-- RPC 4: effectiveness_summary_r2469
CREATE OR REPLACE FUNCTION public.effectiveness_summary_r2469()
RETURNS TABLE(
  total_mbrs int,
  held_mbrs int,
  avg_effectiveness numeric,
  avg_action_items numeric,
  avg_follow_ups numeric,
  founder_attended_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status='held')::int,
    ROUND(AVG(mbr_effectiveness_score) FILTER (WHERE status='held')::numeric, 2),
    ROUND(AVG(action_items_count) FILTER (WHERE status='held')::numeric, 2),
    ROUND(AVG(follow_up_count) FILTER (WHERE status='held')::numeric, 2),
    ROUND(100.0 * COUNT(*) FILTER (WHERE status='held' AND founder_attended) / NULLIF(COUNT(*) FILTER (WHERE status='held'),0), 2)
  FROM public.customer_mbrs_r2469;
END $$;
REVOKE EXECUTE ON FUNCTION public.effectiveness_summary_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.effectiveness_summary_r2469() TO authenticated;

-- RPC 5: monthly_held_trend_r2469
CREATE OR REPLACE FUNCTION public.monthly_held_trend_r2469()
RETURNS TABLE(
  mbr_month text,
  held_count int,
  avg_effectiveness numeric,
  total_action_items int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.mbr_month,
         COUNT(*) FILTER (WHERE m.status='held')::int,
         ROUND(AVG(m.mbr_effectiveness_score) FILTER (WHERE m.status='held')::numeric, 2),
         COALESCE(SUM(m.action_items_count) FILTER (WHERE m.status='held'), 0)::int
  FROM public.customer_mbrs_r2469 m
  GROUP BY m.mbr_month
  ORDER BY m.mbr_month DESC
  LIMIT 24;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_held_trend_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_held_trend_r2469() TO authenticated;

-- RPC 6: top_hospitals_by_effectiveness_r2469
CREATE OR REPLACE FUNCTION public.top_hospitals_by_effectiveness_r2469()
RETURNS TABLE(
  hospital_user_id uuid,
  hospital_email text,
  mbr_count int,
  avg_effectiveness numeric,
  total_action_items int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.hospital_user_id,
         p.email,
         COUNT(*) FILTER (WHERE m.status='held')::int,
         ROUND(AVG(m.mbr_effectiveness_score) FILTER (WHERE m.status='held')::numeric, 2),
         COALESCE(SUM(m.action_items_count) FILTER (WHERE m.status='held'), 0)::int
  FROM public.customer_mbrs_r2469 m
  LEFT JOIN public.profiles p ON p.id = m.hospital_user_id
  GROUP BY m.hospital_user_id, p.email
  ORDER BY ROUND(AVG(m.mbr_effectiveness_score) FILTER (WHERE m.status='held')::numeric, 2) DESC NULLS LAST
  LIMIT 25;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_hospitals_by_effectiveness_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_hospitals_by_effectiveness_r2469() TO authenticated;

-- RPC 7: status_funnel_r2469
CREATE OR REPLACE FUNCTION public.status_funnel_r2469()
RETURNS TABLE(
  status text,
  mbr_count int,
  pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_total int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO v_total FROM public.customer_mbrs_r2469;
  RETURN QUERY
  SELECT m.status,
         COUNT(*)::int,
         ROUND(100.0 * COUNT(*) / NULLIF(v_total,0), 2)
  FROM public.customer_mbrs_r2469 m
  GROUP BY m.status
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2469() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2469() TO authenticated;

