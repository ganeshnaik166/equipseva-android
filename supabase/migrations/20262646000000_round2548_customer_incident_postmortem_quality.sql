-- Round 2548: customer-incident-postmortem-quality
-- Tracks how rigorously hospital customer incidents get post-mortemed: depth, action items, follow-through, no-repeat record.

CREATE TABLE IF NOT EXISTS public.customer_incident_postmortems_r2548 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  incident_kind text NOT NULL CHECK (incident_kind IN ('downtime','wrong_part','data_loss','safety_event','billing_dispute')),
  incident_at timestamptz NOT NULL,
  postmortem_started_at timestamptz,
  postmortem_completed_at timestamptz,
  root_cause_depth_score int NOT NULL DEFAULT 0 CHECK (root_cause_depth_score BETWEEN 0 AND 100),
  action_items_count int NOT NULL DEFAULT 0,
  follow_through_rate_pct numeric(5,2) NOT NULL DEFAULT 0,
  no_repeat_track_record_months int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','in_progress','completed','skipped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.postmortem_action_items_r2548 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  postmortem_id uuid NOT NULL REFERENCES public.customer_incident_postmortems_r2548(id) ON DELETE CASCADE,
  action_text text NOT NULL,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','dropped')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  closed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_incident_postmortems_r2548 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.postmortem_action_items_r2548 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_incident_postmortems_r2548;
CREATE POLICY founder_all ON public.customer_incident_postmortems_r2548
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.postmortem_action_items_r2548;
CREATE POLICY founder_all ON public.postmortem_action_items_r2548
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed postmortems
INSERT INTO public.customer_incident_postmortems_r2548
  (id, hospital_user_id, incident_kind, incident_at, postmortem_started_at, postmortem_completed_at,
   root_cause_depth_score, action_items_count, follow_through_rate_pct, no_repeat_track_record_months,
   owner_email, status, notes)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, NULL, 'downtime',
   '2026-05-12 09:00:00'::timestamptz, '2026-05-13 10:00:00'::timestamptz, '2026-05-14 16:00:00'::timestamptz,
   85, 5, 80.00, 6, 'founder@equipseva.in', 'completed', 'Deep RCA, 5-whys complete'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, NULL, 'wrong_part',
   '2026-04-20 14:00:00'::timestamptz, '2026-04-21 09:00:00'::timestamptz, '2026-04-22 11:00:00'::timestamptz,
   72, 4, 75.00, 4, 'ops@equipseva.in', 'completed', 'Picker error + scan gap'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa03'::uuid, NULL, 'safety_event',
   '2026-06-01 11:30:00'::timestamptz, '2026-06-01 14:00:00'::timestamptz, NULL,
   60, 3, 33.33, 0, 'safety@equipseva.in', 'in_progress', 'Critical, awaiting closure'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa04'::uuid, NULL, 'billing_dispute',
   '2026-03-10 10:00:00'::timestamptz, '2026-03-11 09:00:00'::timestamptz, '2026-03-12 15:00:00'::timestamptz,
   55, 2, 100.00, 9, 'finance@equipseva.in', 'completed', 'Invoice template fixed'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa05'::uuid, NULL, 'data_loss',
   '2026-02-18 08:00:00'::timestamptz, NULL, NULL,
   0, 0, 0, 0, 'founder@equipseva.in', 'skipped', 'Skipped, low impact noted');

