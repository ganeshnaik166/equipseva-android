-- Round 2443: Hospital Chain Onboarding Runway Tracker
-- Tracks multi-site hospital chain onboarding ramp tasks across stages
-- (legal -> training -> equipment_audit -> integration -> go_live) and
-- the ARR-at-stake of chains stuck mid-ramp.

CREATE TABLE IF NOT EXISTS public.chain_onboarding_tasks_r2443 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ramp_stage text NOT NULL
    CHECK (ramp_stage IN ('legal','training','equipment_audit','integration','go_live')),
  task_name text NOT NULL,
  owner_email text,
  due_at timestamptz,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','blocked','done','dropped')),
  blocker_kind text NOT NULL DEFAULT 'none'
    CHECK (blocker_kind IN ('none','legal','integration','training','equipment','other')),
  blocker_notes text,
  notes text
);

CREATE TABLE IF NOT EXISTS public.chain_onboarding_arr_at_stake_r2443 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  snapshot_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Kolkata')::date,
  current_ramp_stage text NOT NULL
    CHECK (current_ramp_stage IN ('legal','training','equipment_audit','integration','go_live')),
  days_in_ramp int NOT NULL DEFAULT 0 CHECK (days_in_ramp >= 0),
  expected_arr_rupees bigint NOT NULL DEFAULT 0 CHECK (expected_arr_rupees >= 0),
  blocked_tasks_count int NOT NULL DEFAULT 0 CHECK (blocked_tasks_count >= 0),
  on_track boolean NOT NULL DEFAULT true,
  top_blocker_notes text,
  owner_email text,
  notes text
);

CREATE INDEX IF NOT EXISTS idx_cot_r2443_chain ON public.chain_onboarding_tasks_r2443(chain_name);
CREATE INDEX IF NOT EXISTS idx_cot_r2443_status ON public.chain_onboarding_tasks_r2443(status);
CREATE INDEX IF NOT EXISTS idx_cot_r2443_stage ON public.chain_onboarding_tasks_r2443(ramp_stage);
CREATE INDEX IF NOT EXISTS idx_cot_r2443_due ON public.chain_onboarding_tasks_r2443(due_at);
CREATE INDEX IF NOT EXISTS idx_caas_r2443_chain ON public.chain_onboarding_arr_at_stake_r2443(chain_name);
CREATE INDEX IF NOT EXISTS idx_caas_r2443_snapshot ON public.chain_onboarding_arr_at_stake_r2443(snapshot_date);

ALTER TABLE public.chain_onboarding_tasks_r2443 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chain_onboarding_arr_at_stake_r2443 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_onboarding_tasks_r2443;
CREATE POLICY founder_all ON public.chain_onboarding_tasks_r2443
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.chain_onboarding_arr_at_stake_r2443;
CREATE POLICY founder_all ON public.chain_onboarding_arr_at_stake_r2443
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed tasks: 5 rows spanning the ramp stages with mixed statuses + blockers
INSERT INTO public.chain_onboarding_tasks_r2443
  (chain_name, ramp_stage, task_name, owner_email, due_at, status, blocker_kind, blocker_notes, notes)
VALUES
  ('Apollo Andhra', 'legal', 'Master services agreement countersign',
    'legal@equipseva.in', '2026-06-15 17:00:00+05:30'::timestamptz,
    'blocked', 'legal',
    'Chain CFO wants indemnity cap raised from 1x to 3x annual fees',
    'Pushed to founder + lawyer; need decision by Jun 22'),
  ('Apollo Andhra', 'training', 'Engineer onboarding workshop (Vizag)',
    'ops@equipseva.in', '2026-06-28 10:00:00+05:30'::timestamptz,
    'open', 'none', null,
    '12 engineers expected; cap at 15'),
  ('Yashoda Hyd', 'equipment_audit', 'Equipment inventory walk-through (5 sites)',
    'fieldops@equipseva.in', '2026-06-18 17:00:00+05:30'::timestamptz,
    'in_progress', 'none', null,
    '3 of 5 sites done; 2 pending due to OT schedule conflicts'),
  ('Yashoda Hyd', 'integration', 'HMS API integration spec sign-off',
    'tech@equipseva.in', '2026-06-25 17:00:00+05:30'::timestamptz,
    'blocked', 'integration',
    'Chain runs custom HMS; needs 4-week dev effort on our side',
    'Engineering capacity tight; may slip go-live by 3 weeks'),
  ('Care Hospitals', 'go_live', 'Soft launch at flagship (Banjara Hills)',
    'founder@equipseva.in', '2026-06-30 09:00:00+05:30'::timestamptz,
    'open', 'none', null,
    'Marketing assets ready; engineer rotation locked');

