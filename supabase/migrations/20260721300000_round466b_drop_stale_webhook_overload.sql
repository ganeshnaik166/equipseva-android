-- Round 466b — drop stale 5-arg overload of record_engineer_payout_webhook.
--
-- Background: round 466 added a 6-arg variant of the webhook RPC (added
-- p_failure_reason as last param, default NULL) but Postgres kept the
-- prior 5-arg overload alongside, since CREATE OR REPLACE only replaces
-- by exact-arity match. Callers that passed 5 args (the payouts-webhook
-- edge fn) silently routed to the OLD 5-arg body — meaning the round-466
-- forward-only-guard relaxation was actually inert in prod.
--
-- Caught during device E2E. Fix: drop the 5-arg variant. The 6-arg
-- variant accepts the same call shape via DEFAULT NULL on the new param.

DROP FUNCTION IF EXISTS public.record_engineer_payout_webhook(text, text, text, text, text);
