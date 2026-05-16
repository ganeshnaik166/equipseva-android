-- Round 247 — atomic call_count increment for virtual_call_sessions reuse.
--
-- The request-call-session edge function's reuse branch does a
-- read-modify-write:
--     prevCount = SELECT call_count ...
--     UPDATE ... SET call_count = prevCount + 1
--
-- That's not race-safe. If a hospital double-taps the "Call engineer"
-- button while the previous bridge is still ringing, two concurrent
-- requests both read prevCount=N and both write N+1 — second write
-- wins, one increment lost. The metric drives the abuse-detection
-- index (virtual_call_sessions_call_count_idx) used by the founder
-- forensics dashboard, so under-counting masks the exact circumvention
-- pattern this table was built to surface.
--
-- Provide an atomic SECDEF RPC that does the increment in a single
-- UPDATE. Service-role only — the edge function is the only caller.
-- Returns the new call_count so the caller can echo it back to the
-- response if desired (current code doesn't, but kept for future).
--
-- Follow-up PR will swap the edge function read-modify-write for a
-- single `admin.rpc('bump_virtual_call_count', { p_session_id })`
-- once PR #687 (which lifted the `as any` casts) has merged.

CREATE OR REPLACE FUNCTION public.bump_virtual_call_count(
  p_session_id uuid
) RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_new_count int;
BEGIN
  UPDATE public.virtual_call_sessions
     SET call_count = COALESCE(call_count, 0) + 1,
         last_called_at = now()
   WHERE id = p_session_id
   RETURNING call_count INTO v_new_count;

  IF v_new_count IS NULL THEN
    RAISE EXCEPTION 'virtual_call_sessions row % not found', p_session_id
      USING ERRCODE = '02000';
  END IF;

  RETURN v_new_count;
END;
$$;

ALTER FUNCTION public.bump_virtual_call_count(uuid) OWNER TO postgres;
REVOKE ALL ON FUNCTION public.bump_virtual_call_count(uuid) FROM PUBLIC;
-- Service-role only. authenticated / anon must not be able to bump
-- the counter directly — would let any user inflate another user's
-- abuse-detection metric.
REVOKE ALL ON FUNCTION public.bump_virtual_call_count(uuid) FROM authenticated, anon;
GRANT EXECUTE ON FUNCTION public.bump_virtual_call_count(uuid) TO service_role;

COMMENT ON FUNCTION public.bump_virtual_call_count(uuid) IS
  'Round 247 — atomic SQL increment of virtual_call_sessions.call_count + bump '
  'last_called_at. Replaces the racy read-modify-write in the request-call-session '
  'edge function reuse branch. Service-role only.';
