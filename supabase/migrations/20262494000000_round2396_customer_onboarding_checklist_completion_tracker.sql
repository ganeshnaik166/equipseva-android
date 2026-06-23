BEGIN;

-- =====================================================================
-- r2396: Customer onboarding-checklist-completion tracker
-- 14-day onboarding checklist: per-item completion + time-to-complete
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.customer_onboarding_checklists_r2396 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_email text NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  deadline_at timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  completed_at timestamptz,
  total_items integer NOT NULL DEFAULT 0,
  completed_items integer NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'in_progress'
    CHECK (status IN ('in_progress','completed','expired','abandoned')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coc_r2396_customer
  ON public.customer_onboarding_checklists_r2396(customer_id);
CREATE INDEX IF NOT EXISTS idx_coc_r2396_status
  ON public.customer_onboarding_checklists_r2396(status);

ALTER TABLE public.customer_onboarding_checklists_r2396 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_coc_r2396
  ON public.customer_onboarding_checklists_r2396;
CREATE POLICY founder_all_coc_r2396
  ON public.customer_onboarding_checklists_r2396
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.customer_onboarding_items_r2396 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  checklist_id uuid NOT NULL REFERENCES public.customer_onboarding_checklists_r2396(id) ON DELETE CASCADE,
  item_key text NOT NULL,
  item_label text NOT NULL,
  item_order integer NOT NULL DEFAULT 0,
  required boolean NOT NULL DEFAULT true,
  completed boolean NOT NULL DEFAULT false,
  completed_at timestamptz,
  time_to_complete_hours numeric(10,2),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (checklist_id, item_key)
);

CREATE INDEX IF NOT EXISTS idx_coi_r2396_checklist
  ON public.customer_onboarding_items_r2396(checklist_id);
CREATE INDEX IF NOT EXISTS idx_coi_r2396_completed
  ON public.customer_onboarding_items_r2396(completed);

ALTER TABLE public.customer_onboarding_items_r2396 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_coi_r2396
  ON public.customer_onboarding_items_r2396;
