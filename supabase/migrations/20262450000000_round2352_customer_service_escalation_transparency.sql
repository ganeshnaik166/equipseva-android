BEGIN;

-- =====================================================================
-- r2352: Customer service-level escalation transparency
-- Expose each escalated ticket with full trail: response time, escalation
-- steps, resolution. Two _r2352 tables, RLS founder_all, 7 RPCs all
-- is_founder() gated.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Table 1: escalated_tickets_r2352
-- One row per escalated customer service ticket
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escalated_tickets_r2352 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id     uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  ticket_subject  text NOT NULL,
  ticket_body     text,
  channel         text NOT NULL CHECK (channel IN ('email','whatsapp','phone','app','chat')),
  severity        text NOT NULL CHECK (severity IN ('p0','p1','p2','p3')),
  opened_at       timestamptz NOT NULL DEFAULT now(),
  first_response_at timestamptz,
  resolved_at     timestamptz,
  current_level   int NOT NULL DEFAULT 1 CHECK (current_level BETWEEN 1 AND 5),
  status          text NOT NULL DEFAULT 'open'
                  CHECK (status IN ('open','escalated','in_progress','resolved','closed','breached')),
  resolution_note text,
  csat_score      int CHECK (csat_score BETWEEN 1 AND 5),
  sla_minutes     int NOT NULL DEFAULT 60,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS escalated_tickets_r2352_customer_idx
  ON public.escalated_tickets_r2352(customer_id);
CREATE INDEX IF NOT EXISTS escalated_tickets_r2352_status_idx
  ON public.escalated_tickets_r2352(status);
CREATE INDEX IF NOT EXISTS escalated_tickets_r2352_opened_idx
  ON public.escalated_tickets_r2352(opened_at DESC);

ALTER TABLE public.escalated_tickets_r2352 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS escalated_tickets_r2352_founder_all ON public.escalated_tickets_r2352;
CREATE POLICY escalated_tickets_r2352_founder_all
  ON public.escalated_tickets_r2352
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---------------------------------------------------------------------
-- Table 2: escalation_steps_r2352
-- One row per escalation step recorded against a ticket (full trail)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escalation_steps_r2352 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id       uuid NOT NULL REFERENCES public.escalated_tickets_r2352(id) ON DELETE CASCADE,
  step_index      int NOT NULL,
  level           int NOT NULL CHECK (level BETWEEN 1 AND 5),
  actor_id        uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_role      text CHECK (actor_role IN ('engineer','hospital_admin','supplier','manufacturer','logistics','support_lead','founder','system')),
  action_type     text NOT NULL CHECK (action_type IN ('open','first_response','reassign','escalate','deescalate','note','resolve','reopen','breach')),
  note            text,
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  minutes_since_open numeric(10,2),
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ticket_id, step_index)
);

CREATE INDEX IF NOT EXISTS escalation_steps_r2352_ticket_idx
  ON public.escalation_steps_r2352(ticket_id);
CREATE INDEX IF NOT EXISTS escalation_steps_r2352_occurred_idx
  ON public.escalation_steps_r2352(occurred_at DESC);

ALTER TABLE public.escalation_steps_r2352 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS escalation_steps_r2352_founder_all ON public.escalation_steps_r2352;
CREATE POLICY escalation_steps_r2352_founder_all
  ON public.escalation_steps_r2352
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list_escalated_tickets_r2352
-- All escalated tickets with response time + escalation depth
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_escalated_tickets_r2352()
RETURNS TABLE (
  id uuid,
  customer_id uuid,
  customer_email text,
  ticket_subject text,
  channel text,
  severity text,
  status text,
  current_level int,
  opened_at timestamptz,
  first_response_minutes numeric,
  resolution_minutes numeric,
  step_count int,
  sla_minutes int,
  sla_breached boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.customer_id,
    p.email AS customer_email,
    t.ticket_subject,
    t.channel,
    t.severity,
    t.status,
    t.current_level,
    t.opened_at,
    CASE WHEN t.first_response_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (t.first_response_at - t.opened_at)) / 60.0
      ELSE NULL
    END AS first_response_minutes,
    CASE WHEN t.resolved_at IS NOT NULL
      THEN EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0
      ELSE NULL
    END AS resolution_minutes,
    (SELECT COUNT(*)::int FROM public.escalation_steps_r2352 s WHERE s.ticket_id = t.id) AS step_count,
    t.sla_minutes,
    CASE
      WHEN t.resolved_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 > t.sla_minutes
      ELSE EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0 > t.sla_minutes
    END AS sla_breached
  FROM public.escalated_tickets_r2352 t
  LEFT JOIN public.profiles p ON p.id = t.customer_id
  ORDER BY t.opened_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_escalated_tickets_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_escalated_tickets_r2352() TO authenticated;

