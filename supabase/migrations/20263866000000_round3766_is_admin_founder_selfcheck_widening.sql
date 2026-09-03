-- Round 3766 — is_admin(auth.uid()) has never actually granted the founder
-- admin-level RLS visibility, across the ENTIRE schema, because is_admin()
-- checks profiles.role = 'admin' and the founder's own profiles.role is
-- 'hospital_admin' (their real, day-to-day operating role — is_founder()
-- is deliberately the email-pinned, role-independent identity check, per
-- round335's admin_force_role_change comment: "profiles.role doesn't gate
-- founder access").
--
-- Found while adding a "cost revisions" section to the founder web
-- console's job-detail page (web/src/app/jobs/[id]/page.tsx) and noticing
-- repair_job_cost_revisions' RLS has NO admin/founder bypass at all.
-- Pulling on that thread: confirmed live that the founder's own
-- RLS-bound session (getSupabaseServerClient() — anon key + session
-- cookie, NOT service-role; requireFounder()'s own comment says so:
-- "Treat the env-var as the SOFT gate. The HARD gate is is_founder()
-- inside each RPC") can see only 28 of 39 real repair_jobs rows —
-- ALL 7 completed jobs, the 1 assigned job, and the 1 in_progress job
-- are invisible; only 'requested' (via a side-channel — the founder
-- happens to also carry a personal `engineers` row) and 2 of 4
-- cancelled jobs are visible. The web console's /jobs and /jobs/[id]
-- pages are the two confirmed-affected pages (grepped web/src for every
-- table with this pattern; only these two do a raw `.from()` read
-- instead of going through a founder-safe SECURITY DEFINER RPC).
--
-- The gap is much wider than those two pages: confirmed via
-- pg_policies that EVERY policy in the schema calling is_admin(...) does
-- so exclusively as is_admin(auth.uid()) — a self-check, never a
-- third-party check (32 occurrences across function bodies, all via a
-- v_caller uuid := auth.uid() local; 0 policies pass any other
-- argument). That means widening is_admin(uuid) to ALSO return true
-- when (uid = auth.uid() AND is_founder()) is a fully safe, purely
-- additive fix for every single call site in one shot — it cannot
-- change the answer for "is some OTHER user an admin" (that path is
-- never exercised), only "does the calling user have admin rights",
-- which is exactly what every one of these call sites actually means.
--
-- Most of the ~30 tables gated by is_admin() were never actually
-- broken in practice — the web/founder console overwhelmingly reads
-- through SECURITY DEFINER RPCs (which already call is_founder()
-- directly and bypass table RLS as the function owner), not raw table
-- reads. This fix closes the gap everywhere at once rather than
-- leaving it latent for the next page that reads a table directly —
-- same defensive standard as round3763/round3765 this session.
--
-- Separately (not fixed by the is_admin() widening, since these 5
-- policies bypass the function entirely and inline the stale
-- profiles.role='admin' check directly): engineer_payout_methods,
-- engineer_payouts, equipment, repair_job_bids, repair_jobs. Rewritten
-- below to route through is_admin(auth.uid()) instead of duplicating
-- the broken inline check — one source of truth going forward.
--
-- Also: repair_job_cost_revisions had ZERO admin/founder SELECT
-- bypass of any kind (participant-only). Added.
BEGIN;

-- ---------------------------------------------------------------------
-- 1. is_admin(uuid) — additive founder self-check widening.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin(uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = uid AND role = 'admin'
  )
  -- Round 3766: every real call site checks the CALLING user's own
  -- privilege (is_admin(auth.uid())) — confirmed via a full-schema
  -- scan of pg_policies + every function body, 0 third-party calls
  -- exist. Scoping the OR to `uid = auth.uid()` means this can only
  -- ever widen a self-check, never answer "is some other user an
  -- admin" incorrectly.
  OR (uid = auth.uid() AND public.is_founder());
$$;

COMMENT ON FUNCTION public.is_admin(uuid) IS
  'Round 3766 — now also true when checking the CALLING user''s own id and that user is the founder (profiles.role alone never carries founder status — the founder''s real operating role is hospital_admin, not admin). Safe: every call site in the schema passes auth.uid()/v_caller (itself auth.uid()), never a third party''s id.';

-- ---------------------------------------------------------------------
-- 2. Policies that inlined the stale profiles.role='admin' check
--    directly instead of calling is_admin() — route through the fixed
--    function so there's one source of truth.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS epm_select_admin ON public.engineer_payout_methods;
CREATE POLICY epm_select_admin ON public.engineer_payout_methods
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS ep_select_admin ON public.engineer_payouts;
CREATE POLICY ep_select_admin ON public.engineer_payouts
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Equipment viewable by org members" ON public.equipment;
CREATE POLICY "Equipment viewable by org members" ON public.equipment
  FOR SELECT
  USING (
    organization_id IN (SELECT profiles.organization_id FROM public.profiles WHERE profiles.id = auth.uid())
    OR public.is_admin(auth.uid())
  );

DROP POLICY IF EXISTS "Admin sees all repair bids" ON public.repair_job_bids;
CREATE POLICY "Admin sees all repair bids" ON public.repair_job_bids
  FOR SELECT
  USING (public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "Repair jobs viewable by involved parties" ON public.repair_jobs;
CREATE POLICY "Repair jobs viewable by involved parties" ON public.repair_jobs
  FOR SELECT
  USING (
    auth.uid() = hospital_user_id
    OR auth.uid() IN (SELECT engineers.user_id FROM public.engineers WHERE engineers.id = repair_jobs.engineer_id)
    OR public.is_admin(auth.uid())
  );

-- ---------------------------------------------------------------------
-- 3. repair_job_cost_revisions — had NO admin/founder SELECT bypass at
--    all (participant-only). Add one, same shape as every sibling
--    escrow/dispute table.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS repair_job_cost_revisions_select_admin ON public.repair_job_cost_revisions;
CREATE POLICY repair_job_cost_revisions_select_admin ON public.repair_job_cost_revisions
  FOR SELECT TO authenticated
  USING (public.is_admin(auth.uid()));

COMMIT;