-- Seed action items
INSERT INTO public.postmortem_action_items_r2548
  (postmortem_id, action_text, owner_email, due_at, status, outcome, closed_at, notes)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, 'Add health-check on payment gateway', 'eng@equipseva.in',
   '2026-05-25 17:00:00'::timestamptz, 'done', 'positive', '2026-05-22 14:00:00'::timestamptz, 'Cuts downtime alert lag 80%'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, 'Runbook for cron failure', 'ops@equipseva.in',
   '2026-05-28 17:00:00'::timestamptz, 'done', 'positive', '2026-05-27 11:00:00'::timestamptz, 'Runbook live'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, 'Auto-page on-call from cron', 'eng@equipseva.in',
   '2026-06-10 17:00:00'::timestamptz, 'in_progress', 'pending', NULL, 'PagerDuty integration WIP'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, 'Add chaos drill quarterly', 'founder@equipseva.in',
   '2026-07-01 17:00:00'::timestamptz, 'open', 'pending', NULL, 'Scheduled Q3'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa01'::uuid, 'Dashboard for cron health', 'eng@equipseva.in',
   '2026-05-30 17:00:00'::timestamptz, 'done', 'neutral', '2026-05-29 16:00:00'::timestamptz, 'Live but low usage'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, 'Barcode scan-gate at pick', 'ops@equipseva.in',
   '2026-05-05 17:00:00'::timestamptz, 'done', 'positive', '2026-05-03 12:00:00'::timestamptz, 'Wrong-part to zero'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, 'Picker SOP refresh', 'ops@equipseva.in',
   '2026-05-08 17:00:00'::timestamptz, 'done', 'positive', '2026-05-07 09:00:00'::timestamptz, 'All pickers retrained'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, 'Photo confirmation on dispatch', 'ops@equipseva.in',
   '2026-05-15 17:00:00'::timestamptz, 'done', 'positive', '2026-05-13 10:00:00'::timestamptz, 'Photo proof live'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa02'::uuid, 'Customer-side scan on receipt', 'ops@equipseva.in',
   '2026-06-15 17:00:00'::timestamptz, 'open', 'pending', NULL, 'Pilot with 2 hospitals'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa03'::uuid, 'Patch safety guard on field tool', 'safety@equipseva.in',
   '2026-06-10 17:00:00'::timestamptz, 'in_progress', 'pending', NULL, 'P0'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa03'::uuid, 'Notify CDSCO if recurrent', 'safety@equipseva.in',
   '2026-06-12 17:00:00'::timestamptz, 'open', 'pending', NULL, 'Reg compliance'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa03'::uuid, 'Engineer recert program', 'safety@equipseva.in',
   '2026-06-30 17:00:00'::timestamptz, 'open', 'pending', NULL, 'Plan in progress'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa04'::uuid, 'New invoice template + sample', 'finance@equipseva.in',
   '2026-03-20 17:00:00'::timestamptz, 'done', 'positive', '2026-03-18 12:00:00'::timestamptz, 'No dispute since'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaa04'::uuid, 'GST line-item breakout', 'finance@equipseva.in',
   '2026-03-22 17:00:00'::timestamptz, 'done', 'positive', '2026-03-21 11:00:00'::timestamptz, 'Customers happier');

-- RPC 1: list_postmortems_r2548
CREATE OR REPLACE FUNCTION public.list_postmortems_r2548()
RETURNS SETOF public.customer_incident_postmortems_r2548
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.customer_incident_postmortems_r2548 ORDER BY incident_at DESC, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_postmortems_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_postmortems_r2548() TO authenticated;

-- RPC 2: list_action_items_r2548
CREATE OR REPLACE FUNCTION public.list_action_items_r2548()
RETURNS SETOF public.postmortem_action_items_r2548
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.postmortem_action_items_r2548 ORDER BY due_at ASC NULLS LAST, created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_action_items_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_action_items_r2548() TO authenticated;

-- RPC 3: top_repeat_offender_kinds_r2548
CREATE OR REPLACE FUNCTION public.top_repeat_offender_kinds_r2548()
RETURNS TABLE(incident_kind text, incident_count bigint, avg_depth_score numeric, avg_follow_through_pct numeric, min_no_repeat_months int)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.incident_kind,
      COUNT(*)::bigint AS incident_count,
      ROUND(AVG(p.root_cause_depth_score)::numeric, 2) AS avg_depth_score,
      ROUND(AVG(p.follow_through_rate_pct)::numeric, 2) AS avg_follow_through_pct,
      MIN(p.no_repeat_track_record_months)::int AS min_no_repeat_months
    FROM public.customer_incident_postmortems_r2548 p
    GROUP BY p.incident_kind
    ORDER BY incident_count DESC, avg_depth_score ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_repeat_offender_kinds_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_repeat_offender_kinds_r2548() TO authenticated;

