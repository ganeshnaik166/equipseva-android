BEGIN;

-- =============================================================================
-- r1662 — Founder Quarterly OKR Retro
-- Per-quarter OKR retrospective: hit-rate, miss-rate, miss-reason taxonomy,
-- action items carried forward.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Table 1: founder_quarterly_okr_retros
-- One row per quarter (e.g. '2026-Q1') with summary markdown.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_quarterly_okr_retros_r1662 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter       text NOT NULL UNIQUE,        -- e.g. '2026-Q1'
  recorded_at   timestamptz NOT NULL DEFAULT now(),
  summary_md    text NOT NULL DEFAULT '',
  hit_count     int NOT NULL DEFAULT 0,
  miss_count    int NOT NULL DEFAULT 0,
  carry_count   int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_quarterly_okr_retros_r1662 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_r1662_retros_founder_all ON public.founder_quarterly_okr_retros_r1662;
CREATE POLICY p_r1662_retros_founder_all
  ON public.founder_quarterly_okr_retros_r1662
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- -----------------------------------------------------------------------------
-- Table 2: founder_quarterly_okr_retro_items
-- One row per OKR per quarter retro.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.founder_quarterly_okr_retro_items_r1662 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retro_quarter   text NOT NULL REFERENCES public.founder_quarterly_okr_retros_r1662(quarter) ON DELETE CASCADE,
  okr_id          uuid NOT NULL,
  okr_title       text NOT NULL DEFAULT '',
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('hit','miss','partial','pending','dropped')),
  miss_reason     text NOT NULL DEFAULT '',
  carry_forward   boolean NOT NULL DEFAULT false,
  owner           text NOT NULL DEFAULT '',
  notes           text NOT NULL DEFAULT '',
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_r1662_items_quarter
  ON public.founder_quarterly_okr_retro_items_r1662(retro_quarter);
CREATE INDEX IF NOT EXISTS idx_r1662_items_carry
  ON public.founder_quarterly_okr_retro_items_r1662(carry_forward) WHERE carry_forward = true;

