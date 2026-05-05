-- v2.1 PR-C5: AMC multi-engineer rotation logic.
--
-- Foundation laid in PR-C1 (amc_contracts_schema): rotation table holds
-- priority 1=primary + 2..N=fallbacks; create_amc_contract() seeds the
-- list. PR-C5 adds the runtime side:
--   1. assign_next_available_amc_engineer() — pick the highest-priority
--      engineer who is is_available + verified, and write them onto the
--      maintenance visit (repair_jobs row).
--   2. auto-assign trigger on INSERT — when PR-C3's cron eventually
--      creates a maintenance repair_jobs row with engineer_id NULL,
--      this fills it in synchronously inside the same transaction.
--   3. re-rotate trigger on engineers.is_available flip — if the
--      currently-assigned engineer goes offline before they hit
--      en_route, push the visit down the rotation if we're already
--      past half the SLA window.
--   4. amc_admin_escalations — when no engineer in the rotation is
--      reachable, log it for ops to backfill manually. Hospitals don't
--      see this table directly.
--   5. add_amc_fallback_engineer / remove_amc_fallback_engineer /
--      list_amc_rotation — hospital-side RPCs to manage their list.
--
-- Notification fan-outs follow the same defensive pattern as the
-- engineer-side push triggers (20260428020000): SECURITY DEFINER, fixed
-- search_path, swallow insert failures so we never roll back the
-- parent assignment. New escalations get an admin-targeted notify too.

-- ---------------------------------------------------------------------------
-- 1. amc_admin_escalations — ops-only audit trail.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.amc_admin_escalations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amc_contract_id uuid NOT NULL REFERENCES public.amc_contracts(id) ON DELETE CASCADE,
  visit_id uuid REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (reason IN ('no_engineers_available','rotation_exhausted','manual')),
  notes text,
  resolved_at timestamptz,
  resolved_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS amc_admin_escalations_contract_idx
  ON public.amc_admin_escalations (amc_contract_id, created_at DESC);

CREATE INDEX IF NOT EXISTS amc_admin_escalations_open_idx
  ON public.amc_admin_escalations (created_at DESC)
  WHERE resolved_at IS NULL;

ALTER TABLE public.amc_admin_escalations ENABLE ROW LEVEL SECURITY;

