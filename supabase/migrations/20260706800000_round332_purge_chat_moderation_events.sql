-- Round 332 — TTL purge for chat_message_moderation_events.
--
-- The table is populated by the chat-PII masking trigger (round 264
-- + 245 + 688). It records every message where the user attempted
-- to share Aadhaar / PAN / phone / email, including the first 200
-- chars of the PRE-MASKING body in `original_excerpt`.
--
-- DPDP angle: `original_excerpt` is exactly the sensitive data the
-- masking layer was supposed to protect. Storing it indefinitely
-- defeats the redaction. Keep events for 90 days for ops triage
-- (matches retention of purge_old_notifications) then drop.
--
-- Sibling fixes in this lineage:
--   * round 304 — purge_old_phone_otp_requests
--   * round 322 — expire_lapsed_amc_contracts
--   * round 323 — purge_old_spot_audit_invitations

CREATE OR REPLACE FUNCTION public.purge_old_chat_moderation_events()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_deleted int := 0;
BEGIN
  WITH purged AS (
    DELETE FROM public.chat_message_moderation_events
     WHERE created_at < now() - interval '90 days'
    RETURNING 1
  )
  SELECT count(*) INTO v_deleted FROM purged;
  RETURN v_deleted;
END;
$$;

ALTER FUNCTION public.purge_old_chat_moderation_events() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.purge_old_chat_moderation_events() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_old_chat_moderation_events() TO service_role;

COMMENT ON FUNCTION public.purge_old_chat_moderation_events() IS
  'Round 332 — drop chat_message_moderation_events older than 90 days. '
  'Their original_excerpt field carries the pre-masking PII the user '
  'attempted to share; longer retention defeats the redaction. Daily '
  'cron via cron-tick.';
