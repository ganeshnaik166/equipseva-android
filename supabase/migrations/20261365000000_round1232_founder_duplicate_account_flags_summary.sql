BEGIN;

-- Round 1232 — founder_duplicate_account_flags_summary
-- Single-row summary of public.duplicate_account_flags lifecycle + signal mix.
-- Read-only; founder/service_role only. Source table confirmed in r501.

CREATE OR REPLACE FUNCTION public.founder_duplicate_account_flags_summary()
RETURNS TABLE (
  -- Lifecycle
  total_flags                bigint,
  open_flags                 bigint,
  investigating_flags        bigint,
  confirmed_flags            bigint,
  false_positive_flags       bigint,
  resolved_flags             bigint,
  -- Severity (open + investigating only — the actionable queue)
  open_critical              bigint,
  open_high                  bigint,
  open_medium                bigint,
  open_low                   bigint,
  -- Signal mix across ALL flags
  shared_aadhaar_total       bigint,
  shared_pan_total           bigint,
  shared_phone_total         bigint,
  shared_phone_norm_total    bigint,
  shared_email_domain_total  bigint,
  name_fuzzy_total           bigint,
  shared_device_id_total     bigint,
  -- Confirmed-rate signal
  confirmed_rate_pct         numeric,
  -- Age of oldest open flag (operational SLA)
  oldest_open_age_days       int,
  -- Recency
  flags_last_7d              bigint,
  flags_last_30d             bigint,
  confirmed_last_30d         bigint,
  -- Snapshot timestamp
  snapshot_at                timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_now timestamptz := now();
BEGIN
  IF NOT (auth.role() = 'service_role' OR public.is_founder()) THEN
    RAISE EXCEPTION 'service_role or founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      d.status,
      d.severity,
      d.signal_kind,
      d.created_at
    FROM public.duplicate_account_flags d
  ),
  lifecycle AS (
    SELECT
      count(*)::bigint                                                           AS total_flags,
      count(*) FILTER (WHERE status = 'open')::bigint                            AS open_flags,
      count(*) FILTER (WHERE status = 'investigating')::bigint                   AS investigating_flags,
      count(*) FILTER (WHERE status = 'confirmed')::bigint                       AS confirmed_flags,
      count(*) FILTER (WHERE status = 'false_positive')::bigint                  AS false_positive_flags,
      count(*) FILTER (WHERE status = 'resolved')::bigint                        AS resolved_flags
    FROM base
  ),
  open_sev AS (
    SELECT
      count(*) FILTER (WHERE severity = 'critical')::bigint AS open_critical,
      count(*) FILTER (WHERE severity = 'high')::bigint     AS open_high,
      count(*) FILTER (WHERE severity = 'medium')::bigint   AS open_medium,
      count(*) FILTER (WHERE severity = 'low')::bigint      AS open_low
    FROM base
    WHERE status IN ('open','investigating')
  ),
  signals AS (
    SELECT
      count(*) FILTER (WHERE signal_kind = 'shared_aadhaar')::bigint          AS shared_aadhaar_total,
      count(*) FILTER (WHERE signal_kind = 'shared_pan')::bigint              AS shared_pan_total,
      count(*) FILTER (WHERE signal_kind = 'shared_phone')::bigint            AS shared_phone_total,
      count(*) FILTER (WHERE signal_kind = 'shared_phone_normalized')::bigint AS shared_phone_norm_total,
      count(*) FILTER (WHERE signal_kind = 'shared_email_domain')::bigint     AS shared_email_domain_total,
      count(*) FILTER (WHERE signal_kind = 'name_fuzzy_match')::bigint        AS name_fuzzy_total,
      count(*) FILTER (WHERE signal_kind = 'shared_device_id')::bigint        AS shared_device_id_total
    FROM base
  ),
  rates AS (
    SELECT
      CASE
        WHEN count(*) FILTER (WHERE status IN ('confirmed','false_positive')) = 0 THEN 0::numeric
        ELSE round(
          100.0 * count(*) FILTER (WHERE status = 'confirmed')::numeric
          / count(*) FILTER (WHERE status IN ('confirmed','false_positive'))::numeric,
          1
        )
      END AS confirmed_rate_pct
    FROM base
  ),
  age AS (
    SELECT
      COALESCE(
        EXTRACT(DAY FROM (v_now - min(created_at)))::int,
        0
      ) AS oldest_open_age_days
    FROM base
    WHERE status IN ('open','investigating')
  ),
  recency AS (
    SELECT
      count(*) FILTER (WHERE created_at >= v_now - interval '7 days')::bigint                                AS flags_last_7d,
      count(*) FILTER (WHERE created_at >= v_now - interval '30 days')::bigint                               AS flags_last_30d,
      count(*) FILTER (WHERE status = 'confirmed' AND created_at >= v_now - interval '30 days')::bigint      AS confirmed_last_30d
    FROM base
  )
  SELECT
    lifecycle.total_flags,
    lifecycle.open_flags,
    lifecycle.investigating_flags,
    lifecycle.confirmed_flags,
    lifecycle.false_positive_flags,
    lifecycle.resolved_flags,
    open_sev.open_critical,
    open_sev.open_high,
    open_sev.open_medium,
    open_sev.open_low,
    signals.shared_aadhaar_total,
    signals.shared_pan_total,
    signals.shared_phone_total,
    signals.shared_phone_norm_total,
    signals.shared_email_domain_total,
    signals.name_fuzzy_total,
    signals.shared_device_id_total,
    rates.confirmed_rate_pct,
    age.oldest_open_age_days,
    recency.flags_last_7d,
    recency.flags_last_30d,
    recency.confirmed_last_30d,
    v_now AS snapshot_at
  FROM lifecycle, open_sev, signals, rates, age, recency;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_duplicate_account_flags_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_duplicate_account_flags_summary() TO authenticated;

COMMENT ON FUNCTION public.founder_duplicate_account_flags_summary() IS
  'r1232 — single-row snapshot of duplicate_account_flags: lifecycle + severity + signal mix + recency. Founder/service_role only.';

COMMIT;
