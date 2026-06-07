-- Round 455 — LOW polish bundle (5 LOW from 2026-06-07 audit).
-- Server-side; companion Android-side polish ships in the same PR.
--
--   1. LOW — avatars_owner_update missing explicit WITH CHECK. Today
--      Postgres falls back to applying USING to NEW row, so no live
--      escape; the drift from project convention (kyc-docs/chat-att/
--      repair-photos all explicit) is a regression footgun. Pin it.
--
--   2. LOW — service-reports bucket missing file_size_limit +
--      allowed_mime_types. Every other bucket pins these per PR #140.
--      Service-role writes today but defense-in-depth.
--
--   3. LOW — chat-attachments SELECT policy excludes the recipient.
--      Today no Android UI consumes the bucket (text-only chat) so
--      it's latent dead code, but the moment a chat-attachment UI is
--      wired up it will silently 403. Extend SELECT to participants
--      of the conversation containing the attachment.
--
--   4. LOW — expire_lapsed_amc_contracts filters status='active' only.
--      Paused contracts that lapse their end_date sit at 'paused'
--      forever. Broaden to ('active','paused').
--
--   5. LOW — notify_warranty_covered_after_insert pushes hospital only.
--      Engineer needs to know at bid time that the payout will be
--      platform-covered. Add engineer fan-out when engineer_id is set
--      at insert time (rare on directory broadcast, but defensive for
--      AMC-style pre-assigned warranty rebooks).

-- ---------------------------------------------------------------------
-- 1. avatars_owner_update — explicit WITH CHECK
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS avatars_owner_update ON storage.objects;
CREATE POLICY avatars_owner_update
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------
-- 2. service-reports bucket — file_size_limit + allowed_mime_types
-- ---------------------------------------------------------------------
UPDATE storage.buckets
   SET file_size_limit = 5 * 1024 * 1024,
       allowed_mime_types = ARRAY['text/html','application/pdf']
 WHERE id = 'service-reports';

-- ---------------------------------------------------------------------
-- 3. chat-attachments SELECT — extend to other conversation participant
-- ---------------------------------------------------------------------
-- The bucket path convention is `<sender_user_id>/<filename>`. The
-- new clause grants SELECT to the OTHER party in the conversation
-- that contains a message referencing this path. Today no messages
-- reference attachments (text-only chat), so this is forward-compat
-- wiring for the future attachment UI. Joins chat_messages where the
-- attachment_path column would carry the storage object name.

DROP POLICY IF EXISTS chat_attachments_owner_select ON storage.objects;
CREATE POLICY chat_attachments_owner_select
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'chat-attachments'
    AND (
      -- Owner of the folder (sender).
      (storage.foldername(name))[1] = auth.uid()::text
      -- OR a participant in a conversation that has a message
      -- referencing this attachment path (chat_messages.message stores
      -- the path inline by convention until a dedicated column ships).
      OR EXISTS (
        SELECT 1
          FROM public.chat_messages m
          JOIN public.chat_conversations c ON c.id = m.conversation_id
         WHERE m.message = storage.objects.name
           AND (
             c.party_a_user_id = auth.uid()
             OR c.party_b_user_id = auth.uid()
           )
      )
    )
  );

-- ---------------------------------------------------------------------
-- 4. expire_lapsed_amc_contracts — include paused contracts
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.expire_lapsed_amc_contracts()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_count int;
BEGIN
  WITH updated AS (
    UPDATE public.amc_contracts
       SET status = 'expired',
           auto_renew = false,
           updated_at = now()
     -- Round 455 fix #4: broaden from status='active' to include
     -- 'paused' contracts. A paused contract whose end_date passes
     -- was previously sitting at paused forever (never expired,
     -- never auto-renewed, never created visits). The transition
     -- 'paused → expired' is legal per the CHECK constraint and is
     -- the right terminal state.
     WHERE status IN ('active','paused')
       AND end_date < CURRENT_DATE
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM updated;
  RETURN v_count;
END;
$$;

ALTER FUNCTION public.expire_lapsed_amc_contracts() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.expire_lapsed_amc_contracts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.expire_lapsed_amc_contracts() TO service_role;

-- ---------------------------------------------------------------------
-- 5. notify_warranty_covered_after_insert — engineer fan-out
-- ---------------------------------------------------------------------
-- Add an engineer-side notification when engineer_id IS NOT NULL at
-- insert time (AMC-style pre-assigned warranty rebooks). Hospital push
-- already exists. For directory-broadcast (engineer_id NULL) the bid
-- surface needs the warranty badge — that's a UI follow-up; here we
-- just close the assigned-at-insert gap.

CREATE OR REPLACE FUNCTION public.notify_warranty_covered_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_job_number text;
  v_engineer_user uuid;
BEGIN
  IF NOT NEW.is_warranty_covered THEN RETURN NEW; END IF;
  IF NEW.hospital_user_id IS NULL THEN RETURN NEW; END IF;

  v_job_number := COALESCE(NEW.job_number, substring(NEW.id::text, 1, 8));

  BEGIN
    INSERT INTO public.notifications (user_id, kind, title, body, data)
    VALUES (
      NEW.hospital_user_id,
      'warranty_covered',
      'Covered by 30-day warranty',
      concat(
        'Job ', v_job_number,
        ' is within 30 days of an earlier completed repair. Service fee is waived once an engineer is assigned.'
      ),
      jsonb_build_object(
        'repair_job_id',         NEW.id,
        'job_number',            v_job_number,
        'warranty_source_job_id', NEW.warranty_source_job_id
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'warranty_covered notify failed: % / %', SQLSTATE, SQLERRM;
  END;

  -- Round 455 fix #5: engineer fan-out when assigned-at-insert.
  IF NEW.engineer_id IS NOT NULL THEN
    SELECT user_id INTO v_engineer_user
      FROM public.engineers WHERE id = NEW.engineer_id;
    IF v_engineer_user IS NOT NULL THEN
      BEGIN
        INSERT INTO public.notifications (user_id, kind, title, body, data)
        VALUES (
          v_engineer_user,
          'warranty_covered',
          'Platform-warranty re-visit',
          concat(
            'Job ', v_job_number,
            ' is a 30-day warranty re-visit on prior work. Platform funds the payout for this job.'
          ),
          jsonb_build_object(
            'repair_job_id',          NEW.id,
            'job_number',             v_job_number,
            'warranty_source_job_id', NEW.warranty_source_job_id,
            'engineer_facing',        true
          )
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'warranty_covered engineer notify failed: % / %', SQLSTATE, SQLERRM;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.notify_warranty_covered_after_insert() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.notify_warranty_covered_after_insert() FROM PUBLIC;