-- Seed ARR-at-stake snapshots: 4 rows for 4 chains
INSERT INTO public.chain_onboarding_arr_at_stake_r2443
  (chain_name, snapshot_date, current_ramp_stage, days_in_ramp,
   expected_arr_rupees, blocked_tasks_count, on_track, top_blocker_notes,
   owner_email, notes)
VALUES
  ('Apollo Andhra', '2026-06-22'::date, 'legal', 47,
    7200000, 1, false,
    'MSA indemnity cap negotiation stuck 3 weeks',
    'founder@equipseva.in',
    '12 sites; ₹60K/site/month AMC tier 2'),
  ('Yashoda Hyd', '2026-06-22'::date, 'integration', 31,
    5400000, 1, false,
    'Custom HMS API integration — 4-week dev capacity needed',
    'tech@equipseva.in',
    '9 sites; ₹50K/site/month AMC tier 1'),
  ('Care Hospitals', '2026-06-22'::date, 'go_live', 18,
    4800000, 0, true,
    null,
    'founder@equipseva.in',
    '8 sites; on track for Jun 30 soft launch'),
  ('KIMS Secunderabad', '2026-06-22'::date, 'training', 9,
    3600000, 0, true,
    null,
    'ops@equipseva.in',
    '6 sites; workshop scheduled Jun 26');