CREATE POLICY founder_all_coi_r2396
  ON public.customer_onboarding_items_r2396
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- RPC 1: list all checklists
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_checklists_r2396()
RETURNS TABLE (
  id uuid,
  customer_id uuid,
  customer_email text,
  started_at timestamptz,
  deadline_at timestamptz,
  completed_at timestamptz,
  total_items integer,
  completed_items integer,
  completion_pct numeric,
  status text,
  days_remaining integer
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
    c.id,
    c.customer_id,
    c.customer_email,
    c.started_at,
    c.deadline_at,
    c.completed_at,
    c.total_items,
    c.completed_items,
    CASE WHEN c.total_items > 0
      THEN ROUND((c.completed_items::numeric / c.total_items::numeric) * 100, 1)
      ELSE 0::numeric
    END,
    c.status,
    GREATEST(0, EXTRACT(DAY FROM (c.deadline_at - now()))::integer)
  FROM public.customer_onboarding_checklists_r2396 c
  ORDER BY c.started_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_checklists_r2396() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_checklists_r2396() TO authenticated;

-- =====================================================================
-- RPC 2: incomplete items across all active checklists
-- =====================================================================
CREATE OR REPLACE FUNCTION public.incomplete_items_r2396()
RETURNS TABLE (
  id uuid,
  checklist_id uuid,
  customer_email text,
  item_key text,
  item_label text,
  item_order integer,
  required boolean,
  hours_since_started numeric,
  deadline_at timestamptz
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
    i.id,
    i.checklist_id,
    c.customer_email,
    i.item_key,
    i.item_label,
    i.item_order,
    i.required,
    ROUND(EXTRACT(EPOCH FROM (now() - c.started_at))/3600.0, 1),
    c.deadline_at
  FROM public.customer_onboarding_items_r2396 i
  JOIN public.customer_onboarding_checklists_r2396 c ON c.id = i.checklist_id
  WHERE i.completed = false
    AND c.status = 'in_progress'
  ORDER BY c.deadline_at ASC, i.item_order ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.incomplete_items_r2396() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.incomplete_items_r2396() TO authenticated;

-- =====================================================================
-- RPC 3: average time-to-complete per item across completed checklists
-- =====================================================================
CREATE OR REPLACE FUNCTION public.avg_time_per_item_r2396()
RETURNS TABLE (
  item_key text,
  item_label text,
  completion_count integer,
  avg_hours numeric,
  median_hours numeric,
  max_hours numeric
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
    i.item_key,
    MAX(i.item_label),
    COUNT(*)::integer,
    ROUND(AVG(i.time_to_complete_hours), 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY i.time_to_complete_hours)::numeric, 2),
    ROUND(MAX(i.time_to_complete_hours), 2)
  FROM public.customer_onboarding_items_r2396 i
  WHERE i.completed = true
    AND i.time_to_complete_hours IS NOT NULL
  GROUP BY i.item_key
  ORDER BY AVG(i.time_to_complete_hours) DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.avg_time_per_item_r2396() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.avg_time_per_item_r2396() TO authenticated;

-- =====================================================================
-- RPC 4: overall funnel by item (count complete / incomplete)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.item_completion_funnel_r2396()
RETURNS TABLE (
  item_key text,
  item_label text,
  total integer,
  completed integer,
  incomplete integer,
  completion_pct numeric
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
    i.item_key,
    MAX(i.item_label),
    COUNT(*)::integer,
    COUNT(*) FILTER (WHERE i.completed = true)::integer,
    COUNT(*) FILTER (WHERE i.completed = false)::integer,
    CASE WHEN COUNT(*) > 0
      THEN ROUND((COUNT(*) FILTER (WHERE i.completed = true)::numeric / COUNT(*)::numeric) * 100, 1)
      ELSE 0::numeric
    END
  FROM public.customer_onboarding_items_r2396 i
  GROUP BY i.item_key
  ORDER BY MIN(i.item_order) ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.item_completion_funnel_r2396() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.item_completion_funnel_r2396() TO authenticated;

-- =====================================================================
-- RPC 5: at-risk checklists (deadline near, low completion)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.at_risk_checklists_r2396()
RETURNS TABLE (
  id uuid,
  customer_email text,
  started_at timestamptz,
  deadline_at timestamptz,
  total_items integer,
  completed_items integer,
  completion_pct numeric,
  days_remaining integer
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
    c.id,
    c.customer_email,
    c.started_at,
    c.deadline_at,
    c.total_items,
    c.completed_items,
    CASE WHEN c.total_items > 0
      THEN ROUND((c.completed_items::numeric / c.total_items::numeric) * 100, 1)
      ELSE 0::numeric
    END,
    GREATEST(0, EXTRACT(DAY FROM (c.deadline_at - now()))::integer)
  FROM public.customer_onboarding_checklists_r2396 c
  WHERE c.status = 'in_progress'
    AND c.deadline_at < (now() + interval '3 days')
    AND (c.total_items = 0 OR (c.completed_items::numeric / NULLIF(c.total_items,0)::numeric) < 0.7)
  ORDER BY c.deadline_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.at_risk_checklists_r2396() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.at_risk_checklists_r2396() TO authenticated;

-- =====================================================================
-- RPC 6: cohort overview (status counts + avg completion time)
-- =====================================================================
CREATE OR REPLACE FUNCTION public.cohort_overview_r2396()
RETURNS TABLE (
  status text,
  customer_count integer,
  avg_completion_pct numeric,
  avg_days_to_complete numeric
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
    c.status,
    COUNT(*)::integer,
    ROUND(AVG(
      CASE WHEN c.total_items > 0
        THEN (c.completed_items::numeric / c.total_items::numeric) * 100
        ELSE 0::numeric
      END
    ), 1),
    ROUND(AVG(
      CASE WHEN c.completed_at IS NOT NULL
        THEN EXTRACT(EPOCH FROM (c.completed_at - c.started_at))/86400.0
        ELSE NULL
      END
    )::numeric, 2)
  FROM public.customer_onboarding_checklists_r2396 c
  GROUP BY c.status
  ORDER BY c.status;
END;
$$;

REVOKE ALL ON FUNCTION public.cohort_overview_r2396() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cohort_overview_r2396() TO authenticated;

-- =====================================================================
-- RPC 7: detail items for a single checklist
-- =====================================================================
CREATE OR REPLACE FUNCTION public.checklist_items_detail_r2396(p_checklist_id uuid)
RETURNS TABLE (
  id uuid,
  item_key text,
  item_label text,
  item_order integer,
  required boolean,
  completed boolean,
  completed_at timestamptz,
  time_to_complete_hours numeric
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
    i.id,
    i.item_key,
    i.item_label,
    i.item_order,
    i.required,
    i.completed,
    i.completed_at,
    i.time_to_complete_hours
  FROM public.customer_onboarding_items_r2396 i
  WHERE i.checklist_id = p_checklist_id
  ORDER BY i.item_order ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.checklist_items_detail_r2396(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.checklist_items_detail_r2396(uuid) TO authenticated;

COMMIT;
