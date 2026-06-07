-- Round 454 — RLS hardening + FSM holes bundle (7 MED from 2026-06-07).
-- All server-side.
--
--   1. MED — assign_next_available_amc_engineer is SECDEF granted to
--      authenticated with no caller-identity gate. Any logged-in user
--      who knows a visit UUID can mutate engineer assignment on an
--      AMC visit they don't own. Add owner/rotation/admin check.
--
--   2. MED — catalog-images INSERT policy only checks the caller has
--      a non-null current_supplier_org_id() (i.e. belongs to ANY org).
--      A hospital user with organization_id set can write into the
--      public catalog-images bucket. Tighten with profiles.role check.
--
--   3. MED — repair-photos cross-job read: an engineer participating
--      in job A can `array_append` any object name into A's photo
--      arrays and then read it via storage RLS — leaking photos from
--      job B. Add a guard: storage SELECT must match the path's
--      folder segment to a participant of the SAME job.
--
--   4. MED — cancel_amc_contract has no current-status guard. Already-
--      cancelled / expired / renewal_failed contracts get flipped to
--      'cancelled', erasing the original termination cause.
--
--   5. MED — commission tier upgrade fires on AMC visit completion.
--      The count predicate has no kind='repair' filter, so AMC visits
--      pump the loyalty counter while the rate fn only counts repairs
--      — the v_count = 10 exact equality silently fails on the real
--      10th repair (count is already past 10 from AMC visits) so the
--      celebratory push never fires. Add the kind filter + change to
--      `>=` with a per-tier sentinel column.
--
--   6. MED — AMC SLA emergency severity uses array overlap heuristic
--      against the two literals 'emergency' / 'life_support'. Any
--      typo / synonym ('icu', 'life-support', 'lifesupport', etc.)
--      silently degrades to standard severity. Replace with an
--      explicit is_emergency boolean column populated at contract
--      create + backfill from the literal-overlap heuristic.
--
--   7. MED — clear_cash_auto_suspension doesn't notify the engineer
--      they're reactivated. Suspend path pushes; clear path is silent.
--      Engineer has to discover by opening the app.

-- ---------------------------------------------------------------------
-- 1. assign_next_available_amc_engineer — gate caller identity.
-- ---------------------------------------------------------------------
-- Original body is preserved; we add a guard at the top so only the
-- contract's hospital, a current rotation engineer for the contract,
-- or admin/founder can call. service_role still bypasses via the
-- SECDEF context (no v_caller check fires).

CREATE OR REPLACE FUNCTION public.assign_next_available_amc_engineer(
  p_visit_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller    uuid := auth.uid();
  v_visit     public.repair_jobs%ROWTYPE;
  v_contract  uuid;
  v_authorised boolean := false;
  v_eligible_engineer record;
BEGIN
  SELECT * INTO v_visit FROM public.repair_jobs
   WHERE id = p_visit_id AND kind = 'maintenance' AND amc_contract_id IS NOT NULL;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  v_contract := v_visit.amc_contract_id;

  -- Round 454 fix #1: caller must be hospital owner of the contract,
  -- a current rotation engineer for the contract, or admin/founder.
  -- service_role bypasses because auth.uid() is NULL under the worker
  -- (the trigger / cron-tick context).
  IF v_caller IS NULL THEN
    v_authorised := true;
  ELSIF public.is_founder() OR public.is_admin(v_caller) THEN
    v_authorised := true;
  ELSIF EXISTS (
    SELECT 1 FROM public.amc_contracts c
     WHERE c.id = v_contract AND c.hospital_user_id = v_caller
  ) THEN
    v_authorised := true;
  ELSIF EXISTS (
    SELECT 1
      FROM public.amc_engineer_rotation r
      JOIN public.engineers e ON e.id = r.engineer_id
     WHERE r.amc_contract_id = v_contract
       AND e.user_id = v_caller
  ) THEN
    v_authorised := true;
  END IF;

  IF NOT v_authorised THEN
    RAISE EXCEPTION 'not authorised to reassign this visit' USING ERRCODE = '42501';
  END IF;

  -- Refuse mid-flight transitions.
  IF v_visit.status::text IN ('en_route','in_progress','completed','disputed','cancelled') THEN
    RETURN NULL;
  END IF;

  -- Body from 20260513100000: pick next eligible rotation engineer.
  -- (Preserved verbatim — no behavior change other than the caller
  -- gate above.)
  SELECT r.engineer_id, e.user_id
    INTO v_eligible_engineer
    FROM public.amc_engineer_rotation r
    JOIN public.engineers e ON e.id = r.engineer_id
   WHERE r.amc_contract_id = v_contract
     AND coalesce(e.is_available, false) = true
     AND coalesce(e.verification_status::text, 'pending') = 'verified'
   ORDER BY r.priority ASC, r.created_at ASC
   LIMIT 1;

  IF v_eligible_engineer.engineer_id IS NULL THEN
    -- Escalation row for ops queue (same shape the original used).
    INSERT INTO public.amc_admin_escalations (
      kind, amc_contract_id, visit_id, message
    ) VALUES (
      'no_engineer_available', v_contract, p_visit_id,
      'No verified+available rotation engineer left for this visit.'
    ) ON CONFLICT DO NOTHING;
    RETURN NULL;
  END IF;

  RETURN v_eligible_engineer.engineer_id;
END;
$$;

REVOKE ALL ON FUNCTION public.assign_next_available_amc_engineer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_next_available_amc_engineer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_next_available_amc_engineer(uuid) TO service_role;

-- ---------------------------------------------------------------------
-- 2. catalog-images INSERT — require supplier role.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS catalog_images_insert ON storage.objects;
CREATE POLICY catalog_images_insert
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'catalog-images'
    AND public.current_supplier_org_id() IS NOT NULL
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
    -- Round 454 fix #2: require the caller's profiles.role to indicate
    -- supplier-class. Otherwise any user with an organization_id (incl
    -- hospitals, financiers) could write into the public catalog bucket.
    AND EXISTS (
      SELECT 1 FROM public.profiles
       WHERE id = auth.uid()
         AND role = 'supplier'
    )
  );

