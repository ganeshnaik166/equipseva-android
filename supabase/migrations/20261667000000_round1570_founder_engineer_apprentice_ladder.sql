BEGIN;

-- =========================================================================
-- Round 1570 — Founder Engineer Apprentice Ladder
-- Apprentices learn under masters across a 6-month curriculum.
-- Founder-only oversight of per-pair progress + graduation gating.
-- =========================================================================

-- -------------------------------------------------------------------------
-- Table 1: apprentice_pairings_v2
--   one row per (apprentice_engineer_id, master_engineer_id) pair
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.apprentice_pairings_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  apprentice_engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  master_engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  curriculum_started_at timestamptz NOT NULL DEFAULT now(),
  curriculum_target_end_at timestamptz NOT NULL DEFAULT (now() + interval '180 days'),
  curriculum_actual_end_at timestamptz,
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','paused','graduated','dropped')),
  jobs_shadowed integer NOT NULL DEFAULT 0,
  jobs_assisted integer NOT NULL DEFAULT 0,
  jobs_solo integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT apprentice_pairings_v2_distinct CHECK (apprentice_engineer_id <> master_engineer_id)
);

CREATE INDEX IF NOT EXISTS apprentice_pairings_v2_apprentice_idx
  ON public.apprentice_pairings_v2 (apprentice_engineer_id);
CREATE INDEX IF NOT EXISTS apprentice_pairings_v2_master_idx
  ON public.apprentice_pairings_v2 (master_engineer_id);
CREATE INDEX IF NOT EXISTS apprentice_pairings_v2_status_idx
  ON public.apprentice_pairings_v2 (status);

ALTER TABLE public.apprentice_pairings_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS apprentice_pairings_v2_founder_all ON public.apprentice_pairings_v2;
CREATE POLICY apprentice_pairings_v2_founder_all
  ON public.apprentice_pairings_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -------------------------------------------------------------------------
-- Table 2: apprentice_milestones_v2
--   one row per (pairing, milestone_code)
-- -------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.apprentice_milestones_v2 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pairing_id uuid NOT NULL REFERENCES public.apprentice_pairings_v2(id) ON DELETE CASCADE,
  milestone_code text NOT NULL
    CHECK (milestone_code IN (
      'safety_orientation','tools_inventory','first_shadow','first_assist',
      'first_solo','hospital_etiquette','escalation_protocol','parts_handling',
      'invoice_workflow','final_eval'
    )),
  target_week integer NOT NULL CHECK (target_week BETWEEN 1 AND 26),
  completed_at timestamptz,
  master_signoff boolean NOT NULL DEFAULT false,
  founder_signoff boolean NOT NULL DEFAULT false,
  score_pct numeric(5,2),
  evidence_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pairing_id, milestone_code)
);

CREATE INDEX IF NOT EXISTS apprentice_milestones_v2_pairing_idx
  ON public.apprentice_milestones_v2 (pairing_id);
CREATE INDEX IF NOT EXISTS apprentice_milestones_v2_completed_idx
  ON public.apprentice_milestones_v2 (completed_at);

ALTER TABLE public.apprentice_milestones_v2 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS apprentice_milestones_v2_founder_all ON public.apprentice_milestones_v2;
CREATE POLICY apprentice_milestones_v2_founder_all
  ON public.apprentice_milestones_v2
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- SECDEF RPCs — 7 reads (STABLE) + writes (VOLATILE)
-- =========================================================================