-- =====================================================================
-- RPC 2: ticket_trail_r2352
-- Full escalation trail for every ticket (joined view)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.ticket_trail_r2352()
RETURNS TABLE (
  step_id uuid,
  ticket_id uuid,
  ticket_subject text,
  step_index int,
  level int,
  actor_id uuid,
  actor_email text,
  actor_role text,
  action_type text,
  note text,
  occurred_at timestamptz,
  minutes_since_open numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    s.id AS step_id,
    s.ticket_id,
    t.ticket_subject,
    s.step_index,
    s.level,
    s.actor_id,
    p.email AS actor_email,
    s.actor_role,
    s.action_type,
    s.note,
    s.occurred_at,
    s.minutes_since_open
  FROM public.escalation_steps_r2352 s
  JOIN public.escalated_tickets_r2352 t ON t.id = s.ticket_id
  LEFT JOIN public.profiles p ON p.id = s.actor_id
  ORDER BY t.opened_at DESC, s.step_index ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.ticket_trail_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ticket_trail_r2352() TO authenticated;

-- =====================================================================
-- RPC 3: sla_breach_summary_r2352
-- Per-severity breakdown of breached vs in-SLA
-- =====================================================================
CREATE OR REPLACE FUNCTION public.sla_breach_summary_r2352()
RETURNS TABLE (
  severity text,
  total_tickets int,
  resolved_in_sla int,
  resolved_breached int,
  open_breached int,
  median_response_minutes numeric,
  median_resolution_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.severity,
    COUNT(*)::int AS total_tickets,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 <= t.sla_minutes
    )::int AS resolved_in_sla,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 > t.sla_minutes
    )::int AS resolved_breached,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NULL
        AND EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0 > t.sla_minutes
    )::int AS open_breached,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY
      CASE WHEN t.first_response_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.first_response_at - t.opened_at)) / 60.0
      END
    ) AS median_response_minutes,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY
      CASE WHEN t.resolved_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0
      END
    ) AS median_resolution_minutes
  FROM public.escalated_tickets_r2352 t
  GROUP BY t.severity
  ORDER BY t.severity;
END;
$$;

REVOKE ALL ON FUNCTION public.sla_breach_summary_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sla_breach_summary_r2352() TO authenticated;

