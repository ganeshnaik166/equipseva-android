-- Round 2609: Founder Monthly Investor Data Room Freshness
-- Tables track data room sections + refresh actions; RPCs surface freshness, cadence compliance, kind breakdown.

CREATE TABLE IF NOT EXISTS public.investor_data_room_sections_r2609 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  section_label text NOT NULL,
  section_kind text NOT NULL CHECK (section_kind IN ('financials','cap_table','customers','team','competition','strategy','risks','legal')),
  last_refreshed_at timestamptz NOT NULL,
  required_cadence_days int NOT NULL DEFAULT 30,
  days_until_stale int NOT NULL DEFAULT 0,
  stale_flag boolean NOT NULL DEFAULT false,
  accessed_by_count int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'fresh' CHECK (status IN ('fresh','aging','stale','archived')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.data_room_refresh_actions_r2609 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  section_id uuid NOT NULL REFERENCES public.investor_data_room_sections_r2609(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('refresh','redact','expand','restructure')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text
);

ALTER TABLE public.investor_data_room_sections_r2609 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_room_refresh_actions_r2609 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_data_room_sections_r2609;
CREATE POLICY founder_all ON public.investor_data_room_sections_r2609
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.data_room_refresh_actions_r2609;
CREATE POLICY founder_all ON public.data_room_refresh_actions_r2609
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.investor_data_room_sections_r2609
  (section_label, section_kind, last_refreshed_at, required_cadence_days, days_until_stale, stale_flag, accessed_by_count, owner_email, status, notes)
VALUES
  ('Monthly P and L pack', 'financials', '2026-06-10T09:00:00Z'::timestamptz, 30, 19, false, 12, 'cfo@equipseva.com', 'fresh', 'June close locked, includes AMC pool reconciliation'),
  ('Cap table snapshot', 'cap_table', '2026-04-20T10:00:00Z'::timestamptz, 90, 28, false, 9, 'founder@equipseva.com', 'aging', 'Pending option grant batch 7 issue'),
  ('Customer concentration deck', 'customers', '2026-03-15T11:00:00Z'::timestamptz, 60, -38, true, 22, 'sales@equipseva.com', 'stale', 'Needs refresh after Tier-2 chain wins'),
  ('Team org chart', 'team', '2026-05-22T08:30:00Z'::timestamptz, 45, 16, false, 7, 'people@equipseva.com', 'fresh', 'Reflects new VP-Service hire'),
  ('Competitive landscape', 'competition', '2026-02-01T09:15:00Z'::timestamptz, 90, -50, true, 14, 'strategy@equipseva.com', 'stale', 'Indegene and Trivitron moves not captured');

INSERT INTO public.data_room_refresh_actions_r2609
  (section_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-12T09:00:00Z'::timestamptz, 'refresh', 'positive', 'cfo@equipseva.com', 'done', 'June pack uploaded to room'
FROM public.investor_data_room_sections_r2609 WHERE section_label = 'Monthly P and L pack' LIMIT 1;

INSERT INTO public.data_room_refresh_actions_r2609
  (section_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-18T10:00:00Z'::timestamptz, 'expand', 'pending', 'sales@equipseva.com', 'open', 'Add hospital chain logos and ARR per logo'
FROM public.investor_data_room_sections_r2609 WHERE section_label = 'Customer concentration deck' LIMIT 1;

INSERT INTO public.data_room_refresh_actions_r2609
  (section_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-19T14:00:00Z'::timestamptz, 'restructure', 'neutral', 'strategy@equipseva.com', 'open', 'Move feature matrix to appendix'
FROM public.investor_data_room_sections_r2609 WHERE section_label = 'Competitive landscape' LIMIT 1;

INSERT INTO public.data_room_refresh_actions_r2609
  (section_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-05T11:30:00Z'::timestamptz, 'redact', 'positive', 'legal@equipseva.com', 'done', 'Scrubbed personal info from grants doc'
FROM public.investor_data_room_sections_r2609 WHERE section_label = 'Cap table snapshot' LIMIT 1;

-- RPC 1: list sections
CREATE OR REPLACE FUNCTION public.list_sections_r2609()
RETURNS TABLE (
  id uuid,
  section_label text,
  section_kind text,
  last_refreshed_at timestamptz,
  required_cadence_days int,
  days_until_stale int,
  stale_flag boolean,
  accessed_by_count int,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.id, s.section_label, s.section_kind, s.last_refreshed_at, s.required_cadence_days,
           s.days_until_stale, s.stale_flag, s.accessed_by_count, s.owner_email, s.status, s.notes
    FROM public.investor_data_room_sections_r2609 s
    ORDER BY s.stale_flag DESC, s.days_until_stale ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_sections_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_sections_r2609() TO authenticated;

-- RPC 2: list refresh actions
CREATE OR REPLACE FUNCTION public.list_refresh_actions_r2609()
RETURNS TABLE (
  id uuid,
  section_label text,
  action_at timestamptz,
  action_kind text,
  outcome text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, s.section_label, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
    FROM public.data_room_refresh_actions_r2609 a
    JOIN public.investor_data_room_sections_r2609 s ON s.id = a.section_id
    ORDER BY a.action_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_refresh_actions_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_refresh_actions_r2609() TO authenticated;

-- RPC 3: stale focus
CREATE OR REPLACE FUNCTION public.stale_focus_r2609()
RETURNS TABLE (
  section_label text,
  section_kind text,
  days_until_stale int,
  status text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_label, s.section_kind, s.days_until_stale, s.status, s.owner_email, s.notes
    FROM public.investor_data_room_sections_r2609 s
    WHERE s.stale_flag = true OR s.status IN ('aging','stale')
    ORDER BY s.days_until_stale ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.stale_focus_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stale_focus_r2609() TO authenticated;

-- RPC 4: section kind breakdown
CREATE OR REPLACE FUNCTION public.section_kind_breakdown_r2609()
RETURNS TABLE (
  section_kind text,
  total_sections int,
  stale_sections int,
  fresh_sections int,
  avg_days_until_stale numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_kind,
           COUNT(*)::int AS total_sections,
           SUM(CASE WHEN s.stale_flag THEN 1 ELSE 0 END)::int AS stale_sections,
           SUM(CASE WHEN s.status = 'fresh' THEN 1 ELSE 0 END)::int AS fresh_sections,
           ROUND(AVG(s.days_until_stale)::numeric, 2) AS avg_days_until_stale
    FROM public.investor_data_room_sections_r2609 s
    GROUP BY s.section_kind
    ORDER BY stale_sections DESC, s.section_kind ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.section_kind_breakdown_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.section_kind_breakdown_r2609() TO authenticated;

-- RPC 5: cadence compliance summary
CREATE OR REPLACE FUNCTION public.cadence_compliance_summary_r2609()
RETURNS TABLE (
  metric_label text,
  metric_value numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT 'total_sections'::text, COUNT(*)::numeric FROM public.investor_data_room_sections_r2609
    UNION ALL
    SELECT 'within_cadence'::text, COUNT(*)::numeric FROM public.investor_data_room_sections_r2609 WHERE stale_flag = false
    UNION ALL
    SELECT 'breached_cadence'::text, COUNT(*)::numeric FROM public.investor_data_room_sections_r2609 WHERE stale_flag = true
    UNION ALL
    SELECT 'avg_cadence_days'::text, COALESCE(ROUND(AVG(required_cadence_days)::numeric, 2), 0) FROM public.investor_data_room_sections_r2609
    UNION ALL
    SELECT 'compliance_pct'::text,
           COALESCE(ROUND(100.0 * SUM(CASE WHEN stale_flag = false THEN 1 ELSE 0 END)::numeric / NULLIF(COUNT(*), 0), 2), 0)
    FROM public.investor_data_room_sections_r2609;
END;$$;
REVOKE EXECUTE ON FUNCTION public.cadence_compliance_summary_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cadence_compliance_summary_r2609() TO authenticated;

-- RPC 6: monthly refresh trend
CREATE OR REPLACE FUNCTION public.monthly_refresh_trend_r2609()
RETURNS TABLE (
  month_label text,
  refresh_actions int,
  done_actions int,
  positive_outcomes int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT to_char(date_trunc('month', a.action_at), 'YYYY-MM') AS month_label,
           COUNT(*)::int AS refresh_actions,
           SUM(CASE WHEN a.status = 'done' THEN 1 ELSE 0 END)::int AS done_actions,
           SUM(CASE WHEN a.outcome = 'positive' THEN 1 ELSE 0 END)::int AS positive_outcomes
    FROM public.data_room_refresh_actions_r2609 a
    GROUP BY date_trunc('month', a.action_at)
    ORDER BY date_trunc('month', a.action_at) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_refresh_trend_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_refresh_trend_r2609() TO authenticated;

-- RPC 7: accessed by summary
CREATE OR REPLACE FUNCTION public.accessed_by_summary_r2609()
RETURNS TABLE (
  section_label text,
  section_kind text,
  accessed_by_count int,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT s.section_label, s.section_kind, s.accessed_by_count, s.status
    FROM public.investor_data_room_sections_r2609 s
    ORDER BY s.accessed_by_count DESC, s.section_label ASC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.accessed_by_summary_r2609() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accessed_by_summary_r2609() TO authenticated;