-- ---- RPC 1: list active pairings -----------------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_pairings_list();
CREATE OR REPLACE FUNCTION public.founder_apprentice_pairings_list()
RETURNS TABLE (
  id uuid,
  apprentice_engineer_id uuid,
  apprentice_name text,
  master_engineer_id uuid,
  master_name text,
  status text,
  started_at timestamptz,
  target_end_at timestamptz,
  days_elapsed numeric,
  days_remaining numeric,
  jobs_shadowed integer,
  jobs_assisted integer,
  jobs_solo integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    p.apprentice_engineer_id,
    COALESCE(ap.full_name, ap.email) AS apprentice_name,
    p.master_engineer_id,
    COALESCE(mp.full_name, mp.email) AS master_name,
    p.status,
    p.curriculum_started_at,
    p.curriculum_target_end_at,
    EXTRACT(EPOCH FROM (now() - p.curriculum_started_at))/86400.0 AS days_elapsed,
    EXTRACT(EPOCH FROM (p.curriculum_target_end_at - now()))/86400.0 AS days_remaining,
    p.jobs_shadowed, p.jobs_assisted, p.jobs_solo
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers ae ON ae.id = p.apprentice_engineer_id
  LEFT JOIN profiles  ap ON ap.id = ae.user_id
  LEFT JOIN engineers me ON me.id = p.master_engineer_id
  LEFT JOIN profiles  mp ON mp.id = me.user_id
  ORDER BY p.curriculum_started_at DESC
  LIMIT 200;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_pairings_list() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_pairings_list() TO authenticated;

-- ---- RPC 2: milestone progress per pairing -------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_milestones_for_pair(uuid);
CREATE OR REPLACE FUNCTION public.founder_apprentice_milestones_for_pair(p_pairing_id uuid)
RETURNS TABLE (
  milestone_code text,
  target_week integer,
  completed_at timestamptz,
  master_signoff boolean,
  founder_signoff boolean,
  score_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.milestone_code, m.target_week, m.completed_at,
         m.master_signoff, m.founder_signoff, m.score_pct
  FROM apprentice_milestones_v2 m
  WHERE m.pairing_id = p_pairing_id
  ORDER BY m.target_week;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_milestones_for_pair(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_milestones_for_pair(uuid) TO authenticated;

-- ---- RPC 3: aggregate KPIs -----------------------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_kpis();
CREATE OR REPLACE FUNCTION public.founder_apprentice_kpis()
RETURNS TABLE (
  total_pairings integer,
  active_pairings integer,
  paused_pairings integer,
  graduated_pairings integer,
  dropped_pairings integer,
  unique_masters integer,
  unique_apprentices integer,
  avg_days_in_program numeric,
  avg_days_to_graduate numeric,
  total_jobs_shadowed integer,
  total_jobs_assisted integer,
  total_jobs_solo integer,
  milestones_completed integer,
  milestones_pending integer,
  pct_milestones_complete numeric,
  overdue_pairings integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH p AS (SELECT * FROM apprentice_pairings_v2),
       m AS (SELECT * FROM apprentice_milestones_v2)
  SELECT
    (SELECT COUNT(*)::int FROM p),
    (SELECT COUNT(*)::int FROM p WHERE status='active'),
    (SELECT COUNT(*)::int FROM p WHERE status='paused'),
    (SELECT COUNT(*)::int FROM p WHERE status='graduated'),
    (SELECT COUNT(*)::int FROM p WHERE status='dropped'),
    (SELECT COUNT(DISTINCT master_engineer_id)::int FROM p),
    (SELECT COUNT(DISTINCT apprentice_engineer_id)::int FROM p),
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (now() - curriculum_started_at))/86400.0)::numeric, 1) FROM p WHERE status='active'),
    (SELECT ROUND(AVG(EXTRACT(EPOCH FROM (curriculum_actual_end_at - curriculum_started_at))/86400.0)::numeric, 1) FROM p WHERE status='graduated' AND curriculum_actual_end_at IS NOT NULL),
    (SELECT COALESCE(SUM(jobs_shadowed),0)::int FROM p),
    (SELECT COALESCE(SUM(jobs_assisted),0)::int FROM p),
    (SELECT COALESCE(SUM(jobs_solo),0)::int FROM p),
    (SELECT COUNT(*)::int FROM m WHERE completed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM m WHERE completed_at IS NULL),
    (SELECT CASE WHEN COUNT(*)=0 THEN 0
            ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE completed_at IS NOT NULL) / COUNT(*)::numeric, 1)
         END FROM m),
    (SELECT COUNT(*)::int FROM p WHERE status='active' AND curriculum_target_end_at < now());
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_kpis() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_kpis() TO authenticated;