ALTER TABLE public.founder_quarterly_okr_retro_items_r1662 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_r1662_items_founder_all ON public.founder_quarterly_okr_retro_items_r1662;
CREATE POLICY p_r1662_items_founder_all
  ON public.founder_quarterly_okr_retro_items_r1662
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =============================================================================
-- RPC 1 — founder_list_quarterly_retros (READ)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_list_quarterly_retros_r1662()
RETURNS TABLE (
  quarter      text,
  recorded_at  timestamptz,
  summary_md   text,
  hit_count    int,
  miss_count   int,
  carry_count  int,
  total_items  int,
  hit_rate_pct numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    r.quarter,
    r.recorded_at,
    r.summary_md,
    r.hit_count,
    r.miss_count,
    r.carry_count,
    (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter) AS total_items,
    CASE
      WHEN (r.hit_count + r.miss_count) > 0
      THEN ROUND((r.hit_count::numeric / (r.hit_count + r.miss_count)::numeric) * 100, 1)
      ELSE 0
    END AS hit_rate_pct
  FROM public.founder_quarterly_okr_retros_r1662 r
  ORDER BY r.quarter DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_list_quarterly_retros_r1662() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_list_quarterly_retros_r1662() TO authenticated;

-- =============================================================================
-- RPC 2 — founder_record_quarterly_retro (WRITE)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_record_quarterly_retro_r1662(
  p_quarter    text,
  p_summary_md text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_quarterly_okr_retros_r1662(quarter, summary_md, recorded_at, updated_at)
  VALUES (p_quarter, COALESCE(p_summary_md, ''), now(), now())
  ON CONFLICT (quarter) DO UPDATE
    SET summary_md  = EXCLUDED.summary_md,
        recorded_at = now(),
        updated_at  = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1662_record_quarterly_retro',
          jsonb_build_object('id', v_id, 'quarter', p_quarter));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_record_quarterly_retro_r1662(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_record_quarterly_retro_r1662(text, text) TO authenticated;

-- =============================================================================
-- RPC 3 — founder_add_retro_item (WRITE)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_add_retro_item_r1662(
  p_quarter      text,
  p_okr_id       uuid,
  p_okr_title    text,
  p_status       text,
  p_miss_reason  text,
  p_carry_forward boolean,
  p_owner        text,
  p_notes        text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_quarterly_okr_retro_items_r1662(
    retro_quarter, okr_id, okr_title, status, miss_reason, carry_forward, owner, notes, updated_at
  ) VALUES (
    p_quarter, p_okr_id, COALESCE(p_okr_title, ''), COALESCE(p_status, 'pending'),
    COALESCE(p_miss_reason, ''), COALESCE(p_carry_forward, false),
    COALESCE(p_owner, ''), COALESCE(p_notes, ''), now()
  )
  RETURNING id INTO v_id;

  -- recompute counts
  UPDATE public.founder_quarterly_okr_retros_r1662 r
     SET hit_count   = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.status = 'hit'),
         miss_count  = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.status = 'miss'),
         carry_count = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.carry_forward = true),
         updated_at  = now()
   WHERE r.quarter = p_quarter;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1662_add_retro_item',
          jsonb_build_object('id', v_id, 'quarter', p_quarter, 'okr_id', p_okr_id, 'status', p_status));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_add_retro_item_r1662(text, uuid, text, text, text, boolean, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_add_retro_item_r1662(text, uuid, text, text, text, boolean, text, text) TO authenticated;

-- =============================================================================
-- RPC 4 — founder_update_retro_item (WRITE)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_update_retro_item_r1662(
  p_item_id       uuid,
  p_status        text,
  p_miss_reason   text,
  p_carry_forward boolean,
  p_owner         text,
  p_notes         text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id      uuid;
  v_quarter text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_quarterly_okr_retro_items_r1662
     SET status        = COALESCE(p_status, status),
         miss_reason   = COALESCE(p_miss_reason, miss_reason),
         carry_forward = COALESCE(p_carry_forward, carry_forward),
         owner         = COALESCE(p_owner, owner),
         notes         = COALESCE(p_notes, notes),
         updated_at    = now()
   WHERE id = p_item_id
  RETURNING id, retro_quarter INTO v_id, v_quarter;

  IF v_id IS NULL THEN
    RAISE EXCEPTION 'item not found';
  END IF;

  -- recompute counts on parent retro
  UPDATE public.founder_quarterly_okr_retros_r1662 r
     SET hit_count   = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.status = 'hit'),
         miss_count  = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.status = 'miss'),
         carry_count = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.carry_forward = true),
         updated_at  = now()
   WHERE r.quarter = v_quarter;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1662_update_retro_item',
          jsonb_build_object('id', v_id, 'status', p_status, 'carry_forward', p_carry_forward));

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_update_retro_item_r1662(uuid, text, text, boolean, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_update_retro_item_r1662(uuid, text, text, boolean, text, text) TO authenticated;

-- =============================================================================
-- RPC 5 — founder_carry_forward_to_next_quarter (WRITE)
-- Copies all carry_forward=true items from p_from_quarter to p_to_quarter
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_carry_forward_to_next_quarter_r1662(
  p_from_quarter text,
  p_to_quarter   text
)
RETURNS int
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id    uuid;
  v_count int := 0;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  -- Ensure destination quarter exists
  INSERT INTO public.founder_quarterly_okr_retros_r1662(quarter, summary_md, recorded_at, updated_at)
  VALUES (p_to_quarter, '', now(), now())
  ON CONFLICT (quarter) DO NOTHING
  RETURNING id INTO v_id;

  -- Copy items
  WITH copied AS (
    INSERT INTO public.founder_quarterly_okr_retro_items_r1662(
      retro_quarter, okr_id, okr_title, status, miss_reason, carry_forward, owner, notes, updated_at
    )
    SELECT
      p_to_quarter, i.okr_id, i.okr_title, 'pending', i.miss_reason, false, i.owner,
      'Carried forward from ' || p_from_quarter || E'\n' || i.notes,
      now()
    FROM public.founder_quarterly_okr_retro_items_r1662 i
    WHERE i.retro_quarter = p_from_quarter
      AND i.carry_forward = true
    RETURNING id
  )
  SELECT COUNT(*)::int INTO v_count FROM copied;

  -- recompute dest counts
  UPDATE public.founder_quarterly_okr_retros_r1662 r
     SET hit_count   = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.status = 'hit'),
         miss_count  = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.status = 'miss'),
         carry_count = (SELECT COUNT(*)::int FROM public.founder_quarterly_okr_retro_items_r1662 i WHERE i.retro_quarter = r.quarter AND i.carry_forward = true),
         updated_at  = now()
   WHERE r.quarter = p_to_quarter;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1662_carry_forward_to_next_quarter',
          jsonb_build_object('from', p_from_quarter, 'to', p_to_quarter, 'count', v_count));

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_carry_forward_to_next_quarter_r1662(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_carry_forward_to_next_quarter_r1662(text, text) TO authenticated;

-- =============================================================================
-- RPC 6 — founder_quarterly_retro_summary (READ)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_quarterly_retro_summary_r1662()
RETURNS TABLE (
  quarters_recorded     int,
  total_items           int,
  total_hits            int,
  total_misses          int,
  total_partial         int,
  total_dropped         int,
  total_carry_forward   int,
  overall_hit_rate_pct  numeric,
  latest_quarter        text,
  top_miss_reason       text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH counts AS (
    SELECT
      (SELECT COUNT(*) FROM public.founder_quarterly_okr_retros_r1662)::int AS q_recorded,
      (SELECT COUNT(*) FROM public.founder_quarterly_okr_retro_items_r1662)::int AS t_items,
      (COUNT(*) FILTER (WHERE i.status = 'hit'))::int     AS t_hits,
      (COUNT(*) FILTER (WHERE i.status = 'miss'))::int    AS t_miss,
      (COUNT(*) FILTER (WHERE i.status = 'partial'))::int AS t_partial,
      (COUNT(*) FILTER (WHERE i.status = 'dropped'))::int AS t_dropped,
      (COUNT(*) FILTER (WHERE i.carry_forward = true))::int AS t_carry
    FROM public.founder_quarterly_okr_retro_items_r1662 i
  ),
  top_reason AS (
    SELECT i.miss_reason
    FROM public.founder_quarterly_okr_retro_items_r1662 i
    WHERE i.status = 'miss' AND i.miss_reason <> ''
    GROUP BY i.miss_reason
    ORDER BY COUNT(*) DESC
    LIMIT 1
  ),
  latest_q AS (
    SELECT quarter FROM public.founder_quarterly_okr_retros_r1662
    ORDER BY quarter DESC LIMIT 1
  )
  SELECT
    c.q_recorded,
    c.t_items,
    c.t_hits,
    c.t_miss,
    c.t_partial,
    c.t_dropped,
    c.t_carry,
    CASE
      WHEN (c.t_hits + c.t_miss) > 0
      THEN ROUND((c.t_hits::numeric / (c.t_hits + c.t_miss)::numeric) * 100, 1)
      ELSE 0
    END,
    COALESCE((SELECT quarter FROM latest_q), ''),
    COALESCE((SELECT miss_reason FROM top_reason), 'none')
  FROM counts c;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_quarterly_retro_summary_r1662() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_quarterly_retro_summary_r1662() TO authenticated;

-- =============================================================================
-- RPC 7 — founder_quarterly_retro_action_items (READ)
-- All items flagged carry_forward=true (the action queue)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.founder_quarterly_retro_action_items_r1662()
RETURNS TABLE (
  id            uuid,
  retro_quarter text,
  okr_id        uuid,
  okr_title     text,
  status        text,
  miss_reason   text,
  owner         text,
  notes         text,
  updated_at    timestamptz
)
LANGUAGE plpgsql
STABLE
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
    i.retro_quarter,
    i.okr_id,
    i.okr_title,
    i.status,
    i.miss_reason,
    i.owner,
    i.notes,
    i.updated_at
  FROM public.founder_quarterly_okr_retro_items_r1662 i
  WHERE i.carry_forward = true
  ORDER BY i.retro_quarter DESC, i.updated_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_quarterly_retro_action_items_r1662() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_quarterly_retro_action_items_r1662() TO authenticated;

COMMIT;