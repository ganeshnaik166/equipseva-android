-- Round 2538: engineer-fatigue-rest-cycle-alignment
-- Tables: engineer_fatigue_cycles_r2538, fatigue_block_actions_r2538
-- RPCs: list_fatigue_cycles_r2538, list_block_actions_r2538, top_fatigued_engineers_r2538,
--       status_distribution_r2538, peer_share_summary_r2538, weekly_fatigue_trend_r2538,
--       auto_block_rate_r2538

BEGIN;

CREATE TABLE IF NOT EXISTS public.engineer_fatigue_cycles_r2538 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  week_start date NOT NULL,
  work_hours numeric(5,2) NOT NULL DEFAULT 0,
  rest_days int NOT NULL DEFAULT 0,
  fatigue_score int NOT NULL DEFAULT 0 CHECK (fatigue_score BETWEEN 0 AND 100),
  consent_for_extra_hours boolean NOT NULL DEFAULT false,
  auto_blocked boolean NOT NULL DEFAULT false,
  peer_share_pct numeric(5,2) NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'green' CHECK (status IN ('green','amber','red','black')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.fatigue_block_actions_r2538 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cycle_id uuid REFERENCES public.engineer_fatigue_cycles_r2538(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL DEFAULT now(),
  action_kind text NOT NULL CHECK (action_kind IN ('load_reduce','mandatory_rest','buddy_pair','escalation','coaching')),
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_fatigue_cycles_r2538 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fatigue_block_actions_r2538 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_fatigue_cycles_r2538;
CREATE POLICY founder_all ON public.engineer_fatigue_cycles_r2538
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.fatigue_block_actions_r2538;
CREATE POLICY founder_all ON public.fatigue_block_actions_r2538
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed fatigue cycles
DO $seed$
DECLARE
  c1_id uuid;
  c2_id uuid;
  c3_id uuid;
  c4_id uuid;
  c5_id uuid;
BEGIN
  INSERT INTO public.engineer_fatigue_cycles_r2538
    (week_start, work_hours, rest_days, fatigue_score, consent_for_extra_hours,
     auto_blocked, peer_share_pct, owner_email, status, notes)
  VALUES ('2026-06-01'::date, 48.0, 2, 35, true, false, 12.0, 'ops@equipseva.in', 'green',
          'baseline week - load normal')
  RETURNING id INTO c1_id;

  INSERT INTO public.engineer_fatigue_cycles_r2538
    (week_start, work_hours, rest_days, fatigue_score, consent_for_extra_hours,
     auto_blocked, peer_share_pct, owner_email, status, notes)
  VALUES ('2026-06-08'::date, 56.0, 1, 58, true, false, 18.5, 'ops@equipseva.in', 'amber',
          'extra hours consented - heavy AMC week')
  RETURNING id INTO c2_id;

  INSERT INTO public.engineer_fatigue_cycles_r2538
    (week_start, work_hours, rest_days, fatigue_score, consent_for_extra_hours,
     auto_blocked, peer_share_pct, owner_email, status, notes)
  VALUES ('2026-06-15'::date, 64.0, 0, 78, false, true, 22.0, 'ops@equipseva.in', 'red',
          'auto-blocked - no rest day taken')
  RETURNING id INTO c3_id;

  INSERT INTO public.engineer_fatigue_cycles_r2538
    (week_start, work_hours, rest_days, fatigue_score, consent_for_extra_hours,
     auto_blocked, peer_share_pct, owner_email, status, notes)
  VALUES ('2026-06-15'::date, 38.0, 2, 28, false, false, 8.5, 'ops@equipseva.in', 'green',
          'healthy load - peer share low')
  RETURNING id INTO c4_id;

  INSERT INTO public.engineer_fatigue_cycles_r2538
    (week_start, work_hours, rest_days, fatigue_score, consent_for_extra_hours,
     auto_blocked, peer_share_pct, owner_email, status, notes)
  VALUES ('2026-06-22'::date, 72.0, 0, 92, false, true, 28.0, 'ops@equipseva.in', 'black',
          'critical - escalation pending')
  RETURNING id INTO c5_id;

  INSERT INTO public.fatigue_block_actions_r2538
    (cycle_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (c2_id, '2026-06-10 10:00:00'::timestamptz, 'load_reduce', 'positive',
          'ops@equipseva.in', 'done', 'reassigned 2 jobs to buddy');

  INSERT INTO public.fatigue_block_actions_r2538
    (cycle_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (c3_id, '2026-06-17 09:00:00'::timestamptz, 'mandatory_rest', 'positive',
          'ops@equipseva.in', 'done', '2 day forced rest applied');

  INSERT INTO public.fatigue_block_actions_r2538
    (cycle_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (c3_id, '2026-06-18 14:00:00'::timestamptz, 'buddy_pair', 'neutral',
          'ops@equipseva.in', 'done', 'paired with senior tier engineer');

  INSERT INTO public.fatigue_block_actions_r2538
    (cycle_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (c5_id, '2026-06-23 08:00:00'::timestamptz, 'escalation', 'pending',
          'founder@equipseva.in', 'open', 'founder review needed - severe burnout signs');

  INSERT INTO public.fatigue_block_actions_r2538
    (cycle_id, action_at, action_kind, outcome, owner_email, status, notes)
  VALUES (c5_id, '2026-06-23 11:00:00'::timestamptz, 'coaching', 'pending',
          'ops@equipseva.in', 'open', '1:1 with engineer scheduled');
END;
$seed$;

-- RPC 1: list_fatigue_cycles_r2538
CREATE OR REPLACE FUNCTION public.list_fatigue_cycles_r2538()
RETURNS TABLE (id uuid, engineer_user_id uuid, week_start date, work_hours numeric,
               rest_days int, fatigue_score int, consent_for_extra_hours boolean,
               auto_blocked boolean, peer_share_pct numeric, owner_email text,
               status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.engineer_user_id, c.week_start, c.work_hours, c.rest_days,
           c.fatigue_score, c.consent_for_extra_hours, c.auto_blocked,
           c.peer_share_pct, c.owner_email, c.status, c.notes
    FROM public.engineer_fatigue_cycles_r2538 c
    ORDER BY c.week_start DESC, c.fatigue_score DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_fatigue_cycles_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_fatigue_cycles_r2538() TO authenticated;

-- RPC 2: list_block_actions_r2538
CREATE OR REPLACE FUNCTION public.list_block_actions_r2538()
RETURNS TABLE (id uuid, cycle_id uuid, action_at timestamptz, action_kind text,
               outcome text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.cycle_id, a.action_at, a.action_kind,
           a.outcome, a.owner_email, a.status, a.notes
    FROM public.fatigue_block_actions_r2538 a
    ORDER BY a.action_at DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.list_block_actions_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_block_actions_r2538() TO authenticated;

-- RPC 3: top_fatigued_engineers_r2538
CREATE OR REPLACE FUNCTION public.top_fatigued_engineers_r2538()
RETURNS TABLE (engineer_user_id uuid, week_start date, fatigue_score int,
               work_hours numeric, rest_days int, status text, auto_blocked boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.engineer_user_id, c.week_start, c.fatigue_score,
           c.work_hours, c.rest_days, c.status, c.auto_blocked
    FROM public.engineer_fatigue_cycles_r2538 c
    ORDER BY c.fatigue_score DESC, c.week_start DESC
    LIMIT 10;
END;$$;
REVOKE EXECUTE ON FUNCTION public.top_fatigued_engineers_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_fatigued_engineers_r2538() TO authenticated;

-- RPC 4: status_distribution_r2538
CREATE OR REPLACE FUNCTION public.status_distribution_r2538()
RETURNS TABLE (status text, cycles_count bigint, avg_fatigue numeric,
               avg_work_hours numeric, auto_blocked_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.status,
           COUNT(*)::bigint AS cycles_count,
           ROUND(AVG(c.fatigue_score)::numeric, 2) AS avg_fatigue,
           ROUND(AVG(c.work_hours)::numeric, 2) AS avg_work_hours,
           SUM(CASE WHEN c.auto_blocked THEN 1 ELSE 0 END)::bigint AS auto_blocked_count
    FROM public.engineer_fatigue_cycles_r2538 c
    GROUP BY c.status
    ORDER BY avg_fatigue DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.status_distribution_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_distribution_r2538() TO authenticated;

-- RPC 5: peer_share_summary_r2538
CREATE OR REPLACE FUNCTION public.peer_share_summary_r2538()
RETURNS TABLE (week_start date, cycles_count bigint, avg_peer_share numeric,
               max_peer_share numeric, total_work_hours numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.week_start,
           COUNT(*)::bigint AS cycles_count,
           ROUND(AVG(c.peer_share_pct)::numeric, 2) AS avg_peer_share,
           ROUND(MAX(c.peer_share_pct)::numeric, 2) AS max_peer_share,
           ROUND(SUM(c.work_hours)::numeric, 2) AS total_work_hours
    FROM public.engineer_fatigue_cycles_r2538 c
    GROUP BY c.week_start
    ORDER BY c.week_start DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.peer_share_summary_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.peer_share_summary_r2538() TO authenticated;

-- RPC 6: weekly_fatigue_trend_r2538
CREATE OR REPLACE FUNCTION public.weekly_fatigue_trend_r2538()
RETURNS TABLE (week_start date, cycles_count bigint, avg_fatigue numeric,
               total_work_hours numeric, total_rest_days bigint, red_or_black_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.week_start,
           COUNT(*)::bigint AS cycles_count,
           ROUND(AVG(c.fatigue_score)::numeric, 2) AS avg_fatigue,
           ROUND(SUM(c.work_hours)::numeric, 2) AS total_work_hours,
           SUM(c.rest_days)::bigint AS total_rest_days,
           SUM(CASE WHEN c.status IN ('red','black') THEN 1 ELSE 0 END)::bigint AS red_or_black_count
    FROM public.engineer_fatigue_cycles_r2538 c
    GROUP BY c.week_start
    ORDER BY c.week_start DESC;
END;$$;
REVOKE EXECUTE ON FUNCTION public.weekly_fatigue_trend_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_fatigue_trend_r2538() TO authenticated;

-- RPC 7: auto_block_rate_r2538
CREATE OR REPLACE FUNCTION public.auto_block_rate_r2538()
RETURNS TABLE (total_cycles bigint, auto_blocked_count bigint, auto_block_rate numeric,
               consented_count bigint, consent_rate numeric, avg_fatigue_overall numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT COUNT(*)::bigint AS total_cycles,
           SUM(CASE WHEN c.auto_blocked THEN 1 ELSE 0 END)::bigint AS auto_blocked_count,
           CASE WHEN COUNT(*) > 0
                THEN ROUND((SUM(CASE WHEN c.auto_blocked THEN 1 ELSE 0 END)::numeric / COUNT(*)::numeric) * 100, 2)
                ELSE 0::numeric END AS auto_block_rate,
           SUM(CASE WHEN c.consent_for_extra_hours THEN 1 ELSE 0 END)::bigint AS consented_count,
           CASE WHEN COUNT(*) > 0
                THEN ROUND((SUM(CASE WHEN c.consent_for_extra_hours THEN 1 ELSE 0 END)::numeric / COUNT(*)::numeric) * 100, 2)
                ELSE 0::numeric END AS consent_rate,
           ROUND(AVG(c.fatigue_score)::numeric, 2) AS avg_fatigue_overall
    FROM public.engineer_fatigue_cycles_r2538 c;
END;$$;
REVOKE EXECUTE ON FUNCTION public.auto_block_rate_r2538() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.auto_block_rate_r2538() TO authenticated;