-- ---- RPC 4: master scoreboard --------------------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_masters_scoreboard();
CREATE OR REPLACE FUNCTION public.founder_apprentice_masters_scoreboard()
RETURNS TABLE (
  master_engineer_id uuid,
  master_name text,
  active_apprentices integer,
  graduated_apprentices integer,
  total_jobs_with_apprentice integer,
  avg_milestone_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.master_engineer_id,
    COALESCE(pr.full_name, pr.email) AS master_name,
    COUNT(*) FILTER (WHERE p.status='active')::int,
    COUNT(*) FILTER (WHERE p.status='graduated')::int,
    COALESCE(SUM(p.jobs_shadowed + p.jobs_assisted + p.jobs_solo),0)::int,
    ROUND(AVG(
      (SELECT CASE WHEN COUNT(*)=0 THEN 0
              ELSE 100.0 * COUNT(*) FILTER (WHERE completed_at IS NOT NULL) / COUNT(*)::numeric END
       FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id)
    )::numeric, 1)
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers e ON e.id = p.master_engineer_id
  LEFT JOIN profiles  pr ON pr.id = e.user_id
  GROUP BY p.master_engineer_id, pr.full_name, pr.email
  ORDER BY active_apprentices DESC NULLS LAST
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_masters_scoreboard() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_masters_scoreboard() TO authenticated;

-- ---- RPC 5: graduation candidates ----------------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_grad_candidates();
CREATE OR REPLACE FUNCTION public.founder_apprentice_grad_candidates()
RETURNS TABLE (
  pairing_id uuid,
  apprentice_name text,
  master_name text,
  days_in_program numeric,
  milestones_done integer,
  milestones_total integer,
  jobs_solo integer,
  ready boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    COALESCE(ap.full_name, ap.email),
    COALESCE(mp.full_name, mp.email),
    EXTRACT(EPOCH FROM (now() - p.curriculum_started_at))/86400.0,
    (SELECT COUNT(*)::int FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id AND m.completed_at IS NOT NULL),
    (SELECT COUNT(*)::int FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id),
    p.jobs_solo,
    (
      EXTRACT(EPOCH FROM (now() - p.curriculum_started_at))/86400.0 >= 150
      AND p.jobs_solo >= 5
      AND (SELECT COUNT(*) FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id AND m.completed_at IS NULL) = 0
    )
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers ae ON ae.id = p.apprentice_engineer_id
  LEFT JOIN profiles  ap ON ap.id = ae.user_id
  LEFT JOIN engineers me ON me.id = p.master_engineer_id
  LEFT JOIN profiles  mp ON mp.id = me.user_id
  WHERE p.status='active'
  ORDER BY days_in_program DESC
  LIMIT 100;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_grad_candidates() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_grad_candidates() TO authenticated;

-- ---- RPC 6: weekly cohort funnel -----------------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_weekly_funnel();
CREATE OR REPLACE FUNCTION public.founder_apprentice_weekly_funnel()
RETURNS TABLE (
  week_start date,
  started integer,
  graduated integer,
  dropped integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH weeks AS (
    SELECT generate_series(date_trunc('week', now())::date - interval '11 weeks',
                           date_trunc('week', now())::date, interval '1 week')::date AS wk
  )
  SELECT
    w.wk,
    (SELECT COUNT(*)::int FROM apprentice_pairings_v2 p
      WHERE date_trunc('week', p.curriculum_started_at)::date = w.wk),
    (SELECT COUNT(*)::int FROM apprentice_pairings_v2 p
      WHERE p.status='graduated' AND date_trunc('week', p.curriculum_actual_end_at)::date = w.wk),
    (SELECT COUNT(*)::int FROM apprentice_pairings_v2 p
      WHERE p.status='dropped' AND date_trunc('week', p.updated_at)::date = w.wk)
  FROM weeks w
  ORDER BY w.wk;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_weekly_funnel() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_weekly_funnel() TO authenticated;

-- ---- RPC 7: overdue pairings ---------------------------------------------
DROP FUNCTION IF EXISTS public.founder_apprentice_overdue();
CREATE OR REPLACE FUNCTION public.founder_apprentice_overdue()
RETURNS TABLE (
  pairing_id uuid,
  apprentice_name text,
  master_name text,
  days_overdue numeric,
  pending_milestones integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    p.id,
    COALESCE(ap.full_name, ap.email),
    COALESCE(mp.full_name, mp.email),
    EXTRACT(EPOCH FROM (now() - p.curriculum_target_end_at))/86400.0,
    (SELECT COUNT(*)::int FROM apprentice_milestones_v2 m WHERE m.pairing_id = p.id AND m.completed_at IS NULL)
  FROM apprentice_pairings_v2 p
  LEFT JOIN engineers ae ON ae.id = p.apprentice_engineer_id
  LEFT JOIN profiles  ap ON ap.id = ae.user_id
  LEFT JOIN engineers me ON me.id = p.master_engineer_id
  LEFT JOIN profiles  mp ON mp.id = me.user_id
  WHERE p.status='active' AND p.curriculum_target_end_at < now()
  ORDER BY days_overdue DESC
  LIMIT 50;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_apprentice_overdue() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_apprentice_overdue() TO authenticated;

-- =========================================================================
-- log_founder_* helpers (VOLATILE SECDEF) — write-side audit shims
-- =========================================================================

DROP FUNCTION IF EXISTS public.log_founder_apprentice_pair_create(uuid, uuid);
CREATE OR REPLACE FUNCTION public.log_founder_apprentice_pair_create(
  p_apprentice_engineer_id uuid,
  p_master_engineer_id uuid
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO apprentice_pairings_v2 (apprentice_engineer_id, master_engineer_id)
  VALUES (p_apprentice_engineer_id, p_master_engineer_id)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'apprentice_pair_create',
          jsonb_build_object('pairing_id', v_id,
                             'apprentice', p_apprentice_engineer_id,
                             'master', p_master_engineer_id));
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_apprentice_pair_create(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_apprentice_pair_create(uuid, uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_apprentice_milestone_complete(uuid, text, numeric);
CREATE OR REPLACE FUNCTION public.log_founder_apprentice_milestone_complete(
  p_pairing_id uuid,
  p_milestone_code text,
  p_score_pct numeric
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE apprentice_milestones_v2
     SET completed_at = COALESCE(completed_at, now()),
         founder_signoff = true,
         score_pct = p_score_pct,
         updated_at = now()
   WHERE pairing_id = p_pairing_id AND milestone_code = p_milestone_code;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'apprentice_milestone_complete',
          jsonb_build_object('pairing_id', p_pairing_id,
                             'milestone', p_milestone_code,
                             'score_pct', p_score_pct));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_apprentice_milestone_complete(uuid, text, numeric) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_apprentice_milestone_complete(uuid, text, numeric) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_apprentice_graduate(uuid);
CREATE OR REPLACE FUNCTION public.log_founder_apprentice_graduate(p_pairing_id uuid)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE apprentice_pairings_v2
     SET status = 'graduated',
         curriculum_actual_end_at = now(),
         updated_at = now()
   WHERE id = p_pairing_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'apprentice_graduate',
          jsonb_build_object('pairing_id', p_pairing_id, 'graduated_at', now()));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_apprentice_graduate(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_apprentice_graduate(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_apprentice_drop(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_apprentice_drop(p_pairing_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE apprentice_pairings_v2
     SET status = 'dropped',
         notes = COALESCE(notes,'') || E'\nDROPPED: ' || COALESCE(p_reason,'(no reason)'),
         updated_at = now()
   WHERE id = p_pairing_id;

  INSERT INTO founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'apprentice_drop',
          jsonb_build_object('pairing_id', p_pairing_id, 'reason', p_reason));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_apprentice_drop(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_apprentice_drop(uuid, text) TO authenticated;

COMMIT;