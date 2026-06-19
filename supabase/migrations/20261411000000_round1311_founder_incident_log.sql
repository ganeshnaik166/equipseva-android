BEGIN;
-- r1311 — Founder incident log + auto-creation cron.
-- Every critical item that's been pending >24h in /founder-action-center
-- auto-creates an incident record. Founder resolves incidents (mark resolved
-- with root-cause note + post-mortem link).
--
-- This formalizes the "we had an outage / leak" narrative — incidents are
-- the historical record of every fire the founder put out.

CREATE TABLE IF NOT EXISTS public.founder_incidents (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_domain         text NOT NULL,         -- 'payouts' / 'code_red' / 'collusion' / ...
  source_item_id        uuid,                  -- if specific item; NULL for fleet-wide incidents
  title                 text NOT NULL,
  severity              text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  status                text NOT NULL DEFAULT 'open'
                          CHECK (status IN ('open','investigating','resolved','wont_fix','dupe')),
  opened_at             timestamptz NOT NULL DEFAULT now(),
  resolved_at           timestamptz,
  resolved_by           uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  root_cause_note       text,
  postmortem_url        text,
  auto_created          boolean NOT NULL DEFAULT false,
  created_by            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  -- Idempotency: prevent duplicate auto-incidents for same source item
  CONSTRAINT founder_incident_source_unique
    UNIQUE (source_domain, source_item_id)
);
COMMENT ON TABLE public.founder_incidents IS
  'Historical record of every founder incident. Auto-creates from /founder-action-center critical items >24h old.';

CREATE INDEX IF NOT EXISTS idx_founder_incidents_status ON public.founder_incidents (status, opened_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_incidents_severity ON public.founder_incidents (severity, opened_at DESC);

ALTER TABLE public.founder_incidents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_incidents_no_direct ON public.founder_incidents;
CREATE POLICY founder_incidents_no_direct ON public.founder_incidents FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_incidents FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Cron: founder_auto_create_incidents (runs hourly)
--   For every CRITICAL item in founder_action_center that's >24h old AND
--   hasn't been silenced as resolved, create an incident if one doesn't exist.
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_auto_create_incidents();
CREATE OR REPLACE FUNCTION public.founder_auto_create_incidents()
RETURNS TABLE (created_count int)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_created int := 0;
BEGIN
  -- Pull critical items >24h old from the action center
  WITH critical_items AS (
    SELECT * FROM public.founder_action_center(500) WHERE severity = 1 AND age_hours > 24
  ),
  inserted AS (
    INSERT INTO public.founder_incidents
      (source_domain, source_item_id, title, severity, auto_created, created_by)
    SELECT
      c.source_domain,
      c.item_id,
      c.label,
      CASE WHEN c.age_hours > 168 THEN 'p0'
           WHEN c.age_hours > 72  THEN 'p1'
           ELSE 'p2' END,
      true,
      NULL
    FROM critical_items c
    ON CONFLICT (source_domain, source_item_id) DO NOTHING
    RETURNING 1
  )
  SELECT count(*)::int INTO v_created FROM inserted;
  RETURN QUERY SELECT v_created;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_auto_create_incidents() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_auto_create_incidents() TO authenticated;

-- ============================================================================
-- founder_resolve_incident — mark incident resolved with root-cause
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_resolve_incident(uuid, text, text);
CREATE OR REPLACE FUNCTION public.founder_resolve_incident(
  p_incident_id   uuid,
  p_root_cause    text,
  p_postmortem    text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  UPDATE public.founder_incidents
  SET status = 'resolved',
      resolved_at = now(),
      resolved_by = auth.uid(),
      root_cause_note = p_root_cause,
      postmortem_url = p_postmortem
  WHERE id = p_incident_id AND status != 'resolved';
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_resolve_incident(uuid, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_resolve_incident(uuid, text, text) TO authenticated;

-- ============================================================================
-- founder_incidents_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_incidents_summary();
CREATE OR REPLACE FUNCTION public.founder_incidents_summary()
RETURNS TABLE (
  open_now            bigint,
  investigating_now   bigint,
  resolved_30d        bigint,
  opened_today        bigint,
  resolved_today      bigint,
  p0_open             bigint,
  p1_open             bigint,
  p2_open             bigint,
  p3_open             bigint,
  median_resolve_hrs  numeric,
  oldest_open_age_days int,
  resolution_rate_30d_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_today_start timestamptz := (now() AT TIME ZONE 'Asia/Kolkata')::date::timestamptz AT TIME ZONE 'Asia/Kolkata';
  v_opened_30d bigint;
  v_resolved_30d bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  SELECT count(*)::bigint INTO v_opened_30d FROM public.founder_incidents WHERE opened_at >= now() - interval '30 days';
  SELECT count(*)::bigint INTO v_resolved_30d FROM public.founder_incidents WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days';
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'open'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'investigating'), 0),
    v_resolved_30d,
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE opened_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'resolved' AND resolved_at >= v_today_start), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'open' AND severity = 'p0'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'open' AND severity = 'p1'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'open' AND severity = 'p2'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_incidents WHERE status = 'open' AND severity = 'p3'), 0),
    coalesce((SELECT round(avg(extract(epoch from (resolved_at - opened_at)) / 3600.0)::numeric, 1)
              FROM public.founder_incidents WHERE status = 'resolved' AND resolved_at >= now() - interval '30 days'), 0),
    coalesce((SELECT extract(day from (now() - min(opened_at)))::int FROM public.founder_incidents WHERE status IN ('open','investigating')), 0),
    CASE WHEN v_opened_30d = 0 THEN 0::numeric ELSE round(100.0 * v_resolved_30d / v_opened_30d, 1) END;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_incidents_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_incidents_summary() TO authenticated;

-- ============================================================================
-- founder_incidents_recent — list view
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_incidents_recent(int);
CREATE OR REPLACE FUNCTION public.founder_incidents_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id              uuid,
  source_domain   text,
  source_item_id  uuid,
  title           text,
  severity        text,
  status          text,
  opened_at       timestamptz,
  resolved_at     timestamptz,
  age_hours       int,
  auto_created    boolean,
  root_cause_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT i.id, i.source_domain, i.source_item_id, i.title, i.severity, i.status,
    i.opened_at, i.resolved_at,
    extract(hour from (coalesce(i.resolved_at, now()) - i.opened_at))::int,
    i.auto_created, i.root_cause_note
  FROM public.founder_incidents i
  ORDER BY (i.status IN ('open','investigating')) DESC, i.opened_at DESC
  LIMIT p_limit;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_incidents_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_incidents_recent(int) TO authenticated;

-- Bootstrap run skipped during migration apply (founder context not available); cron will pick up.

COMMIT;