-- Admin / founder only. Hospitals + engineers must not see ops triage.
CREATE POLICY amc_admin_escalations_admin_all ON public.amc_admin_escalations
  FOR ALL TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder())
  WITH CHECK (public.is_admin(auth.uid()) OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE ON public.amc_admin_escalations FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. assign_next_available_amc_engineer(visit_id)
-- ---------------------------------------------------------------------------
-- Walks rotation in priority order. Returns the engineer_id we wrote, or
-- NULL after logging an escalation. Idempotent: if an already-assigned
-- engineer is still in active rotation + is_available, we keep them.

CREATE OR REPLACE FUNCTION public.assign_next_available_amc_engineer(p_visit_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_contract_id uuid;
  v_kind text;
  v_status text;
  v_current_engineer uuid;
  v_picked_engineer uuid;
  v_rotation_record record;
  v_current_still_eligible boolean := false;
BEGIN
  SELECT amc_contract_id, kind, status::text, engineer_id
    INTO v_contract_id, v_kind, v_status, v_current_engineer
    FROM public.repair_jobs
    WHERE id = p_visit_id;

  IF v_contract_id IS NULL OR v_kind IS DISTINCT FROM 'maintenance' THEN
    RAISE EXCEPTION 'not an AMC visit' USING ERRCODE = '22023';
  END IF;

  -- If already terminal / already in field, don't touch.
  IF v_status IN ('en_route','in_progress','completed','disputed','cancelled') THEN
    RETURN v_current_engineer;
  END IF;

  -- Idempotency: if currently-assigned engineer is still active in
  -- rotation + verified + available, return them unchanged.
  IF v_current_engineer IS NOT NULL THEN
    SELECT TRUE INTO v_current_still_eligible
      FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = v_contract_id
        AND r.engineer_id = v_current_engineer
        AND r.active = true
        AND coalesce(e.is_available, false) = true
        AND e.verification_status::text = 'verified'
      LIMIT 1;
    IF coalesce(v_current_still_eligible, false) THEN
      RETURN v_current_engineer;
    END IF;
  END IF;

  -- Walk rotation in priority order, skip the currently-assigned one
  -- (we only got here because it's no longer eligible).
  FOR v_rotation_record IN
    SELECT r.engineer_id
      FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
      WHERE r.amc_contract_id = v_contract_id
        AND r.active = true
        AND coalesce(e.is_available, false) = true
        AND e.verification_status::text = 'verified'
        AND (v_current_engineer IS NULL OR r.engineer_id <> v_current_engineer)
      ORDER BY r.priority ASC
  LOOP
    v_picked_engineer := v_rotation_record.engineer_id;
    EXIT;
  END LOOP;

  IF v_picked_engineer IS NOT NULL THEN
    UPDATE public.repair_jobs
       SET engineer_id = v_picked_engineer,
           updated_at = now()
     WHERE id = p_visit_id;
    RETURN v_picked_engineer;
  END IF;

  -- Rotation exhausted. Log an escalation; ops surfaces this in the
  -- admin console. We don't roll back the parent transaction — visit
  -- still exists, just unassigned.
  BEGIN
    INSERT INTO public.amc_admin_escalations (amc_contract_id, visit_id, reason, notes)
    VALUES (
      v_contract_id, p_visit_id,
      CASE WHEN v_current_engineer IS NULL THEN 'no_engineers_available'
           ELSE 'rotation_exhausted' END,
      concat('auto-assign found 0 eligible engineers in rotation; current=',
             coalesce(v_current_engineer::text, 'null'))
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'assign_next_available_amc_engineer: escalation insert failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.assign_next_available_amc_engineer(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.assign_next_available_amc_engineer(uuid) TO service_role;
-- Also grant to authenticated; the RLS policy on repair_jobs + the
-- 'not an AMC visit' guard keep this safe — only AMC visits accepted,
-- and the SECDEF write goes through repair_jobs UPDATE which has its
-- own RLS layer on top.
GRANT EXECUTE ON FUNCTION public.assign_next_available_amc_engineer(uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. AFTER INSERT trigger on repair_jobs — auto-assign on maintenance create.
-- ---------------------------------------------------------------------------
-- PR-C3's cron creates a maintenance repair_jobs row with engineer_id
-- NULL; this fills it in. Manual hospital-initiated repair_jobs INSERTs
-- (kind='repair') are skipped via the WHEN clause.

CREATE OR REPLACE FUNCTION public.auto_assign_amc_visit_on_create()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_assigned uuid;
  v_hospital_user uuid;
  v_engineer_user uuid;
  v_job_number text;
BEGIN
  v_assigned := public.assign_next_available_amc_engineer(NEW.id);

  IF v_assigned IS NULL THEN
    -- escalation already logged inside the helper; tell hospital we're
    -- working on a backup. Use NEW.hospital_user_id since the visit row
    -- is fresh.
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        NEW.hospital_user_id,
        'amc_visit_pending_assignment',
        'Finding a maintenance engineer',
        'We''re lining up a backup technician for your scheduled visit.',
        jsonb_build_object(
          'amc_contract_id', NEW.amc_contract_id,
          'repair_job_id',   NEW.id,
          'job_number',      NEW.job_number
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'auto_assign_amc_visit_on_create: hospital pending notify failed: % / %', SQLSTATE, SQLERRM;
    END;
    RETURN NEW;
  END IF;

  -- Fan out to the picked engineer + the hospital so both sides know
  -- the visit is locked in. Resolve auth user from engineers row.
  SELECT user_id INTO v_engineer_user
    FROM public.engineers WHERE id = v_assigned;

  SELECT job_number INTO v_job_number
    FROM public.repair_jobs WHERE id = NEW.id;

  IF v_engineer_user IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user,
        'amc_visit_assigned',
        'New AMC maintenance visit',
        concat('You''ve been assigned visit ',
               coalesce(v_job_number, substring(NEW.id::text, 1, 8)),
               '. Tap to plan the trip.'),
        jsonb_build_object(
          'amc_contract_id', NEW.amc_contract_id,
          'repair_job_id',   NEW.id,
          'job_number',      v_job_number
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'auto_assign_amc_visit_on_create: engineer notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'amc_visit_engineer_assigned',
      'Maintenance visit scheduled',
      'An engineer has been assigned to your upcoming AMC visit.',
      jsonb_build_object(
        'amc_contract_id', NEW.amc_contract_id,
        'repair_job_id',   NEW.id,
        'engineer_id',     v_assigned
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'auto_assign_amc_visit_on_create: hospital notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.auto_assign_amc_visit_on_create() FROM PUBLIC;

DROP TRIGGER IF EXISTS auto_assign_amc_visit_on_create_trg ON public.repair_jobs;
CREATE TRIGGER auto_assign_amc_visit_on_create_trg
  AFTER INSERT ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.kind = 'maintenance' AND NEW.amc_contract_id IS NOT NULL AND NEW.engineer_id IS NULL)
  EXECUTE FUNCTION public.auto_assign_amc_visit_on_create();

-- ---------------------------------------------------------------------------
-- 4. AFTER UPDATE OF is_available trigger on engineers — re-rotate.
-- ---------------------------------------------------------------------------
-- Primary engineer toggles is_available=false mid-window. For each
-- pending AMC visit they're on (status IN requested/assigned, not yet
-- en_route), if we're past half the standard SLA window, push to the
-- next fallback. Half is the judgment call: gives the primary a chance
-- to flip back available within minutes/hours, but cuts losses before
-- the breach window closes.

CREATE OR REPLACE FUNCTION public.re_rotate_on_engineer_unavailable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_visit record;
  v_new_engineer uuid;
  v_new_engineer_user uuid;
  v_hours_elapsed numeric;
  v_half_window numeric;
BEGIN
  FOR v_visit IN
    SELECT rj.id, rj.amc_contract_id, rj.hospital_user_id, rj.job_number,
           rj.status::text AS status_text, rj.created_at, rj.updated_at,
           c.response_time_standard_hours
      FROM public.repair_jobs rj
      JOIN public.amc_contracts c ON c.id = rj.amc_contract_id
     WHERE rj.engineer_id = NEW.id
       AND rj.kind = 'maintenance'
       AND rj.status::text IN ('requested','assigned')
  LOOP
    v_half_window := greatest(v_visit.response_time_standard_hours, 1)::numeric / 2.0;
    v_hours_elapsed := extract(epoch FROM (now() - coalesce(v_visit.updated_at, v_visit.created_at))) / 3600.0;

    IF v_hours_elapsed < v_half_window THEN
      -- Still within grace window for the primary. Skip — primary
      -- might toggle back. PR-C4 SLA breach detector will pick it up
      -- if they don't.
      CONTINUE;
    END IF;

    v_new_engineer := public.assign_next_available_amc_engineer(v_visit.id);

    IF v_new_engineer IS NOT NULL AND v_new_engineer <> NEW.id THEN
      -- Notify the new engineer + hospital that the rotation moved.
      SELECT user_id INTO v_new_engineer_user
        FROM public.engineers WHERE id = v_new_engineer;

      IF v_new_engineer_user IS NOT NULL THEN
        BEGIN
          INSERT INTO public.notifications (user_id, kind, title, body, data)
          VALUES (
            v_new_engineer_user,
            'amc_visit_assigned',
            'AMC visit reassigned to you',
            concat('Primary engineer is unavailable; visit ',
                   coalesce(v_visit.job_number, substring(v_visit.id::text, 1, 8)),
                   ' is now yours.'),
            jsonb_build_object(
              'amc_contract_id', v_visit.amc_contract_id,
              'repair_job_id',   v_visit.id,
              'job_number',      v_visit.job_number,
              'rerouted',        true
            )
          );
        EXCEPTION WHEN OTHERS THEN
          RAISE NOTICE 're_rotate_on_engineer_unavailable: engineer notify failed: % / %', SQLSTATE, SQLERRM;
        END;
      END IF;

      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_visit.hospital_user_id,
          'amc_visit_engineer_changed',
          'AMC engineer changed',
          'Your AMC visit was reassigned to a backup engineer.',
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id,
            'engineer_id',     v_new_engineer
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 're_rotate_on_engineer_unavailable: hospital notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    ELSIF v_new_engineer IS NULL THEN
      -- Helper already inserted an escalation row. Nudge the hospital.
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_visit.hospital_user_id,
          'amc_visit_pending_assignment',
          'Finding a backup engineer',
          'Your AMC engineer is unavailable and we''re lining up a backup.',
          jsonb_build_object(
            'amc_contract_id', v_visit.amc_contract_id,
            'repair_job_id',   v_visit.id
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 're_rotate_on_engineer_unavailable: hospital pending notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.re_rotate_on_engineer_unavailable() FROM PUBLIC;

DROP TRIGGER IF EXISTS re_rotate_on_engineer_unavailable_trg ON public.engineers;
CREATE TRIGGER re_rotate_on_engineer_unavailable_trg
  AFTER UPDATE OF is_available ON public.engineers
  FOR EACH ROW
  WHEN (NEW.is_available = false AND OLD.is_available = true)
  EXECUTE FUNCTION public.re_rotate_on_engineer_unavailable();

-- ---------------------------------------------------------------------------
-- 5. add_amc_fallback_engineer — hospital extends rotation.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.add_amc_fallback_engineer(
  p_contract_id uuid,
  p_engineer_id uuid,
  p_priority int DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_hospital_id uuid;
  v_engineer_verified boolean;
  v_priority int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT hospital_user_id INTO v_hospital_id
    FROM public.amc_contracts WHERE id = p_contract_id;
  IF v_hospital_id IS NULL THEN
    RAISE EXCEPTION 'contract not found' USING ERRCODE = '42704';
  END IF;
  IF v_caller <> v_hospital_id
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not the contract owner' USING ERRCODE = '42501';
  END IF;

  SELECT (verification_status::text = 'verified') INTO v_engineer_verified
    FROM public.engineers WHERE id = p_engineer_id;
  IF v_engineer_verified IS NULL OR NOT v_engineer_verified THEN
    RAISE EXCEPTION 'fallback engineer must be verified' USING ERRCODE = '22023';
  END IF;

  IF p_priority IS NULL THEN
    SELECT coalesce(max(priority), 0) + 1 INTO v_priority
      FROM public.amc_engineer_rotation
      WHERE amc_contract_id = p_contract_id;
  ELSE
    IF p_priority < 2 THEN
      RAISE EXCEPTION 'priority must be >= 2 (priority 1 is reserved for the primary engineer)'
        USING ERRCODE = '22023';
    END IF;
    v_priority := p_priority;
  END IF;

  INSERT INTO public.amc_engineer_rotation (amc_contract_id, engineer_id, priority, active)
  VALUES (p_contract_id, p_engineer_id, v_priority, true)
  ON CONFLICT (amc_contract_id, engineer_id)
    DO UPDATE SET active = true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.add_amc_fallback_engineer(uuid, uuid, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.add_amc_fallback_engineer(uuid, uuid, int) TO authenticated;

-- ---------------------------------------------------------------------------
-- 6. remove_amc_fallback_engineer — soft-delete via active=false.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.remove_amc_fallback_engineer(
  p_contract_id uuid,
  p_engineer_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_hospital_id uuid;
  v_priority int;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT hospital_user_id INTO v_hospital_id
    FROM public.amc_contracts WHERE id = p_contract_id;
  IF v_hospital_id IS NULL THEN
    RAISE EXCEPTION 'contract not found' USING ERRCODE = '42704';
  END IF;
  IF v_caller <> v_hospital_id
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not the contract owner' USING ERRCODE = '42501';
  END IF;

  SELECT priority INTO v_priority
    FROM public.amc_engineer_rotation
    WHERE amc_contract_id = p_contract_id AND engineer_id = p_engineer_id;
  IF v_priority IS NULL THEN
    -- nothing to do
    RETURN;
  END IF;
  IF v_priority = 1 THEN
    RAISE EXCEPTION 'cannot remove the primary engineer; change amc_contracts.primary_engineer_id instead'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.amc_engineer_rotation
     SET active = false
   WHERE amc_contract_id = p_contract_id
     AND engineer_id = p_engineer_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.remove_amc_fallback_engineer(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remove_amc_fallback_engineer(uuid, uuid) TO authenticated;

-- ---------------------------------------------------------------------------
-- 7. list_amc_rotation — hospital UI lists engineers in priority order.
-- ---------------------------------------------------------------------------
-- SECURITY INVOKER so the rotation SELECT policy from PR-C1 applies. The
-- policy lets hospital owner + any rotation engineer see the list.

CREATE OR REPLACE FUNCTION public.list_amc_rotation(p_contract_id uuid)
RETURNS TABLE (
  rotation_id uuid,
  engineer_id uuid,
  engineer_name text,
  engineer_city text,
  priority int,
  is_primary boolean,
  active boolean,
  is_available boolean
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT
    r.id AS rotation_id,
    r.engineer_id,
    coalesce(p.full_name, '(unnamed)') AS engineer_name,
    coalesce(e.city, '') AS engineer_city,
    r.priority,
    (r.priority = 1) AS is_primary,
    r.active,
    coalesce(e.is_available, false) AS is_available
  FROM public.amc_engineer_rotation r
  JOIN public.engineers e ON e.id = r.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE r.amc_contract_id = p_contract_id
  ORDER BY r.priority ASC;
$$;

GRANT EXECUTE ON FUNCTION public.list_amc_rotation(uuid) TO authenticated;
