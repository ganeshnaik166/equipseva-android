BEGIN;

-- ============================================================================
-- Round 1777 — Investor Cap Refresh Tracker
-- Tracks when cap table refreshes are due (annual review, new round, secondary,
-- employee grant, buyback) plus supporting documents (409A, board resolution,
-- term sheet amendment, secretary certificate).
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_cap_refresh_schedule_r1777 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  refresh_type text NOT NULL CHECK (refresh_type IN (
    'annual_review','new_round','secondary_sale','employee_grant','buyback'
  )),
  scheduled_date date NOT NULL,
  completed_date date,
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN (
    'scheduled','in_progress','completed','cancelled'
  )),
  snapshot_id_before uuid,
  snapshot_id_after uuid,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_cap_refresh_documents_r1777 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  schedule_id uuid NOT NULL REFERENCES public.investor_cap_refresh_schedule_r1777(id) ON DELETE CASCADE,
  document_type text NOT NULL CHECK (document_type IN (
    '409a_valuation','secretary_certificate','board_resolution','term_sheet_amendment'
  )),
  document_url text NOT NULL,
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cap_refresh_sched_r1777_status
  ON public.investor_cap_refresh_schedule_r1777(status, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_cap_refresh_docs_r1777_sched
  ON public.investor_cap_refresh_documents_r1777(schedule_id);

ALTER TABLE public.investor_cap_refresh_schedule_r1777 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_cap_refresh_documents_r1777 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_sched_r1777 ON public.investor_cap_refresh_schedule_r1777;
CREATE POLICY founder_only_sched_r1777 ON public.investor_cap_refresh_schedule_r1777
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_only_docs_r1777 ON public.investor_cap_refresh_documents_r1777;
CREATE POLICY founder_only_docs_r1777 ON public.investor_cap_refresh_documents_r1777
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1 — list_schedules
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_cap_refresh_schedules_r1777()
RETURNS TABLE (
  id uuid,
  refresh_type text,
  scheduled_date date,
  completed_date date,
  status text,
  snapshot_id_before uuid,
  snapshot_id_after uuid,
  notes text,
  created_at timestamptz,
  doc_count bigint
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
    s.id,
    s.refresh_type,
    s.scheduled_date,
    s.completed_date,
    s.status,
    s.snapshot_id_before,
    s.snapshot_id_after,
    s.notes,
    s.created_at,
    (SELECT COUNT(*) FROM public.investor_cap_refresh_documents_r1777 d WHERE d.schedule_id = s.id) AS doc_count
  FROM public.investor_cap_refresh_schedule_r1777 s
  ORDER BY s.scheduled_date DESC, s.created_at DESC;
END;
$$;

-- ============================================================================
-- RPC 2 — schedule_refresh (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.schedule_cap_refresh_r1777(
  p_refresh_type text,
  p_scheduled_date date,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_cap_refresh_schedule_r1777(refresh_type, scheduled_date, notes)
  VALUES (p_refresh_type, p_scheduled_date, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'schedule_cap_refresh_r1777',
    jsonb_build_object('id', v_id, 'refresh_type', p_refresh_type, 'scheduled_date', p_scheduled_date)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3 — list_documents
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_cap_refresh_documents_r1777(p_schedule_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  schedule_id uuid,
  refresh_type text,
  document_type text,
  document_url text,
  uploaded_at timestamptz,
  notes text
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
    d.id,
    d.schedule_id,
    s.refresh_type,
    d.document_type,
    d.document_url,
    d.uploaded_at,
    d.notes
  FROM public.investor_cap_refresh_documents_r1777 d
  JOIN public.investor_cap_refresh_schedule_r1777 s ON s.id = d.schedule_id
  WHERE p_schedule_id IS NULL OR d.schedule_id = p_schedule_id
  ORDER BY d.uploaded_at DESC;
END;
$$;

-- ============================================================================
-- RPC 4 — attach_document (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.attach_cap_refresh_document_r1777(
  p_schedule_id uuid,
  p_document_type text,
  p_document_url text,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.investor_cap_refresh_documents_r1777(schedule_id, document_type, document_url, notes)
  VALUES (p_schedule_id, p_document_type, p_document_url, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'attach_cap_refresh_document_r1777',
    jsonb_build_object('id', v_id, 'schedule_id', p_schedule_id, 'document_type', p_document_type)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5 — complete_refresh (write)
-- ============================================================================
CREATE OR REPLACE FUNCTION public.complete_cap_refresh_r1777(
  p_schedule_id uuid,
  p_snapshot_id_after uuid DEFAULT NULL,
  p_snapshot_id_before uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.investor_cap_refresh_schedule_r1777
  SET status = 'completed',
      completed_date = CURRENT_DATE,
      snapshot_id_after = COALESCE(p_snapshot_id_after, snapshot_id_after),
      snapshot_id_before = COALESCE(p_snapshot_id_before, snapshot_id_before),
      updated_at = now()
  WHERE id = p_schedule_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'complete_cap_refresh_r1777',
    jsonb_build_object('schedule_id', p_schedule_id, 'completed_date', CURRENT_DATE)
  );
END;
$$;

-- ============================================================================
-- RPC 6 — upcoming_refreshes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upcoming_cap_refreshes_r1777()
RETURNS TABLE (
  id uuid,
  refresh_type text,
  scheduled_date date,
  days_until int,
  status text,
  notes text
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
    s.id,
    s.refresh_type,
    s.scheduled_date,
    (s.scheduled_date - CURRENT_DATE)::int AS days_until,
    s.status,
    s.notes
  FROM public.investor_cap_refresh_schedule_r1777 s
  WHERE s.status IN ('scheduled','in_progress')
    AND s.scheduled_date >= CURRENT_DATE
  ORDER BY s.scheduled_date ASC
  LIMIT 25;
END;
$$;

-- ============================================================================
-- RPC 7 — recent_refreshes
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_cap_refreshes_r1777()
RETURNS TABLE (
  id uuid,
  refresh_type text,
  scheduled_date date,
  completed_date date,
  status text,
  doc_count bigint
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
    s.id,
    s.refresh_type,
    s.scheduled_date,
    s.completed_date,
    s.status,
    (SELECT COUNT(*) FROM public.investor_cap_refresh_documents_r1777 d WHERE d.schedule_id = s.id) AS doc_count
  FROM public.investor_cap_refresh_schedule_r1777 s
  WHERE s.status = 'completed'
    AND s.completed_date IS NOT NULL
  ORDER BY s.completed_date DESC
  LIMIT 25;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_cap_refresh_schedules_r1777()           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.schedule_cap_refresh_r1777(text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_cap_refresh_documents_r1777(uuid)        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.attach_cap_refresh_document_r1777(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_cap_refresh_r1777(uuid, uuid, uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_cap_refreshes_r1777()                FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_cap_refreshes_r1777()                  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_cap_refresh_schedules_r1777()           TO authenticated;
GRANT EXECUTE ON FUNCTION public.schedule_cap_refresh_r1777(text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_cap_refresh_documents_r1777(uuid)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.attach_cap_refresh_document_r1777(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_cap_refresh_r1777(uuid, uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_cap_refreshes_r1777()                TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_cap_refreshes_r1777()                  TO authenticated;

COMMIT;