-- =====================================================================
-- RPC 4: open_breaches_r2352
-- Tickets currently open AND past SLA
-- =====================================================================
CREATE OR REPLACE FUNCTION public.open_breaches_r2352()
RETURNS TABLE (
  id uuid,
  ticket_subject text,
  customer_email text,
  severity text,
  current_level int,
  opened_at timestamptz,
  minutes_open numeric,
  sla_minutes int,
  minutes_over numeric,
  step_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.id,
    t.ticket_subject,
    p.email AS customer_email,
    t.severity,
    t.current_level,
    t.opened_at,
    EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0 AS minutes_open,
    t.sla_minutes,
    (EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0) - t.sla_minutes AS minutes_over,
    (SELECT COUNT(*)::int FROM public.escalation_steps_r2352 s WHERE s.ticket_id = t.id) AS step_count
  FROM public.escalated_tickets_r2352 t
  LEFT JOIN public.profiles p ON p.id = t.customer_id
  WHERE t.resolved_at IS NULL
    AND EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0 > t.sla_minutes
  ORDER BY (EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0) - t.sla_minutes DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.open_breaches_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_breaches_r2352() TO authenticated;

-- =====================================================================
-- RPC 5: escalation_depth_distribution_r2352
-- How many tickets escalated to each level
-- =====================================================================
CREATE OR REPLACE FUNCTION public.escalation_depth_distribution_r2352()
RETURNS TABLE (
  current_level int,
  ticket_count int,
  resolved_count int,
  open_count int,
  avg_resolution_minutes numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.current_level,
    COUNT(*)::int AS ticket_count,
    COUNT(*) FILTER (WHERE t.resolved_at IS NOT NULL)::int AS resolved_count,
    COUNT(*) FILTER (WHERE t.resolved_at IS NULL)::int AS open_count,
    AVG(
      CASE WHEN t.resolved_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0
      END
    ) AS avg_resolution_minutes
  FROM public.escalated_tickets_r2352 t
  GROUP BY t.current_level
  ORDER BY t.current_level;
END;
$$;

REVOKE ALL ON FUNCTION public.escalation_depth_distribution_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.escalation_depth_distribution_r2352() TO authenticated;

-- =====================================================================
-- RPC 6: top_repeat_escalators_r2352
-- Customers with multiple escalated tickets
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_repeat_escalators_r2352()
RETURNS TABLE (
  customer_id uuid,
  customer_email text,
  ticket_count int,
  open_count int,
  breached_count int,
  avg_csat numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.customer_id,
    p.email AS customer_email,
    COUNT(*)::int AS ticket_count,
    COUNT(*) FILTER (WHERE t.resolved_at IS NULL)::int AS open_count,
    COUNT(*) FILTER (
      WHERE t.resolved_at IS NOT NULL
        AND EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 > t.sla_minutes
    )::int AS breached_count,
    AVG(t.csat_score::numeric) AS avg_csat
  FROM public.escalated_tickets_r2352 t
  LEFT JOIN public.profiles p ON p.id = t.customer_id
  GROUP BY t.customer_id, p.email
  HAVING COUNT(*) >= 2
  ORDER BY COUNT(*) DESC, COUNT(*) FILTER (WHERE t.resolved_at IS NULL) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.top_repeat_escalators_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_repeat_escalators_r2352() TO authenticated;

-- =====================================================================
-- RPC 7: channel_performance_r2352
-- Response/resolution stats per intake channel
-- =====================================================================
CREATE OR REPLACE FUNCTION public.channel_performance_r2352()
RETURNS TABLE (
  channel text,
  total_tickets int,
  avg_first_response_minutes numeric,
  avg_resolution_minutes numeric,
  breach_rate_pct numeric,
  avg_csat numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    t.channel,
    COUNT(*)::int AS total_tickets,
    AVG(
      CASE WHEN t.first_response_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.first_response_at - t.opened_at)) / 60.0
      END
    ) AS avg_first_response_minutes,
    AVG(
      CASE WHEN t.resolved_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0
      END
    ) AS avg_resolution_minutes,
    CASE WHEN COUNT(*) > 0
      THEN ROUND(
        100.0 * COUNT(*) FILTER (
          WHERE (t.resolved_at IS NOT NULL
                  AND EXTRACT(EPOCH FROM (t.resolved_at - t.opened_at)) / 60.0 > t.sla_minutes)
             OR (t.resolved_at IS NULL
                  AND EXTRACT(EPOCH FROM (now() - t.opened_at)) / 60.0 > t.sla_minutes)
        )::numeric / COUNT(*),
        2
      )
      ELSE 0
    END AS breach_rate_pct,
    AVG(t.csat_score::numeric) AS avg_csat
  FROM public.escalated_tickets_r2352 t
  GROUP BY t.channel
  ORDER BY COUNT(*) DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.channel_performance_r2352() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.channel_performance_r2352() TO authenticated;

COMMIT;
