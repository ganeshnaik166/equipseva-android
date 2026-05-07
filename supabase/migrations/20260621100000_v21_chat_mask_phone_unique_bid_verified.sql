-- v2.1 PR-D46 — close 3 HIGH-severity holes from the 2026-05-07 audit:
--
-- (a) Off-platform leak via chat (#4): no regex strip on chat_messages.
--     A hospital + colluding engineer could swap WhatsApp / phone numbers
--     in chat to take subsequent jobs off-platform. BEFORE-INSERT trigger
--     masks 10-digit Indian mobiles + email addresses with a friendly
--     swap-marker and writes an audit row to chat_message_moderation_events
--     (admin/founder-readable only).
--
-- (b) profiles.phone uniqueness (#5): banned engineer can re-register the
--     same phone with a fresh email. Unique partial index on
--     profiles(phone) WHERE phone IS NOT NULL. Existing duplicates are
--     deduped first — keep one row per phone (verified + earliest), NULL
--     out others so they can re-add a different number.
--
-- (c) repair_job_bids INSERT verified-engineer gate (#6): the existing
--     INSERT policy on the table only checks engineer_user_id = auth.uid().
--     An unverified engineer (verification_status != 'verified') can still
--     submit bids — they're hidden from the engineers directory but the
--     bid lands and a hospital sees it. WITH CHECK now also requires the
--     caller's `engineers` row to be verified.

-- ---------- (a) chat phone/email leak filter ----------------------------

CREATE TABLE IF NOT EXISTS public.chat_message_moderation_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid,
  sender_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  -- First 200 chars of the original (pre-masking) message body so ops
  -- can see what was attempted. Sensitive — RLS gates to admin/founder.
  original_excerpt text,
  matched_kinds text[] NOT NULL,
  masked_count int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_message_moderation_events_sender_created
  ON public.chat_message_moderation_events (sender_user_id, created_at DESC);

ALTER TABLE public.chat_message_moderation_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_moderation_admin_select
  ON public.chat_message_moderation_events;
CREATE POLICY chat_moderation_admin_select
  ON public.chat_message_moderation_events
  FOR SELECT
  TO authenticated
  USING (public.is_admin(auth.uid()) OR public.is_founder());

REVOKE INSERT, UPDATE, DELETE
  ON public.chat_message_moderation_events
  FROM authenticated, anon, public;

CREATE OR REPLACE FUNCTION public.chat_messages_mask_pii()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  -- Indian mobiles: optional +91 / 91 / 0 prefix, then [6-9] + 9 digits.
  -- Allows soft separators (space/dash) between the prefix and number,
  -- but not WITHIN the 10-digit body — keeps false-positive rate low.
  v_phone_re constant text := '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';
  -- Email: standard local@domain.tld with safe-char allowlist.
  v_email_re constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_replacement constant text := '[contact removed — keep on EquipSeva]';

  v_orig text;
  v_masked text;
  v_kinds text[] := ARRAY[]::text[];
  v_count int := 0;
  v_phone_hits int := 0;
  v_email_hits int := 0;
BEGIN
  v_orig := COALESCE(NEW.message, '');
  IF v_orig = '' THEN RETURN NEW; END IF;
  v_masked := v_orig;

  -- Phone pass.
  SELECT COALESCE(array_length(regexp_matches(v_masked, v_phone_re, 'g'), 1), 0)
    INTO v_phone_hits;
  -- regexp_matches returns one row per match; the SELECT above isn't
  -- aggregating right. Use the array form via regexp_replace count:
  -- count occurrences by replacing-and-counting length delta would be
  -- noisy. Simpler: split-on-match cardinality.
  SELECT count(*) INTO v_phone_hits
    FROM regexp_matches(v_masked, v_phone_re, 'g');
  IF v_phone_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_phone_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'phone');
    v_count := v_count + v_phone_hits;
  END IF;

  -- Email pass — run AFTER phone replacement so the marker text doesn't
  -- accidentally match an email pattern.
  SELECT count(*) INTO v_email_hits
    FROM regexp_matches(v_masked, v_email_re, 'g');
  IF v_email_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_email_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'email');
    v_count := v_count + v_email_hits;
  END IF;

  IF v_count > 0 THEN
    NEW.message := v_masked;
    -- Audit. Best-effort — if the parent INSERT subsequently fails (RLS
    -- reject etc), this row stays as a "tried to leak" signal which is
    -- still useful for ops review.
    INSERT INTO public.chat_message_moderation_events (
      conversation_id, sender_user_id, original_excerpt, matched_kinds, masked_count
    ) VALUES (
      NEW.conversation_id,
      NEW.sender_user_id,
      LEFT(v_orig, 200),
      v_kinds,
      v_count
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_messages_mask_pii_trg ON public.chat_messages;
CREATE TRIGGER chat_messages_mask_pii_trg
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_messages_mask_pii();

REVOKE ALL ON FUNCTION public.chat_messages_mask_pii() FROM PUBLIC;

COMMENT ON FUNCTION public.chat_messages_mask_pii() IS
  'PR-D46 — strip phone numbers + emails from chat_messages.message on '
  'INSERT and audit attempted leaks to chat_message_moderation_events. '
  'Edit-path moderation deferred — chat_message_edit RPCs go through '
  'separate functions (20260424121050) and would need a sister trigger.';

-- ---------- (b) profiles.phone uniqueness ------------------------------

-- Dedupe: for any phone with >1 owner, keep the row that is verified +
-- has the earliest created_at; NULL out the others. They can add a
-- different number later. Wrapped so the unique-index step below can't
-- fail at migration time.
WITH ranked AS (
  SELECT id,
         phone,
         row_number() OVER (
           PARTITION BY phone
           ORDER BY phone_verified DESC NULLS LAST,
                    created_at ASC NULLS LAST,
                    id ASC
         ) AS rn
    FROM public.profiles
   WHERE phone IS NOT NULL
)
UPDATE public.profiles
   SET phone = NULL,
       phone_verified = false
  FROM ranked
 WHERE profiles.id = ranked.id
   AND ranked.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_unique
  ON public.profiles (phone)
  WHERE phone IS NOT NULL;

COMMENT ON INDEX public.profiles_phone_unique IS
  'PR-D46 — banned-account rotation defence. A user whose account is '
  'suspended cannot re-register the same phone with a fresh email; '
  'they must use a different number. Pre-existing duplicates were '
  'deduped (verified + earliest kept) at migration time.';

-- ---------- (c) repair_job_bids verified-engineer INSERT gate ----------

-- We don't know the original INSERT policy name (the table predates the
-- migration directory's full coverage). Drop common candidates so the
-- new one wins. ALTER POLICY would be cleaner but requires the exact
-- name to exist; DROP+CREATE is safer for migration idempotency.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT polname FROM pg_policy p
      JOIN pg_class c ON c.oid = p.polrelid
     WHERE c.relname = 'repair_job_bids'
       AND p.polcmd = 'a'  -- 'a' = INSERT
  LOOP
    EXECUTE format('DROP POLICY %I ON public.repair_job_bids', r.polname);
  END LOOP;
END$$;

-- Ensure RLS is on (no-op if already enabled).
ALTER TABLE public.repair_job_bids ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Verified engineers insert own bid"
  ON public.repair_job_bids
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = engineer_user_id
    AND EXISTS (
      SELECT 1
        FROM public.engineers e
       WHERE e.user_id = auth.uid()
         AND e.verification_status = 'verified'
    )
  );

COMMENT ON POLICY "Verified engineers insert own bid" ON public.repair_job_bids IS
  'PR-D46 — only KYC-verified engineers can submit bids. Without this '
  'gate the engineers directory hides unverified rows but raw REST INSERT '
  'still landed bids that hospitals could see + accept.';
