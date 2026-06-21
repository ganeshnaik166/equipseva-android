BEGIN;

-- =========================================================
-- r1665 — Investor Diligence Tracker
-- Per-investor, per-item diligence checklist + milestones
-- =========================================================

CREATE TABLE IF NOT EXISTS public.investor_diligence_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  investor_id uuid NOT NULL,
  item_label text NOT NULL,
  category text NOT NULL DEFAULT 'general',
  required boolean NOT NULL DEFAULT true,
  due_date date,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','submitted','cleared','blocked')),
  submitted_at timestamptz,
  cleared_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_dilig_items_investor
  ON public.investor_diligence_items(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_dilig_items_status
  ON public.investor_diligence_items(status);
CREATE INDEX IF NOT EXISTS idx_inv_dilig_items_due
  ON public.investor_diligence_items(due_date);

CREATE TABLE IF NOT EXISTS public.investor_diligence_milestones (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  investor_id uuid NOT NULL,
  milestone text NOT NULL,
  reached_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_dilig_ms_investor
  ON public.investor_diligence_milestones(investor_id);
CREATE INDEX IF NOT EXISTS idx_inv_dilig_ms_reached
  ON public.investor_diligence_milestones(reached_at);

ALTER TABLE public.investor_diligence_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_diligence_milestones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_inv_dilig_items_founder ON public.investor_diligence_items;
CREATE POLICY p_inv_dilig_items_founder ON public.investor_diligence_items
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_inv_dilig_ms_founder ON public.investor_diligence_milestones;
CREATE POLICY p_inv_dilig_ms_founder ON public.investor_diligence_milestones
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- =========================================================
-- RPC 1: founder_list_diligence_items
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_list_diligence_items(p_investor uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  item_label text,
  category text,
  required boolean,
  due_date date,
  status text,
  submitted_at timestamptz,
  cleared_at timestamptz,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT i.id, i.investor_id, i.item_label, i.category, i.required,
           i.due_date, i.status, i.submitted_at, i.cleared_at, i.note, i.created_at
      FROM public.investor_diligence_items i
     WHERE (p_investor IS NULL OR i.investor_id = p_investor)
     ORDER BY i.due_date NULLS LAST, i.created_at DESC
     LIMIT 500;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_list_diligence_items(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_list_diligence_items(uuid) TO authenticated;

-- =========================================================
-- RPC 2: founder_add_diligence_item
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_add_diligence_item(
  p_investor uuid,
  p_item_label text,
  p_category text,
  p_required boolean,
  p_due_date date,
  p_note text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_diligence_items(
    investor_id, item_label, category, required, due_date, note
  )
  VALUES (
    p_investor, p_item_label, COALESCE(p_category, 'general'),
    COALESCE(p_required, true), p_due_date, p_note
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1665_add_diligence_item',
    jsonb_build_object('id', v_id, 'investor_id', p_investor, 'item_label', p_item_label)
  );
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_add_diligence_item(uuid,text,text,boolean,date,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_add_diligence_item(uuid,text,text,boolean,date,text) TO authenticated;

-- =========================================================
-- RPC 3: founder_update_diligence_status
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_update_diligence_status(
  p_item_id uuid,
  p_status text,
  p_note text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_status NOT IN ('pending','submitted','cleared','blocked') THEN
    RAISE EXCEPTION 'invalid_status';
  END IF;

  UPDATE public.investor_diligence_items
     SET status = p_status,
         submitted_at = CASE WHEN p_status = 'submitted' AND submitted_at IS NULL THEN now() ELSE submitted_at END,
         cleared_at   = CASE WHEN p_status = 'cleared'   AND cleared_at   IS NULL THEN now() ELSE cleared_at   END,
         note         = COALESCE(p_note, note),
         updated_at   = now()
   WHERE id = p_item_id
   RETURNING id INTO v_id;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'item_not_found';
  END IF;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1665_update_diligence_status',
    jsonb_build_object('id', v_id, 'status', p_status)
  );
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_update_diligence_status(uuid,text,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_update_diligence_status(uuid,text,text) TO authenticated;

-- =========================================================
-- RPC 4: founder_list_diligence_milestones
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_list_diligence_milestones(p_investor uuid DEFAULT NULL)
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  milestone text,
  reached_at timestamptz,
  note text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT m.id, m.investor_id, m.milestone, m.reached_at, m.note, m.created_at
      FROM public.investor_diligence_milestones m
     WHERE (p_investor IS NULL OR m.investor_id = p_investor)
     ORDER BY m.reached_at DESC NULLS LAST, m.created_at DESC
     LIMIT 500;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_list_diligence_milestones(uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_list_diligence_milestones(uuid) TO authenticated;

-- =========================================================
-- RPC 5: founder_record_diligence_milestone
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_record_diligence_milestone(
  p_investor uuid,
  p_milestone text,
  p_reached_at timestamptz,
  p_note text
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
VOLATILE
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.investor_diligence_milestones(
    investor_id, milestone, reached_at, note
  ) VALUES (
    p_investor, p_milestone, COALESCE(p_reached_at, now()), p_note
  )
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1665_record_diligence_milestone',
    jsonb_build_object('id', v_id, 'investor_id', p_investor, 'milestone', p_milestone)
  );
  RETURN v_id;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_record_diligence_milestone(uuid,text,timestamptz,text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_record_diligence_milestone(uuid,text,timestamptz,text) TO authenticated;

-- =========================================================
-- RPC 6: founder_investor_diligence_summary
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_investor_diligence_summary()
RETURNS TABLE(
  investor_id uuid,
  total_items int,
  pending_count int,
  submitted_count int,
  cleared_count int,
  blocked_count int,
  overdue_count int,
  pct_cleared numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT
      i.investor_id,
      COUNT(*)::int AS total_items,
      (COUNT(*) FILTER (WHERE i.status = 'pending'))::int   AS pending_count,
      (COUNT(*) FILTER (WHERE i.status = 'submitted'))::int AS submitted_count,
      (COUNT(*) FILTER (WHERE i.status = 'cleared'))::int   AS cleared_count,
      (COUNT(*) FILTER (WHERE i.status = 'blocked'))::int   AS blocked_count,
      (COUNT(*) FILTER (WHERE i.due_date < current_date AND i.status NOT IN ('cleared')))::int AS overdue_count,
      ROUND(
        100.0 * (COUNT(*) FILTER (WHERE i.status = 'cleared'))::numeric
              / NULLIF(COUNT(*),0),
        1
      ) AS pct_cleared
    FROM public.investor_diligence_items i
    GROUP BY i.investor_id
    ORDER BY pct_cleared NULLS LAST;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_investor_diligence_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_diligence_summary() TO authenticated;

-- =========================================================
-- RPC 7: founder_blocked_diligence_items
-- =========================================================
CREATE OR REPLACE FUNCTION public.founder_blocked_diligence_items()
RETURNS TABLE(
  id uuid,
  investor_id uuid,
  item_label text,
  category text,
  due_date date,
  status text,
  note text,
  age_days int
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
    SELECT i.id, i.investor_id, i.item_label, i.category, i.due_date,
           i.status, i.note,
           GREATEST(0, (current_date - i.created_at::date))::int AS age_days
      FROM public.investor_diligence_items i
     WHERE i.status = 'blocked'
        OR (i.due_date IS NOT NULL AND i.due_date < current_date AND i.status NOT IN ('cleared'))
     ORDER BY i.due_date NULLS LAST, i.created_at ASC
     LIMIT 200;
END $$;

REVOKE EXECUTE ON FUNCTION public.founder_blocked_diligence_items() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_blocked_diligence_items() TO authenticated;

COMMIT;