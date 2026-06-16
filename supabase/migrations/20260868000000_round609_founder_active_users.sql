-- =====================================================================
-- Round 609 — Founder active-users (DAU/WAU/MAU) view
-- =====================================================================
--
-- We track signups (r608) but not "how many of those signed in today?"
-- Active-user counts let the founder spot stickiness drops (a churn
-- signal) and shipping wins (a new feature lifts DAU). Reads auth.
-- users.last_sign_in_at across 1d / 7d / 30d windows, broken out by
-- role.

BEGIN;

DROP FUNCTION IF EXISTS public.founder_active_users();

CREATE OR REPLACE FUNCTION public.founder_active_users()
RETURNS TABLE (
  window_label  text,
  total_users   bigint,
  hospitals     bigint,
  engineers     bigint,
  ratio_pct     numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      u.id,
      u.last_sign_in_at,
      coalesce(lower(p.role::text), 'unknown') AS role
    FROM auth.users u
    LEFT JOIN public.profiles p ON p.id = u.id
    WHERE u.last_sign_in_at IS NOT NULL
  ),
  windows(w_label, w_interval, w_ord) AS (
    VALUES
      ('DAU', interval '1 day', 1),
      ('WAU', interval '7 days', 2),
      ('MAU', interval '30 days', 3)
  ),
  totals AS (
    SELECT count(*)::bigint AS total_registered
    FROM auth.users
  )
  SELECT
    w.w_label                                                  AS window_label,
    (SELECT count(*)::bigint
       FROM base b WHERE b.last_sign_in_at >= v_now - w.w_interval)
                                                               AS total_users,
    (SELECT count(*)::bigint
       FROM base b
      WHERE b.last_sign_in_at >= v_now - w.w_interval
        AND b.role = 'hospital')                               AS hospitals,
    (SELECT count(*)::bigint
       FROM base b
      WHERE b.last_sign_in_at >= v_now - w.w_interval
        AND b.role = 'engineer')                               AS engineers,
    CASE
      WHEN (SELECT total_registered FROM totals) = 0 THEN 0::numeric
      ELSE round(
        (SELECT count(*) FROM base b
          WHERE b.last_sign_in_at >= v_now - w.w_interval)::numeric
        / (SELECT total_registered FROM totals)::numeric * 100.0,
        1
      )
    END                                                        AS ratio_pct
  FROM windows w
  ORDER BY w.w_ord;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_active_users() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_active_users() TO authenticated;

COMMIT;
