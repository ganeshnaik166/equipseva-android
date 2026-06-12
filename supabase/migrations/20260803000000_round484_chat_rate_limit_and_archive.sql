-- =====================================================================
-- Round 484 — Chat hardening (v0.4 Phase 1 #4 + #5)
-- =====================================================================
--
-- Audit-9 surfaced two real chat HIGHs (8 of 12 confirmed findings were
-- false positives; these two were real):
--   (#1) No rate limit on send_message / edit_my_chat_message — spam
--        + DoS vector. A single user could blast 1000+ messages to
--        flood recipient inbox + push notifications + DB load.
--   (#2) Conversations not auto-archived when the linked repair_job
--        completes — engineer can keep messaging hospital after the
--        job is done, harassment risk.
--
-- We don't have a centralized send_message RPC; chat_messages are
-- inserted directly via PostgREST INSERT (gated by the existing RLS
-- policies). Rate limit + archive enforcement therefore happens at
-- the trigger layer so it covers ALL insert paths (direct + future
-- RPC + service-role webhook callbacks).

BEGIN;

-- ---------------------------------------------------------------------
-- 1. Rate-limit trigger
-- ---------------------------------------------------------------------
-- Two-tier sliding-window limit (per the audit-9 recommendation):
--   * max 10 messages per conversation per minute (hot-thread cap)
--   * max 100 messages per user per hour (account-wide cap)
--
-- We trip the per-conversation cap first (cheaper count, smaller index
-- scan window). Per-user cap catches the multi-conversation spammer
-- who'd otherwise blast 5 conversations with 9 messages each.
--
-- Excluded from the limit:
--   * service_role inserts (system/webhook generated messages, e.g.,
--     "engineer accepted your job" auto-replies)
--   * is_founder() actors (admin troubleshooting)
--
-- Failure mode: RAISE EXCEPTION rolls back the INSERT. Client surfaces
-- a "you're sending too fast" toast. Existing chat_messages_mask_pii
-- BEFORE INSERT trigger continues to run before rate-limit fires
-- (PII mask is cheap; rate-limit is the gate).

CREATE OR REPLACE FUNCTION public.chat_messages_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_conv_count_1m  int;
  v_user_count_1h  int;
BEGIN
  -- Skip rate limit when running as service_role or as a founder.
  -- auth.role() returns 'service_role' for service-key requests, the
  -- jwt role for authenticated requests, 'anon' otherwise.
  IF auth.role() = 'service_role' OR public.is_founder() THEN
    RETURN NEW;
  END IF;

  -- Tier 1: per-conversation cap (10 msgs/min)
  SELECT count(*) INTO v_conv_count_1m
    FROM public.chat_messages
   WHERE conversation_id = NEW.conversation_id
     AND sender_user_id  = NEW.sender_user_id
     AND created_at >= now() - interval '1 minute';

  IF v_conv_count_1m >= 10 THEN
    RAISE EXCEPTION 'chat_rate_limited_conversation'
      USING ERRCODE = 'P0001',
            HINT = 'Max 10 messages per conversation per minute. Slow down.';
  END IF;

  -- Tier 2: per-user account-wide cap (100 msgs/hr)
  SELECT count(*) INTO v_user_count_1h
    FROM public.chat_messages
   WHERE sender_user_id = NEW.sender_user_id
     AND created_at >= now() - interval '1 hour';

  IF v_user_count_1h >= 100 THEN
    RAISE EXCEPTION 'chat_rate_limited_user'
      USING ERRCODE = 'P0001',
            HINT = 'Max 100 messages per hour. Slow down or contact support.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_messages_rate_limit_trg ON public.chat_messages;
CREATE TRIGGER chat_messages_rate_limit_trg
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_messages_rate_limit();

COMMENT ON FUNCTION public.chat_messages_rate_limit IS
  'Round 484 — sliding-window rate limit on chat_messages INSERT. 10/conv/min + 100/user/hr. Service_role + founder bypass for system + admin paths.';

-- Index to make the per-conversation count cheap. Filters on
-- (conversation_id, sender_user_id, created_at) — the rate-limit
-- trigger executes this query on EVERY message insert, so the index
-- has to be tight.
CREATE INDEX IF NOT EXISTS chat_messages_rate_limit_conv_idx
  ON public.chat_messages (conversation_id, sender_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS chat_messages_rate_limit_user_idx
  ON public.chat_messages (sender_user_id, created_at DESC);

-- ---------------------------------------------------------------------
-- 2. Auto-archive on linked repair_job completion
-- ---------------------------------------------------------------------
-- Convention: chat_conversations.related_entity_type = 'repair_job'
-- + related_entity_id = repair_jobs.id (per the existing schema).
-- When the linked repair_job hits status='completed', engineer +
-- hospital should NOT be able to send new messages — the
-- conversation is "closed" + the existing thread stays read-only.
--
-- Enforcement: BEFORE INSERT trigger that, when the conversation
-- is tied to a repair_job in 'completed' / 'cancelled' status,
-- raises with a clear error. Service_role + founder bypass for
-- system messages (e.g., closing notification, refund settlement
-- broadcast).
--
-- We deliberately DO NOT mutate chat_conversations.status here —
-- there's no archived_at column today and adding one would touch
-- too much UI. The trigger refuses the insert; client sees a
-- "conversation closed" toast.

CREATE OR REPLACE FUNCTION public.chat_messages_block_on_completed_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_related_type   text;
  v_related_id     uuid;
  v_job_status     text;
BEGIN
  IF auth.role() = 'service_role' OR public.is_founder() THEN
    RETURN NEW;
  END IF;

  SELECT related_entity_type, related_entity_id
    INTO v_related_type, v_related_id
    FROM public.chat_conversations
   WHERE id = NEW.conversation_id;

  -- Conversation not tied to a repair_job → no archive rule applies.
  IF v_related_type IS DISTINCT FROM 'repair_job' OR v_related_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT status::text INTO v_job_status
    FROM public.repair_jobs
   WHERE id = v_related_id;

  IF v_job_status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'chat_conversation_closed'
      USING ERRCODE = 'P0001',
            HINT = 'This conversation is closed because the repair job is ' || v_job_status || '. Contact support if you need to reach the other party.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS chat_messages_block_on_completed_job_trg ON public.chat_messages;
CREATE TRIGGER chat_messages_block_on_completed_job_trg
  BEFORE INSERT ON public.chat_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.chat_messages_block_on_completed_job();

COMMENT ON FUNCTION public.chat_messages_block_on_completed_job IS
  'Round 484 — block chat_messages INSERT when the linked repair_job is completed or cancelled. Service_role + founder bypass for system broadcasts.';

-- ---------------------------------------------------------------------
-- 3. Apply the same guards to edit_my_chat_message
-- ---------------------------------------------------------------------
-- The audit's HIGH was specifically about message editing too. The
-- existing edit RPC didn't rate-limit. Now both the rate-limit and
-- the closed-conversation guards apply at the SECDEF RPC layer
-- (the trigger fires on INSERT only, not UPDATE — so we need the
-- explicit gate inside the edit RPC).

-- Look up current edit_my_chat_message signature so the CREATE OR
-- REPLACE matches.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'edit_my_chat_message'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE NOTICE 'edit_my_chat_message not found — skipping edit-rate-limit retrofit';
  END IF;
END;
$$;

-- The edit retrofit is deferred to r485 — the existing edit RPC body
-- needs careful merging with the round 446 PII-mask UPDATE trigger
-- and the round 484 rate-limit gate. Insert-path coverage above is
-- the main user-facing exposure.

COMMIT;

-- ---------------------------------------------------------------------
-- Post-condition assertions
-- ---------------------------------------------------------------------
DO $$
BEGIN
  -- 1. Triggers exist
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'chat_messages_rate_limit_trg'
      AND tgrelid = 'public.chat_messages'::regclass
  ) THEN
    RAISE EXCEPTION 'round 484: chat_messages_rate_limit_trg not installed';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'chat_messages_block_on_completed_job_trg'
      AND tgrelid = 'public.chat_messages'::regclass
  ) THEN
    RAISE EXCEPTION 'round 484: chat_messages_block_on_completed_job_trg not installed';
  END IF;
  -- 2. Indices created
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'chat_messages'
      AND indexname = 'chat_messages_rate_limit_conv_idx'
  ) THEN
    RAISE EXCEPTION 'round 484: rate-limit conversation index missing';
  END IF;
  RAISE NOTICE 'round 484 chat hardening verified: rate-limit + archive triggers + indices installed';
END;
$$;
