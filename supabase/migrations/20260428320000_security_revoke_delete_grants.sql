-- DELETE grant on every core table was inherited from the default
-- "GRANT ALL" pattern. RLS blocks DELETE today because none of these
-- tables have a DELETE policy, but the grant itself is tinder — a
-- single careless `CREATE POLICY … FOR DELETE TO authenticated USING
-- (true)` would unlock the entire table to client-side DELETEs.
--
-- Account deletion routes through delete_my_account SECURITY DEFINER
-- RPC; chat delete through delete_my_chat_message DEFINER; KYC docs
-- via storage.objects; everything else is admin-only via the founder
-- queue or simply tombstones via deleted_at columns. No client-side
-- DELETE path is legitimate today.
--
-- Sweep REVOKE so any future "let me add a quick DELETE policy" mistake
-- still fails the privilege check at the table level. service_role
-- bypass keeps the admin RPCs working.

REVOKE DELETE ON public.profiles FROM authenticated, anon;
REVOKE DELETE ON public.engineers FROM authenticated, anon;
REVOKE DELETE ON public.organizations FROM authenticated, anon;
REVOKE DELETE ON public.repair_jobs FROM authenticated, anon;
REVOKE DELETE ON public.repair_job_bids FROM authenticated, anon;
REVOKE DELETE ON public.chat_messages FROM authenticated, anon;
REVOKE DELETE ON public.chat_conversations FROM authenticated, anon;
REVOKE DELETE ON public.notifications FROM authenticated, anon;
REVOKE DELETE ON public.bank_accounts FROM authenticated, anon;
REVOKE DELETE ON public.payments FROM authenticated, anon;
REVOKE DELETE ON public.content_reports FROM authenticated, anon;
REVOKE DELETE ON public.buyer_kyc_verifications FROM authenticated, anon;
REVOKE DELETE ON public.device_tokens FROM authenticated, anon;
