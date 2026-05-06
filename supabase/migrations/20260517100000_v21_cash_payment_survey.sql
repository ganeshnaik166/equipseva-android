-- v2.1 PR-D1: post-completion cash-payment survey (T2.6 in
-- anti-disintermediation strategy).
--
-- 24h after a repair_job hits 'completed', ping the hospital with a
-- one-question survey: did the engineer ask for cash payment outside
-- the app? Three 'asked_cash' flags on the same engineer in 90 days
-- → admin alert (soft signal — no auto-suspend in v1, deferred to
-- v2.2 to avoid weaponization).
--
-- Pieces:
--   1. cash_survey_responses table (one row per repair_job)
--   2. RLS: hospital can SELECT own; INSERT only via SECDEF RPC
--   3. submit_cash_survey(p_job, p_response) — gates on hospital_user_id,
--      job in 'completed', responded within 7-day window
--   4. get_pending_cash_survey() — returns the next un-surveyed completed
--      job for the calling hospital (last 7 days)
--   5. engineer_cash_flag_count_90d(p_engineer_id) — admin-facing read
--   6. notify_on_repair_job_completed_for_cash_survey trigger — inserts
--      a notifications row with kind='cash_survey' on the same status
--      transition that already fires the rate prompt (sister of
--      notify_on_repair_job_completed_for_rating from #245-ish)
--
-- Note on 24h delay: notifications baseline has no scheduled-send
-- column. We insert immediately at completion and let the Android
-- bottom-sheet gate by `now() - completed_at >= interval '24h'` so the
-- prompt only surfaces at the right moment. Cheap, no cron required.

CREATE TABLE IF NOT EXISTS public.cash_survey_responses (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  repair_job_id    uuid NOT NULL UNIQUE REFERENCES public.repair_jobs(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES auth.users(id)             ON DELETE CASCADE,
  engineer_id      uuid NOT NULL REFERENCES public.engineers(id)        ON DELETE CASCADE,
  response         text NOT NULL CHECK (response IN ('asked_cash','no_cash','declined')),
  responded_at     timestamptz NOT NULL DEFAULT now(),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cash_survey_engineer_recent
  ON public.cash_survey_responses (engineer_id, response, responded_at DESC);

ALTER TABLE public.cash_survey_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS cash_survey_select_hospital ON public.cash_survey_responses;
CREATE POLICY cash_survey_select_hospital
  ON public.cash_survey_responses FOR SELECT
  USING (auth.uid() = hospital_user_id);

DROP POLICY IF EXISTS cash_survey_select_admin ON public.cash_survey_responses;
CREATE POLICY cash_survey_select_admin
  ON public.cash_survey_responses FOR SELECT
  USING (public.is_admin(auth.uid()) OR public.is_founder());

-- No INSERT/UPDATE/DELETE policies → only SECDEF RPCs can write.

GRANT SELECT ON public.cash_survey_responses TO authenticated;

-- ---------------------------------------------------------------------
-- RPC: submit_cash_survey
-- Called by hospital from the bottom-sheet response.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_cash_survey(
  p_job      uuid,
  p_response text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller       uuid := auth.uid();
  v_hospital     uuid;
  v_engineer     uuid;
  v_status       text;
  v_completed_at timestamptz;
  v_id           uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF p_response NOT IN ('asked_cash','no_cash','declined') THEN
    RAISE EXCEPTION 'invalid response %', p_response USING ERRCODE = '22023';
  END IF;

  SELECT hospital_user_id, engineer_id, status::text, completed_at
    INTO v_hospital, v_engineer, v_status, v_completed_at
    FROM public.repair_jobs
   WHERE id = p_job;

  IF v_hospital IS NULL THEN
    RAISE EXCEPTION 'job not found' USING ERRCODE = '02000';
  END IF;
  IF v_hospital <> v_caller THEN
    RAISE EXCEPTION 'not the hospital on this job' USING ERRCODE = '42501';
  END IF;
  IF v_status <> 'completed' THEN
    RAISE EXCEPTION 'job not completed' USING ERRCODE = '22023';
  END IF;
  IF v_engineer IS NULL THEN
    RAISE EXCEPTION 'job has no engineer' USING ERRCODE = '22023';
  END IF;
  -- 7-day response window (matches dispute window in strategy doc)
  IF v_completed_at IS NULL OR v_completed_at < now() - interval '7 days' THEN
    RAISE EXCEPTION 'survey window closed' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.cash_survey_responses (
    repair_job_id, hospital_user_id, engineer_id, response
  ) VALUES (
    p_job, v_hospital, v_engineer, p_response
  )
  ON CONFLICT (repair_job_id) DO UPDATE
    SET response = EXCLUDED.response,
        responded_at = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.submit_cash_survey(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.submit_cash_survey(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- RPC: get_pending_cash_survey
-- Returns the next un-surveyed completed job for the calling hospital
-- in the 24h..7d window. Android calls this on app open.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_pending_cash_survey()
RETURNS TABLE (
  repair_job_id uuid,
  job_number    text,
  engineer_name text,
  completed_at  timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT
    rj.id              AS repair_job_id,
    rj.job_number,
    coalesce(p.full_name, '(unnamed)') AS engineer_name,
    rj.completed_at
  FROM public.repair_jobs rj
  JOIN public.engineers e ON e.id = rj.engineer_id
  LEFT JOIN public.profiles p ON p.id = e.user_id
  WHERE rj.hospital_user_id = auth.uid()
    AND rj.status::text     = 'completed'
    AND rj.completed_at IS NOT NULL
    AND rj.completed_at <= now() - interval '24 hours'
    AND rj.completed_at >= now() - interval '7 days'
    AND NOT EXISTS (
      SELECT 1
        FROM public.cash_survey_responses csr
       WHERE csr.repair_job_id = rj.id
    )
  ORDER BY rj.completed_at ASC
  LIMIT 1;
$$;
REVOKE EXECUTE ON FUNCTION public.get_pending_cash_survey() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_pending_cash_survey() TO authenticated;

-- ---------------------------------------------------------------------
-- RPC: engineer_cash_flag_count_90d
-- Admin / founder facing read for the dashboards. Returns total
-- 'asked_cash' responses in the last 90 days for an engineer.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.engineer_cash_flag_count_90d(p_engineer_id uuid)
RETURNS int
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_count  int  := 0;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_count
    FROM public.cash_survey_responses
   WHERE engineer_id = p_engineer_id
     AND response = 'asked_cash'
     AND responded_at >= now() - interval '90 days';

  RETURN v_count;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.engineer_cash_flag_count_90d(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_cash_flag_count_90d(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- Trigger: enqueue an in-app notification at completion. The 24h gate
-- is enforced by get_pending_cash_survey on the read side, so this just
-- needs to drop a notification row so the user has a tappable entry in
-- the bell list. Sister of notify_on_repair_job_completed_for_rating.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notify_on_repair_job_completed_for_cash_survey()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job_number text;
BEGIN
  IF NEW.status::text <> 'completed' THEN
    RETURN NEW;
  END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;
  IF NEW.hospital_user_id IS NULL OR NEW.engineer_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'cash_survey',
      'Quick check-in',
      concat('How did payment go for job ', v_job_number, '?'),
      jsonb_build_object('repair_job_id', NEW.id, 'job_number', v_job_number)
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'cash_survey notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_on_repair_job_completed_for_cash_survey() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_on_repair_job_completed_for_cash_survey() FROM PUBLIC;

DROP TRIGGER IF EXISTS notify_on_repair_job_completed_for_cash_survey_trg ON public.repair_jobs;
CREATE TRIGGER notify_on_repair_job_completed_for_cash_survey_trg
  AFTER UPDATE OF status ON public.repair_jobs
  FOR EACH ROW
  WHEN (NEW.status::text = 'completed' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_on_repair_job_completed_for_cash_survey();
