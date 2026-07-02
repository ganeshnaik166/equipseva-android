BEGIN;

-- ============================================================================
-- Round 1694: Founder Speaking Engagements Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_speaking_events_r1694 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_name text NOT NULL,
  event_type text NOT NULL CHECK (event_type IN ('conference','panel','keynote','webinar','podcast')),
  event_date date NOT NULL,
  audience_size int NOT NULL DEFAULT 0,
  recording_url text,
  status text NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed','delivered','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_speaking_leads_r1694 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.founder_speaking_events_r1694(id) ON DELETE CASCADE,
  lead_name text NOT NULL,
  lead_org text,
  lead_email text,
  lead_status text NOT NULL DEFAULT 'new' CHECK (lead_status IN ('new','qualified','converted','dropped')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_speaking_events_r1694 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_speaking_leads_r1694 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_events_r1694 ON public.founder_speaking_events_r1694;
CREATE POLICY founder_all_events_r1694 ON public.founder_speaking_events_r1694
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_leads_r1694 ON public.founder_speaking_leads_r1694;
CREATE POLICY founder_all_leads_r1694 ON public.founder_speaking_leads_r1694
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_events
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_speaking_events_r1694();
CREATE OR REPLACE FUNCTION public.list_speaking_events_r1694()
RETURNS TABLE (
  id uuid,
  event_name text,
  event_type text,
  event_date date,
  audience_size int,
  recording_url text,
  status text,
  lead_count int,
  converted_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id,
      e.event_name,
      e.event_type,
      e.event_date,
      e.audience_size,
      e.recording_url,
      e.status,
      (SELECT (COUNT(*))::int FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id) AS lead_count,
      (SELECT (COUNT(*))::int FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id AND l.lead_status = 'converted') AS converted_count
    FROM public.founder_speaking_events_r1694 e
    ORDER BY e.event_date DESC;
END;
$$;

-- ============================================================================
-- RPC 2: add_event
-- ============================================================================
DROP FUNCTION IF EXISTS public.add_speaking_event_r1694(text, text, date, int, text, text);
CREATE OR REPLACE FUNCTION public.add_speaking_event_r1694(
  p_event_name text,
  p_event_type text,
  p_event_date date,
  p_audience_size int,
  p_recording_url text,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_speaking_events_r1694(event_name, event_type, event_date, audience_size, recording_url, status)
    VALUES (p_event_name, p_event_type, p_event_date, COALESCE(p_audience_size, 0), p_recording_url, COALESCE(p_status, 'confirmed'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_speaking_event_r1694',
      jsonb_build_object('id', v_id, 'event_name', p_event_name, 'event_type', p_event_type, 'event_date', p_event_date));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_leads
-- ============================================================================
DROP FUNCTION IF EXISTS public.list_speaking_leads_r1694(uuid);
CREATE OR REPLACE FUNCTION public.list_speaking_leads_r1694(p_event_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  event_id uuid,
  event_name text,
  lead_name text,
  lead_org text,
  lead_email text,
  lead_status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      l.id,
      l.event_id,
      e.event_name,
      l.lead_name,
      l.lead_org,
      l.lead_email,
      l.lead_status,
      l.created_at
    FROM public.founder_speaking_leads_r1694 l
    JOIN public.founder_speaking_events_r1694 e ON e.id = l.event_id
    WHERE (p_event_id IS NULL OR l.event_id = p_event_id)
    ORDER BY l.created_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4: add_lead
-- ============================================================================
DROP FUNCTION IF EXISTS public.add_speaking_lead_r1694(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.add_speaking_lead_r1694(
  p_event_id uuid,
  p_lead_name text,
  p_lead_org text,
  p_lead_email text,
  p_lead_status text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_speaking_leads_r1694(event_id, lead_name, lead_org, lead_email, lead_status)
    VALUES (p_event_id, p_lead_name, p_lead_org, p_lead_email, COALESCE(p_lead_status, 'new'))
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_speaking_lead_r1694',
      jsonb_build_object('id', v_id, 'event_id', p_event_id, 'lead_name', p_lead_name));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: mark_lead_converted
-- ============================================================================
DROP FUNCTION IF EXISTS public.mark_speaking_lead_converted_r1694(uuid);
CREATE OR REPLACE FUNCTION public.mark_speaking_lead_converted_r1694(p_lead_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_speaking_leads_r1694
    SET lead_status = 'converted', updated_at = now()
    WHERE id = p_lead_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_speaking_lead_converted_r1694',
      jsonb_build_object('lead_id', p_lead_id));
END;
$$;

-- ============================================================================
-- RPC 6: audience_summary
-- ============================================================================
DROP FUNCTION IF EXISTS public.speaking_audience_summary_r1694();
CREATE OR REPLACE FUNCTION public.speaking_audience_summary_r1694()
RETURNS TABLE (
  event_type text,
  events_count int,
  total_audience int,
  avg_audience int,
  delivered_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.event_type,
      (COUNT(*))::int AS events_count,
      (COALESCE(SUM(e.audience_size), 0))::int AS total_audience,
      (COALESCE(AVG(e.audience_size), 0))::int AS avg_audience,
      (COUNT(*) FILTER (WHERE e.status = 'delivered'))::int AS delivered_count
    FROM public.founder_speaking_events_r1694 e
    GROUP BY e.event_type
    ORDER BY total_audience DESC;
END;
$$;

-- ============================================================================
-- RPC 7: conversion_rate
-- ============================================================================
DROP FUNCTION IF EXISTS public.speaking_conversion_rate_r1694();
CREATE OR REPLACE FUNCTION public.speaking_conversion_rate_r1694()
RETURNS TABLE (
  event_id uuid,
  event_name text,
  event_date date,
  audience_size int,
  total_leads int,
  qualified_leads int,
  converted_leads int,
  conversion_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      e.id AS event_id,
      e.event_name,
      e.event_date,
      e.audience_size,
      (SELECT (COUNT(*))::int FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id) AS total_leads,
      (SELECT (COUNT(*))::int FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id AND l.lead_status = 'qualified') AS qualified_leads,
      (SELECT (COUNT(*))::int FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id AND l.lead_status = 'converted') AS converted_leads,
      CASE
        WHEN (SELECT COUNT(*) FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id) = 0 THEN 0::numeric
        ELSE ROUND(
          ((SELECT COUNT(*) FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id AND l.lead_status = 'converted')::numeric
           / (SELECT COUNT(*) FROM public.founder_speaking_leads_r1694 l WHERE l.event_id = e.id)::numeric) * 100,
          2
        )
      END AS conversion_pct
    FROM public.founder_speaking_events_r1694 e
    ORDER BY e.event_date DESC;
END;
$$;

-- ============================================================================
-- Permissions
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_speaking_events_r1694() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_speaking_event_r1694(text, text, date, int, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_speaking_leads_r1694(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_speaking_lead_r1694(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_speaking_lead_converted_r1694(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.speaking_audience_summary_r1694() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.speaking_conversion_rate_r1694() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_speaking_events_r1694() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_speaking_event_r1694(text, text, date, int, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_speaking_leads_r1694(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_speaking_lead_r1694(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_speaking_lead_converted_r1694(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.speaking_audience_summary_r1694() TO authenticated;
GRANT EXECUTE ON FUNCTION public.speaking_conversion_rate_r1694() TO authenticated;

COMMIT;