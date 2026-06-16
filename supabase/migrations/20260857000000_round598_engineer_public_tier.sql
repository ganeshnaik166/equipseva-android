-- =====================================================================
-- Round 598 — Public engineer tier label (hospital-facing badge)
-- =====================================================================
--
-- engineer_certification_progress is RLS-scoped to (own row OR founder),
-- so hospitals browsing engineer profiles can't read others' tiers.
-- That means the cert ladder (r550) is invisible at the moment of
-- choice — the place where it matters most for hospital trust.
--
-- r598 plants a thin SECDEF RPC that exposes ONLY the public tier
-- label (not jobs_completed / dispute_rate / supervised_completions
-- which are confidential signals). Hospitals call this when rendering
-- engineer profile cards; engineers' own private metrics stay locked.
--
-- Returns NULL when the engineer has no progress row (cold-start,
-- never been computed) — caller renders no badge in that case.

BEGIN;

DROP FUNCTION IF EXISTS public.engineer_public_tier_label(uuid);

CREATE OR REPLACE FUNCTION public.engineer_public_tier_label(
  p_engineer_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tier text;
BEGIN
  -- No auth.uid() gate — this is intentionally public-readable info
  -- (it's a "badge" — the engineer's PUBLIC tier). Anon callers
  -- (search engines, public profile previews) get the same answer.
  SELECT p.current_tier
    INTO v_tier
    FROM public.engineer_certification_progress p
    JOIN public.engineers e ON e.user_id = p.engineer_user_id
   WHERE e.id = p_engineer_id;

  -- 'none' tier is treated as "no badge" — only bronze/silver/gold
  -- are interesting public signals. None means the engineer hasn't
  -- earned a tier yet (or was demoted to floor).
  IF v_tier IS NULL OR v_tier = 'none' THEN
    RETURN NULL;
  END IF;

  RETURN v_tier;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.engineer_public_tier_label(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.engineer_public_tier_label(uuid) TO anon, authenticated;

COMMENT ON FUNCTION public.engineer_public_tier_label(uuid) IS
  'r598: engineer cert tier as a public badge label. Returns bronze/silver/gold or NULL (no badge for none-tier or missing progress).';

COMMIT;
