-- Round 2537: founder-weekly-deep-work-block-protection
-- Tables: founder_deep_work_blocks_r2537, deep_work_commitment_devices_r2537
-- RPCs: list_blocks_r2537, list_commitment_devices_r2537, weekly_deep_work_trend_r2537,
--       stealer_kind_breakdown_r2537, top_quality_days_r2537, device_success_rate_r2537,
--       monthly_summary_r2537

BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_deep_work_blocks_r2537 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  day date NOT NULL,
  hours_planned numeric(5,2) NOT NULL DEFAULT 0,
  hours_actual numeric(5,2) NOT NULL DEFAULT 0,
  interruption_count int NOT NULL DEFAULT 0,
  top_stealer_kind text NOT NULL DEFAULT 'no_steal' CHECK (top_stealer_kind IN ('meetings','slack','email','firefighting','family','no_steal')),
  commitment_device_md text,
  block_quality_score int NOT NULL DEFAULT 0 CHECK (block_quality_score BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','missed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.deep_work_commitment_devices_r2537 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  device_kind text NOT NULL CHECK (device_kind IN ('calendar_block','do_not_disturb','away_message','founder_focus_room','co_working','morning_routine')),
  description_md text,
  success_count int NOT NULL DEFAULT 0,
  failure_count int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','retired','in_test')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_deep_work_blocks_r2537 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deep_work_commitment_devices_r2537 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_deep_work_blocks_r2537;
CREATE POLICY founder_all ON public.founder_deep_work_blocks_r2537
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.deep_work_commitment_devices_r2537;
CREATE POLICY founder_all ON public.deep_work_commitment_devices_r2537
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed deep-work blocks
INSERT INTO public.founder_deep_work_blocks_r2537
  (day, hours_planned, hours_actual, interruption_count, top_stealer_kind, commitment_device_md,
   block_quality_score, status, notes)
VALUES
  ('2026-06-15'::date, 4.0, 3.5, 1, 'slack',
   '## Device\n- DnD on phone\n- Slack snoozed', 82, 'done', 'monday roadmap block'),
  ('2026-06-16'::date, 4.0, 2.0, 4, 'meetings',
   '## Device\n- Calendar blocked but overridden', 50, 'done', 'investor calls broke flow'),
  ('2026-06-17'::date, 4.0, 0.0, 0, 'firefighting',
   '## Device\n- Tried away message\n- Cashfree incident hit', 0, 'missed', 'P0 incident day'),
  ('2026-06-18'::date, 3.0, 3.0, 0, 'no_steal',
   '## Device\n- Co-working space\n- No internet on phone', 95, 'done', 'best day this week'),
  ('2026-06-22'::date, 4.0, 0.0, 0, 'no_steal', NULL, 0, 'planned', 'planned for next week');

-- Seed commitment devices
INSERT INTO public.deep_work_commitment_devices_r2537
  (device_kind, description_md, success_count, failure_count, owner_email, status, notes)
VALUES
  ('calendar_block',
   '## Calendar Block\n- 6am-10am every weekday\n- Marked DO NOT BOOK',
   12, 4, 'founder@equipseva.in', 'active', 'baseline device'),
  ('do_not_disturb',
   '## DnD\n- Phone in DnD\n- Slack snoozed 4 hours',
   18, 2, 'founder@equipseva.in', 'active', 'most reliable'),
  ('co_working',
   '## Co-working\n- Headphones on\n- Different building from team',
   6, 0, 'founder@equipseva.in', 'in_test', 'expensive but effective'),
  ('away_message',
   '## Away Message\n- Auto-reply on email\n- "Back at 11am"',
   4, 8, 'founder@equipseva.in', 'retired', 'team ignored the message'),
  ('morning_routine',
   '## Morning Routine\n- No phone until 9am\n- Walk + plan first',
   10, 3, 'founder@equipseva.in', 'active', 'pairs well with calendar block');

CREATE OR REPLACE FUNCTION public.list_blocks_r2537()
RETURNS TABLE (id uuid, day date, hours_planned numeric, hours_actual numeric,
               interruption_count int, top_stealer_kind text, block_quality_score int,
               status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.id, b.day, b.hours_planned, b.hours_actual, b.interruption_count,
           b.top_stealer_kind, b.block_quality_score, b.status, b.notes
    FROM public.founder_deep_work_blocks_r2537 b
    ORDER BY b.day DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_blocks_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_blocks_r2537() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_commitment_devices_r2537()
RETURNS TABLE (id uuid, device_kind text, success_count int, failure_count int,
               owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.id, d.device_kind, d.success_count, d.failure_count,
           d.owner_email, d.status, d.notes
    FROM public.deep_work_commitment_devices_r2537 d
    ORDER BY d.success_count DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_commitment_devices_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_commitment_devices_r2537() TO authenticated;

CREATE OR REPLACE FUNCTION public.weekly_deep_work_trend_r2537()
RETURNS TABLE (week_start date, blocks_count bigint, total_planned numeric,
               total_actual numeric, avg_quality numeric, total_interruptions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT (date_trunc('week', b.day)::date) AS week_start,
           count(*)::bigint,
           round(sum(b.hours_planned)::numeric, 2),
           round(sum(b.hours_actual)::numeric, 2),
           round(avg(b.block_quality_score)::numeric, 2),
           sum(b.interruption_count)::bigint
    FROM public.founder_deep_work_blocks_r2537 b
    GROUP BY date_trunc('week', b.day)
    ORDER BY week_start DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.weekly_deep_work_trend_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_deep_work_trend_r2537() TO authenticated;

CREATE OR REPLACE FUNCTION public.stealer_kind_breakdown_r2537()
RETURNS TABLE (top_stealer_kind text, blocks_count bigint, avg_quality numeric,
               total_interruptions bigint, total_hours_lost numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.top_stealer_kind,
           count(*)::bigint,
           round(avg(b.block_quality_score)::numeric, 2),
           sum(b.interruption_count)::bigint,
           round(sum(b.hours_planned - b.hours_actual)::numeric, 2)
    FROM public.founder_deep_work_blocks_r2537 b
    GROUP BY b.top_stealer_kind
    ORDER BY round(sum(b.hours_planned - b.hours_actual)::numeric, 2) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.stealer_kind_breakdown_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stealer_kind_breakdown_r2537() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_quality_days_r2537()
RETURNS TABLE (day date, hours_actual numeric, block_quality_score int,
               top_stealer_kind text, interruption_count int, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT b.day, b.hours_actual, b.block_quality_score,
           b.top_stealer_kind, b.interruption_count, b.status
    FROM public.founder_deep_work_blocks_r2537 b
    WHERE b.status = 'done'
    ORDER BY b.block_quality_score DESC, b.hours_actual DESC
    LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_quality_days_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_quality_days_r2537() TO authenticated;

CREATE OR REPLACE FUNCTION public.device_success_rate_r2537()
RETURNS TABLE (device_kind text, success_count int, failure_count int,
               success_rate numeric, status text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.device_kind, d.success_count, d.failure_count,
           CASE WHEN (d.success_count + d.failure_count) > 0
                THEN round((d.success_count::numeric * 100) / (d.success_count + d.failure_count), 2)
                ELSE 0::numeric END AS success_rate,
           d.status
    FROM public.deep_work_commitment_devices_r2537 d
    ORDER BY (CASE WHEN (d.success_count + d.failure_count) > 0
                   THEN (d.success_count::numeric * 100) / (d.success_count + d.failure_count)
                   ELSE 0::numeric END) DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.device_success_rate_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.device_success_rate_r2537() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_summary_r2537()
RETURNS TABLE (total_blocks bigint, done_count bigint, missed_count bigint,
               total_hours_planned numeric, total_hours_actual numeric,
               avg_quality numeric, total_interruptions bigint,
               active_devices bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT count(*)::bigint FROM public.founder_deep_work_blocks_r2537),
      (SELECT count(*)::bigint FROM public.founder_deep_work_blocks_r2537 WHERE status = 'done'),
      (SELECT count(*)::bigint FROM public.founder_deep_work_blocks_r2537 WHERE status = 'missed'),
      (SELECT round(sum(hours_planned)::numeric, 2) FROM public.founder_deep_work_blocks_r2537),
      (SELECT round(sum(hours_actual)::numeric, 2) FROM public.founder_deep_work_blocks_r2537),
      (SELECT round(avg(block_quality_score)::numeric, 2) FROM public.founder_deep_work_blocks_r2537),
      (SELECT sum(interruption_count)::bigint FROM public.founder_deep_work_blocks_r2537),
      (SELECT count(*)::bigint FROM public.deep_work_commitment_devices_r2537 WHERE status = 'active');
END;$$;
REVOKE EXECUTE ON FUNCTION public.monthly_summary_r2537() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_summary_r2537() TO authenticated;