-- RPC 4: follow_through_rate_summary_r2548
CREATE OR REPLACE FUNCTION public.follow_through_rate_summary_r2548()
RETURNS TABLE(status text, postmortem_count bigint, avg_follow_through_pct numeric, avg_depth_score numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      p.status,
      COUNT(*)::bigint AS postmortem_count,
      ROUND(AVG(p.follow_through_rate_pct)::numeric, 2) AS avg_follow_through_pct,
      ROUND(AVG(p.root_cause_depth_score)::numeric, 2) AS avg_depth_score
    FROM public.customer_incident_postmortems_r2548 p
    GROUP BY p.status
    ORDER BY postmortem_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.follow_through_rate_summary_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.follow_through_rate_summary_r2548() TO authenticated;

-- RPC 5: no_repeat_record_top_hospitals_r2548
CREATE OR REPLACE FUNCTION public.no_repeat_record_top_hospitals_r2548()
RETURNS TABLE(postmortem_id uuid, incident_kind text, incident_at timestamptz, no_repeat_track_record_months int, follow_through_rate_pct numeric, root_cause_depth_score int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT p.id, p.incident_kind, p.incident_at, p.no_repeat_track_record_months,
           p.follow_through_rate_pct, p.root_cause_depth_score, p.status
    FROM public.customer_incident_postmortems_r2548 p
    ORDER BY p.no_repeat_track_record_months DESC, p.follow_through_rate_pct DESC
    LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.no_repeat_record_top_hospitals_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.no_repeat_record_top_hospitals_r2548() TO authenticated;

-- RPC 6: action_completion_rate_r2548
CREATE OR REPLACE FUNCTION public.action_completion_rate_r2548()
RETURNS TABLE(status text, item_count bigint, positive_outcomes bigint, negative_outcomes bigint, pending_outcomes bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      a.status,
      COUNT(*)::bigint AS item_count,
      SUM(CASE WHEN a.outcome = 'positive' THEN 1 ELSE 0 END)::bigint AS positive_outcomes,
      SUM(CASE WHEN a.outcome = 'negative' THEN 1 ELSE 0 END)::bigint AS negative_outcomes,
      SUM(CASE WHEN a.outcome = 'pending' THEN 1 ELSE 0 END)::bigint AS pending_outcomes
    FROM public.postmortem_action_items_r2548 a
    GROUP BY a.status
    ORDER BY item_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.action_completion_rate_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.action_completion_rate_r2548() TO authenticated;

-- RPC 7: monthly_postmortem_trend_r2548
CREATE OR REPLACE FUNCTION public.monthly_postmortem_trend_r2548()
RETURNS TABLE(month_label text, incident_count bigint, completed_count bigint, skipped_count bigint, avg_depth_score numeric, avg_follow_through_pct numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      to_char(date_trunc('month', p.incident_at), 'YYYY-MM') AS month_label,
      COUNT(*)::bigint AS incident_count,
      SUM(CASE WHEN p.status = 'completed' THEN 1 ELSE 0 END)::bigint AS completed_count,
      SUM(CASE WHEN p.status = 'skipped' THEN 1 ELSE 0 END)::bigint AS skipped_count,
      ROUND(AVG(p.root_cause_depth_score)::numeric, 2) AS avg_depth_score,
      ROUND(AVG(p.follow_through_rate_pct)::numeric, 2) AS avg_follow_through_pct
    FROM public.customer_incident_postmortems_r2548 p
    GROUP BY date_trunc('month', p.incident_at)
    ORDER BY month_label ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_postmortem_trend_r2548() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_postmortem_trend_r2548() TO authenticated;