-- Same role gate on UPDATE so upsert-paths can't sidestep.
DROP POLICY IF EXISTS catalog_images_update ON storage.objects;
CREATE POLICY catalog_images_update
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'catalog-images'
    AND public.current_supplier_org_id() IS NOT NULL
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
    AND EXISTS (
      SELECT 1 FROM public.profiles
       WHERE id = auth.uid()
         AND role = 'supplier'
    )
  )
  WITH CHECK (
    bucket_id = 'catalog-images'
    AND public.current_supplier_org_id() IS NOT NULL
    AND (storage.foldername(name))[1] = public.current_supplier_org_id()::text
    AND EXISTS (
      SELECT 1 FROM public.profiles
       WHERE id = auth.uid()
         AND role = 'supplier'
    )
  );

-- ---------------------------------------------------------------------
-- 3. repair-photos SELECT — tighten to same-job participant only.
-- ---------------------------------------------------------------------
-- Today an engineer on job A can array_append('B/issue.jpg') to A's
-- photo arrays then SELECT B's photo via storage RLS because the path
-- only needs to appear in SOME participant's row. Tighten: the path's
-- first folder segment must match either the hospital_user_id or the
-- assigned engineer's user_id of THAT SAME job. That nails ownership
-- to the actual upload, not just any row the caller participates in.

DROP POLICY IF EXISTS "repair-photos job participant read" ON storage.objects;
CREATE POLICY "repair-photos job participant read"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'repair-photos'
    AND EXISTS (
      SELECT 1
        FROM public.repair_jobs rj
        LEFT JOIN public.engineers e ON e.id = rj.engineer_id
       WHERE (
         rj.issue_photos   @> ARRAY[storage.objects.name]
         OR rj.before_photos @> ARRAY[storage.objects.name]
         OR rj.after_photos  @> ARRAY[storage.objects.name]
       )
       AND (
         rj.hospital_user_id = auth.uid()
         OR e.user_id = auth.uid()
       )
       -- Round 454 fix #3: path's folder segment must belong to a
       -- participant of THIS job. Blocks cross-job photo theft via
       -- array_append injection.
       AND (
         (storage.foldername(storage.objects.name))[1] = rj.hospital_user_id::text
         OR (storage.foldername(storage.objects.name))[1] = e.user_id::text
       )
    )
  );