-- RPC: list all onboarding tasks
CREATE OR REPLACE FUNCTION public.list_tasks_r2443()
RETURNS TABLE (
  id uuid,
  chain_name text,
  ramp_stage text,
  task_name text,
  owner_email text,
  due_at timestamptz,
  status text,
  blocker_kind text,
  blocker_notes text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.id, t.chain_name, t.ramp_stage, t.task_name, t.owner_email,
         t.due_at, t.status, t.blocker_kind, t.blocker_notes, t.notes, t.created_at
  FROM public.chain_onboarding_tasks_r2443 t
  ORDER BY
    CASE t.status
      WHEN 'blocked' THEN 1
      WHEN 'in_progress' THEN 2
      WHEN 'open' THEN 3
      WHEN 'done' THEN 4
      WHEN 'dropped' THEN 5
    END,
    t.due_at NULLS LAST,
    t.created_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_tasks_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_tasks_r2443() TO authenticated;

-- RPC: list ARR-at-stake snapshots
CREATE OR REPLACE FUNCTION public.list_arr_at_stake_r2443()
RETURNS TABLE (
  id uuid,
  chain_name text,
  snapshot_date date,
  current_ramp_stage text,
  days_in_ramp int,
  expected_arr_rupees bigint,
  blocked_tasks_count int,
  on_track boolean,
  top_blocker_notes text,
  owner_email text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.snapshot_date, a.current_ramp_stage,
         a.days_in_ramp, a.expected_arr_rupees, a.blocked_tasks_count,
         a.on_track, a.top_blocker_notes, a.owner_email, a.notes
  FROM public.chain_onboarding_arr_at_stake_r2443 a
  ORDER BY a.on_track ASC, a.expected_arr_rupees DESC, a.days_in_ramp DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_arr_at_stake_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_arr_at_stake_r2443() TO authenticated;

-- RPC: how many tasks live in each ramp stage
CREATE OR REPLACE FUNCTION public.stage_distribution_r2443()
RETURNS TABLE (
  ramp_stage text,
  task_count bigint,
  blocked_count bigint,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.ramp_stage,
         COUNT(*)::bigint AS task_count,
         COUNT(*) FILTER (WHERE t.status = 'blocked')::bigint AS blocked_count,
         COUNT(*) FILTER (WHERE t.status = 'done')::bigint AS done_count
  FROM public.chain_onboarding_tasks_r2443 t
  GROUP BY t.ramp_stage
  ORDER BY
    CASE t.ramp_stage
      WHEN 'legal' THEN 1
      WHEN 'training' THEN 2
      WHEN 'equipment_audit' THEN 3
      WHEN 'integration' THEN 4
      WHEN 'go_live' THEN 5
    END;
END $$;
REVOKE EXECUTE ON FUNCTION public.stage_distribution_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stage_distribution_r2443() TO authenticated;

-- RPC: chains stuck longest in ramp ordered by ARR at risk
CREATE OR REPLACE FUNCTION public.top_stuck_chains_r2443()
RETURNS TABLE (
  chain_name text,
  current_ramp_stage text,
  days_in_ramp int,
  expected_arr_rupees bigint,
  blocked_tasks_count int,
  on_track boolean,
  top_blocker_notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.chain_name, a.current_ramp_stage, a.days_in_ramp,
         a.expected_arr_rupees, a.blocked_tasks_count, a.on_track,
         a.top_blocker_notes
  FROM public.chain_onboarding_arr_at_stake_r2443 a
  WHERE a.on_track = false
  ORDER BY a.expected_arr_rupees DESC, a.days_in_ramp DESC
  LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_stuck_chains_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_stuck_chains_r2443() TO authenticated;

-- RPC: blocker breakdown across all tasks
CREATE OR REPLACE FUNCTION public.blocker_breakdown_r2443()
RETURNS TABLE (
  blocker_kind text,
  task_count bigint,
  blocked_arr_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT t.blocker_kind,
         COUNT(*)::bigint AS task_count,
         COALESCE(SUM(a.expected_arr_rupees), 0)::bigint AS blocked_arr_rupees
  FROM public.chain_onboarding_tasks_r2443 t
  LEFT JOIN public.chain_onboarding_arr_at_stake_r2443 a
    ON a.chain_name = t.chain_name
  WHERE t.status = 'blocked'
  GROUP BY t.blocker_kind
  ORDER BY task_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.blocker_breakdown_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.blocker_breakdown_r2443() TO authenticated;

-- RPC: owner load — how many tasks each owner has by status
CREATE OR REPLACE FUNCTION public.owner_load_r2443()
RETURNS TABLE (
  owner_email text,
  open_count bigint,
  in_progress_count bigint,
  blocked_count bigint,
  done_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT COALESCE(t.owner_email, '(unassigned)') AS owner_email,
         COUNT(*) FILTER (WHERE t.status = 'open')::bigint AS open_count,
         COUNT(*) FILTER (WHERE t.status = 'in_progress')::bigint AS in_progress_count,
         COUNT(*) FILTER (WHERE t.status = 'blocked')::bigint AS blocked_count,
         COUNT(*) FILTER (WHERE t.status = 'done')::bigint AS done_count
  FROM public.chain_onboarding_tasks_r2443 t
  GROUP BY COALESCE(t.owner_email, '(unassigned)')
  ORDER BY blocked_count DESC, open_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2443() TO authenticated;

-- RPC: weekly progress — tasks created vs done per week
CREATE OR REPLACE FUNCTION public.weekly_progress_r2443()
RETURNS TABLE (
  week_start date,
  created_count bigint,
  done_count bigint,
  blocked_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('week', t.created_at)::date AS week_start,
         COUNT(*)::bigint AS created_count,
         COUNT(*) FILTER (WHERE t.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE t.status = 'blocked')::bigint AS blocked_count
  FROM public.chain_onboarding_tasks_r2443 t
  GROUP BY date_trunc('week', t.created_at)::date
  ORDER BY week_start DESC
  LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.weekly_progress_r2443() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_progress_r2443() TO authenticated;
