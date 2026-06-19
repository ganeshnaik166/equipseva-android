BEGIN;

-- =====================================================================
-- Round 1213 — founder_chat_moderation_summary
-- =====================================================================
-- Chat / moderation domain has been untouched by the founder console.
-- chat_message_moderation_events is populated by the PII-mask trigger
-- (PR-D46 + round 264 + 241). Each row = an attempted leak of
-- phone / email / Aadhaar / PAN; original_excerpt is sensitive (DPDP).
-- This RPC aggregates volume + safety signals so founder can monitor
-- chat health without ever SELECTing the row bodies.
--
-- 12 KPIs (today + 7d + 30d windows, IST day boundary):
--   1.  messages_today                  — total chat_messages today
--   2.  messages_7d                     — 7-day volume
--   3.  messages_30d                    — 30-day volume
--   4.  active_conversations_today      — distinct conversation_id today
--   5.  active_senders_today            — distinct sender_user_id today
--   6.  deleted_today                   — soft-deleted today (regret signal)
--   7.  pii_attempts_today              — moderation events today
--   8.  pii_attempts_7d                 — moderation events 7d
--   9.  pii_attempts_30d                — moderation events 30d
--   10. pii_phone_attempts_30d          — 'phone' in matched_kinds 30d
--   11. pii_email_attempts_30d          — 'email' in matched_kinds 30d
--   12. repeat_offenders_30d            — senders with >=3 events 30d
--
-- Every column ref below is verified against:
--   migrations/20260424113451_chat_message_soft_delete.sql
--   migrations/20260621100000_v21_chat_mask_phone_unique_bid_verified.sql
--   migrations/20260625100000_v21_chat_conversations_last_message_mask.sql
--   migrations/20260803000000_round484_chat_rate_limit_and_archive.sql
--
-- IMPORTANT: we never project original_excerpt. Only counts + kinds.

DROP FUNCTION IF EXISTS public.founder_chat_moderation_summary();

CREATE OR REPLACE FUNCTION public.founder_chat_moderation_summary()
RETURNS TABLE (
  messages_today              bigint,
  messages_7d                 bigint,
  messages_30d                bigint,
  active_conversations_today  bigint,
  active_senders_today        bigint,
  deleted_today               bigint,
  pii_attempts_today          bigint,
  pii_attempts_7d             bigint,
  pii_attempts_30d            bigint,
  pii_phone_attempts_30d      bigint,
  pii_email_attempts_30d      bigint,
  repeat_offenders_30d        bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_today_end   timestamptz := v_today_start + interval '1 day';
  v_7d_start    timestamptz := v_today_end - interval '7 days';
  v_30d_start   timestamptz := v_today_end - interval '30 days';
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    -- 1. messages_today
    (SELECT count(*)::bigint
       FROM public.chat_messages
      WHERE created_at >= v_today_start
        AND created_at <  v_today_end),
    -- 2. messages_7d
    (SELECT count(*)::bigint
       FROM public.chat_messages
      WHERE created_at >= v_7d_start
        AND created_at <  v_today_end),
    -- 3. messages_30d
    (SELECT count(*)::bigint
       FROM public.chat_messages
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end),
    -- 4. active_conversations_today
    (SELECT count(DISTINCT conversation_id)::bigint
       FROM public.chat_messages
      WHERE created_at >= v_today_start
        AND created_at <  v_today_end),
    -- 5. active_senders_today
    (SELECT count(DISTINCT sender_user_id)::bigint
       FROM public.chat_messages
      WHERE created_at >= v_today_start
        AND created_at <  v_today_end
        AND sender_user_id IS NOT NULL),
    -- 6. deleted_today (soft deletes happening on messages today)
    (SELECT count(*)::bigint
       FROM public.chat_messages
      WHERE deleted_at IS NOT NULL
        AND deleted_at >= v_today_start
        AND deleted_at <  v_today_end),
    -- 7. pii_attempts_today
    (SELECT count(*)::bigint
       FROM public.chat_message_moderation_events
      WHERE created_at >= v_today_start
        AND created_at <  v_today_end),
    -- 8. pii_attempts_7d
    (SELECT count(*)::bigint
       FROM public.chat_message_moderation_events
      WHERE created_at >= v_7d_start
        AND created_at <  v_today_end),
    -- 9. pii_attempts_30d
    (SELECT count(*)::bigint
       FROM public.chat_message_moderation_events
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end),
    -- 10. pii_phone_attempts_30d
    (SELECT count(*)::bigint
       FROM public.chat_message_moderation_events
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end
        AND 'phone' = ANY(matched_kinds)),
    -- 11. pii_email_attempts_30d
    (SELECT count(*)::bigint
       FROM public.chat_message_moderation_events
      WHERE created_at >= v_30d_start
        AND created_at <  v_today_end
        AND 'email' = ANY(matched_kinds)),
    -- 12. repeat_offenders_30d (sender with >=3 PII events in 30d)
    (SELECT count(*)::bigint FROM (
       SELECT sender_user_id
         FROM public.chat_message_moderation_events
        WHERE created_at >= v_30d_start
          AND created_at <  v_today_end
          AND sender_user_id IS NOT NULL
        GROUP BY sender_user_id
       HAVING count(*) >= 3
     ) ro);
END;
$$;

ALTER FUNCTION public.founder_chat_moderation_summary() OWNER TO postgres;
REVOKE EXECUTE ON FUNCTION public.founder_chat_moderation_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_chat_moderation_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_chat_moderation_summary() IS
  'Round 1213 — founder chat / moderation 12-KPI snapshot. Aggregates volume + PII-leak attempts from chat_message_moderation_events without ever projecting original_excerpt (DPDP). Founder-only via is_founder() guard.';

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition assertion
-- ---------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'founder_chat_moderation_summary'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'round 1213: founder_chat_moderation_summary not installed';
  END IF;
  RAISE NOTICE 'round 1213 chat moderation summary fn installed';
END;
$$;