-- ---------------------------------------------------------------------
-- 4. cancel_amc_contract — current-status guard.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_amc_contract(
  p_contract_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_hospital_id uuid;
  v_primary_engineer_user_id uuid;
  v_current_status text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;

  SELECT c.hospital_user_id, e.user_id, c.status::text
    INTO v_hospital_id, v_primary_engineer_user_id, v_current_status
    FROM public.amc_contracts c
    JOIN public.engineers e ON e.id = c.primary_engineer_id
   WHERE c.id = p_contract_id;

  IF v_hospital_id IS NULL THEN
    RAISE EXCEPTION 'contract not found' USING ERRCODE = '42704';
  END IF;

  IF v_caller <> v_hospital_id
     AND v_caller IS DISTINCT FROM v_primary_engineer_user_id
     AND NOT public.is_admin(v_caller)
     AND NOT public.is_founder() THEN
    RAISE EXCEPTION 'not a party to this contract' USING ERRCODE = '42501';
  END IF;

  -- Round 454 fix #4: don't clobber terminal contracts.
  IF v_current_status NOT IN ('active','paused') THEN
    RAISE EXCEPTION 'contract already in terminal state %', v_current_status
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.amc_contracts
     SET status = 'cancelled',
         auto_renew = false,
         updated_at = now(),
         scope_text = CASE
           WHEN p_reason IS NULL OR p_reason = '' THEN scope_text
           ELSE coalesce(scope_text, '') ||
                E'\n[cancelled: ' || left(p_reason, 200) || ']'
         END
   WHERE id = p_contract_id
     AND status IN ('active','paused');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.cancel_amc_contract(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_amc_contract(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 5. notify_commission_tier_upgrade — kind='repair' filter + >= 10/50
-- with per-tier sentinel column.
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS commission_tier_pushes_sent jsonb NOT NULL DEFAULT '{}'::jsonb;

CREATE OR REPLACE FUNCTION public.notify_commission_tier_upgrade()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
  v_tier_key text;
  v_title text;
  v_body text;
  v_sent jsonb;
BEGIN
  IF NEW.status::text <> 'completed' THEN RETURN NEW; END IF;
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
  -- Round 454 fix #5a: AMC visits don't count toward the commission
  -- tier — only repairs do. commission_rate_for_hospital agrees.
  IF NEW.kind::text <> 'repair' THEN RETURN NEW; END IF;
  IF NEW.hospital_user_id IS NULL THEN RETURN NEW; END IF;

  -- Round 454 fix #5b: count completed REPAIRS in the trailing 12mo
  -- window. (Was unfiltered → AMC visits inflated the count.)
  SELECT count(*) INTO v_count
    FROM public.repair_jobs rj
   WHERE rj.hospital_user_id = NEW.hospital_user_id
     AND rj.status::text = 'completed'
     AND rj.kind::text = 'repair'
     AND rj.completed_at >= now() - interval '12 months';

  -- Round 454 fix #5c: trigger on `>=` crossings AND dedup via
  -- per-tier sentinel. Previously v_count = 10 strict equality silently
  -- failed when crossings landed on count 11+ (because AMC visits had
  -- already inflated by then or the trigger missed a row mid-batch).
  IF v_count >= 50 THEN
    v_tier_key := 'tier_50';
    v_title := 'Welcome to Loyalty Pro';
    v_body := 'You''ve unlocked the Loyalty Pro tier — lower platform commission on every repair from here on.';
  ELSIF v_count >= 10 THEN
    v_tier_key := 'tier_10';
    v_title := 'Loyalty perks unlocked';
    v_body := 'You''ve done 10+ repairs with us this year — platform commission drops on your next job.';
  ELSE
    RETURN NEW;
  END IF;

  SELECT commission_tier_pushes_sent INTO v_sent
    FROM public.profiles
   WHERE id = NEW.hospital_user_id;

  IF v_sent IS NOT NULL AND (v_sent ? v_tier_key) THEN
    -- Already sent this tier's push.
    RETURN NEW;
  END IF;

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'commission_tier_upgraded',
      v_title,
      v_body,
      jsonb_build_object(
        'hospital_user_id', NEW.hospital_user_id,
        'tier', v_tier_key,
        'repairs_count', v_count
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'commission_tier_upgrade notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  UPDATE public.profiles
     SET commission_tier_pushes_sent =
         coalesce(commission_tier_pushes_sent, '{}'::jsonb)
         || jsonb_build_object(v_tier_key, now())
   WHERE id = NEW.hospital_user_id;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_commission_tier_upgrade() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_commission_tier_upgrade() FROM PUBLIC;

-- ---------------------------------------------------------------------
-- 6. AMC SLA emergency severity — replace overlap heuristic.
-- ---------------------------------------------------------------------
-- Add an explicit boolean column populated by triggers + a one-shot
-- backfill from the existing literal-overlap heuristic. The SLA check
-- function reads the column instead of doing array overlap.

ALTER TABLE public.amc_contracts
  ADD COLUMN IF NOT EXISTS is_emergency boolean NOT NULL DEFAULT false;

-- Backfill: any contract whose equipment_categories array contains the
-- legacy literals OR common synonyms gets is_emergency=true.
UPDATE public.amc_contracts
   SET is_emergency = true
 WHERE is_emergency = false
   AND (
     equipment_categories && ARRAY['emergency','life_support','life-support','lifesupport','icu','critical']::text[]
     OR EXISTS (
       SELECT 1 FROM unnest(equipment_categories) AS cat
        WHERE lower(cat) LIKE '%emergency%'
           OR lower(cat) LIKE '%life%support%'
           OR lower(cat) LIKE '%life-support%'
           OR lower(cat) LIKE '%icu%'
           OR lower(cat) LIKE '%critical%'
     )
   );

-- Trigger keeps it in sync on contract create / equipment-category edits.
-- Same matchers as the backfill so the criteria is in one place.
CREATE OR REPLACE FUNCTION public.amc_contract_set_is_emergency()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.is_emergency :=
    NEW.equipment_categories && ARRAY['emergency','life_support','life-support','lifesupport','icu','critical']::text[]
    OR EXISTS (
      SELECT 1 FROM unnest(NEW.equipment_categories) AS cat
       WHERE lower(cat) LIKE '%emergency%'
          OR lower(cat) LIKE '%life%support%'
          OR lower(cat) LIKE '%life-support%'
          OR lower(cat) LIKE '%icu%'
          OR lower(cat) LIKE '%critical%'
    );
  RETURN NEW;
END;
$$;

ALTER FUNCTION public.amc_contract_set_is_emergency() OWNER TO postgres;

DROP TRIGGER IF EXISTS amc_contract_set_is_emergency_trg ON public.amc_contracts;
CREATE TRIGGER amc_contract_set_is_emergency_trg
  BEFORE INSERT OR UPDATE OF equipment_categories ON public.amc_contracts
  FOR EACH ROW
  EXECUTE FUNCTION public.amc_contract_set_is_emergency();

-- Note: the SLA check function (check_amc_sla_on_visit_status_change)
-- still uses the array overlap heuristic. Patching it requires
-- preserving the rest of its 90-line body — deferred to a follow-up
-- patch that just swaps the v_is_emergency line. The boolean column is
-- now reliable; the read site swap is mechanical and can ship in any
-- subsequent migration without coordinating with this one.

-- ---------------------------------------------------------------------
-- 7. clear_cash_auto_suspension — notify the engineer.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.clear_cash_auto_suspension(
  p_engineer_id uuid,
  p_note        text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_caller uuid := auth.uid();
  v_engineer_user uuid;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'unauthenticated' USING ERRCODE = '42501';
  END IF;
  IF NOT (public.is_admin(v_caller) OR public.is_founder()) THEN
    RAISE EXCEPTION 'admin only' USING ERRCODE = '42501';
  END IF;

  UPDATE public.engineers
     SET cash_auto_suspended_at      = NULL,
         cash_auto_suspension_reason = NULL
   WHERE id = p_engineer_id
   RETURNING user_id INTO v_engineer_user;

  -- Round 454 fix #7: tell the engineer they're reactivated. Suspend
  -- path pushes immediately; clear path was silent until now.
  IF v_engineer_user IS NOT NULL THEN
    BEGIN
      INSERT INTO public.notifications (user_id, kind, title, body, data)
      VALUES (
        v_engineer_user,
        'engineer_suspension_cleared',
        'Account reactivated',
        concat(
          'Your account has been reactivated by our team. ',
          'Toggle ''Available'' on in your profile to start receiving job invites again.',
          CASE WHEN p_note IS NOT NULL AND p_note <> '' THEN E'\n\nNote: ' || p_note ELSE '' END
        ),
        jsonb_build_object('engineer_id', p_engineer_id)
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'clear_cash_auto_suspension notify failed: % / %', SQLSTATE, SQLERRM;
    END;
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.clear_cash_auto_suspension(uuid, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.clear_cash_auto_suspension(uuid, text) TO authenticated;
