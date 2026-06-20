BEGIN;

-- Round 1514 — Founder hospital cross-sell ladder
-- For each AMC hospital, suggest next product (spare parts contract, training, equipment swap, refurbishment).
-- Tracks ladder state + founder action queue.

-- =====================================================================
-- TABLE 1: founder_hospital_cross_sell_ladder
-- One row per (hospital_org_id, product_slug) — current ladder state.
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_cross_sell_ladder (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id   uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  product_slug      text NOT NULL CHECK (product_slug IN ('spare_parts_contract','training','equipment_swap','refurbishment')),
  ladder_stage      text NOT NULL DEFAULT 'suggested' CHECK (ladder_stage IN ('suggested','pitched','interested','negotiating','won','lost','parked')),
  fit_score         int  NOT NULL DEFAULT 0,           -- 0..100 heuristic
  est_value_rupees  bigint NOT NULL DEFAULT 0,
  rationale         text,
  last_action_note  text,
  next_action_due_at timestamptz,
  founder_owned     boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hospital_org_id, product_slug)
);

CREATE INDEX IF NOT EXISTS idx_xsell_ladder_hospital ON public.founder_hospital_cross_sell_ladder (hospital_org_id);
CREATE INDEX IF NOT EXISTS idx_xsell_ladder_stage    ON public.founder_hospital_cross_sell_ladder (ladder_stage);
CREATE INDEX IF NOT EXISTS idx_xsell_ladder_due      ON public.founder_hospital_cross_sell_ladder (next_action_due_at);

ALTER TABLE public.founder_hospital_cross_sell_ladder ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS xsell_ladder_founder_only ON public.founder_hospital_cross_sell_ladder;
CREATE POLICY xsell_ladder_founder_only
  ON public.founder_hospital_cross_sell_ladder
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- TABLE 2: founder_hospital_cross_sell_action_queue
-- Founder action queue items (call/email/visit) per ladder row.
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.founder_hospital_cross_sell_action_queue (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ladder_id       uuid NOT NULL REFERENCES public.founder_hospital_cross_sell_ladder(id) ON DELETE CASCADE,
  action_kind     text NOT NULL CHECK (action_kind IN ('call','email','visit','quote','followup','close')),
  priority        text NOT NULL DEFAULT 'medium' CHECK (priority IN ('low','medium','high','urgent')),
  due_at          timestamptz NOT NULL DEFAULT now(),
  status          text NOT NULL DEFAULT 'open' CHECK (status IN ('open','in_progress','done','cancelled')),
  note            text,
  completed_at    timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_xsell_queue_ladder ON public.founder_hospital_cross_sell_action_queue (ladder_id);
CREATE INDEX IF NOT EXISTS idx_xsell_queue_status ON public.founder_hospital_cross_sell_action_queue (status, due_at);

ALTER TABLE public.founder_hospital_cross_sell_action_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS xsell_queue_founder_only ON public.founder_hospital_cross_sell_action_queue;
CREATE POLICY xsell_queue_founder_only
  ON public.founder_hospital_cross_sell_action_queue
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =====================================================================
-- HELPERS — log_founder_*
-- =====================================================================
CREATE OR REPLACE FUNCTION public.log_founder_xsell_suggest(p_ladder_id uuid, p_product_slug text, p_fit int)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'xsell_suggest',
          jsonb_build_object('ladder_id', p_ladder_id, 'product_slug', p_product_slug, 'fit_score', p_fit));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_xsell_stage_change(p_ladder_id uuid, p_from text, p_to text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'xsell_stage_change',
          jsonb_build_object('ladder_id', p_ladder_id, 'from_stage', p_from, 'to_stage', p_to));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_xsell_queue_action(p_queue_id uuid, p_action_kind text, p_priority text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'xsell_queue_action',
          jsonb_build_object('queue_id', p_queue_id, 'action_kind', p_action_kind, 'priority', p_priority));
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_xsell_close(p_ladder_id uuid, p_outcome text)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'xsell_close',
          jsonb_build_object('ladder_id', p_ladder_id, 'outcome', p_outcome));
END $$;

-- =====================================================================
-- RPC 1 (READ) — overview KPIs
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_overview()
RETURNS TABLE (
  total_amc_hospitals     bigint,
  hospitals_with_ladder   bigint,
  total_ladder_rows       bigint,
  suggested_rows          bigint,
  pitched_rows            bigint,
  interested_rows         bigint,
  negotiating_rows        bigint,
  won_rows                bigint,
  lost_rows               bigint,
  parked_rows             bigint,
  total_pipeline_rupees   bigint,
  won_pipeline_rupees     bigint,
  open_queue_items        bigint,
  overdue_queue_items     bigint,
  urgent_queue_items      bigint,
  avg_fit_score           numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH amc_h AS (
    SELECT DISTINCT p.organization_id AS org_id
    FROM public.amc_contracts c
    JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE p.organization_id IS NOT NULL
  ),
  ladder AS (SELECT * FROM public.founder_hospital_cross_sell_ladder),
  q AS (SELECT * FROM public.founder_hospital_cross_sell_action_queue)
  SELECT
    (SELECT COUNT(*) FROM amc_h),
    (SELECT COUNT(DISTINCT hospital_org_id) FROM ladder),
    (SELECT COUNT(*) FROM ladder),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='suggested'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='pitched'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='interested'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='negotiating'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='won'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='lost'),
    (SELECT COUNT(*) FROM ladder WHERE ladder_stage='parked'),
    (SELECT COALESCE(SUM(est_value_rupees),0) FROM ladder WHERE ladder_stage NOT IN ('lost','parked')),
    (SELECT COALESCE(SUM(est_value_rupees),0) FROM ladder WHERE ladder_stage='won'),
    (SELECT COUNT(*) FROM q WHERE status='open'),
    (SELECT COUNT(*) FROM q WHERE status='open' AND due_at < now()),
    (SELECT COUNT(*) FROM q WHERE status='open' AND priority='urgent'),
    (SELECT COALESCE(ROUND(AVG(fit_score)::numeric, 1), 0) FROM ladder);
END $$;

-- =====================================================================
-- RPC 2 (READ) — ladder rows with hospital + product detail
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_ladder_list()
RETURNS TABLE (
  id uuid,
  hospital_org_id uuid,
  hospital_name text,
  product_slug text,
  ladder_stage text,
  fit_score int,
  est_value_rupees bigint,
  rationale text,
  next_action_due_at timestamptz,
  days_until_due numeric,
  open_queue_items bigint,
  updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.hospital_org_id, o.name, l.product_slug, l.ladder_stage,
         l.fit_score, l.est_value_rupees, l.rationale, l.next_action_due_at,
         CASE WHEN l.next_action_due_at IS NULL THEN NULL
              ELSE ROUND((EXTRACT(EPOCH FROM (l.next_action_due_at - now()))/86400.0)::numeric, 1) END,
         (SELECT COUNT(*) FROM public.founder_hospital_cross_sell_action_queue q WHERE q.ladder_id=l.id AND q.status='open'),
         l.updated_at
  FROM public.founder_hospital_cross_sell_ladder l
  LEFT JOIN public.organizations o ON o.id = l.hospital_org_id
  ORDER BY l.fit_score DESC, l.est_value_rupees DESC NULLS LAST;
END $$;

-- =====================================================================
-- RPC 3 (READ) — action queue list
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_queue_list()
RETURNS TABLE (
  id uuid,
  ladder_id uuid,
  hospital_name text,
  product_slug text,
  action_kind text,
  priority text,
  status text,
  due_at timestamptz,
  hours_overdue numeric,
  note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.ladder_id, o.name, l.product_slug, q.action_kind, q.priority, q.status, q.due_at,
         CASE WHEN q.due_at < now() AND q.status='open'
              THEN ROUND((EXTRACT(EPOCH FROM (now() - q.due_at))/3600.0)::numeric, 1)
              ELSE 0 END,
         q.note
  FROM public.founder_hospital_cross_sell_action_queue q
  JOIN public.founder_hospital_cross_sell_ladder l ON l.id = q.ladder_id
  LEFT JOIN public.organizations o ON o.id = l.hospital_org_id
  ORDER BY (q.status='open') DESC, q.due_at ASC;
END $$;

-- =====================================================================
-- RPC 4 (READ) — per-product breakdown
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_by_product()
RETURNS TABLE (
  product_slug text,
  total_rows bigint,
  won_rows bigint,
  pipeline_rupees bigint,
  avg_fit numeric,
  open_queue bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.product_slug,
         COUNT(*),
         COUNT(*) FILTER (WHERE l.ladder_stage='won'),
         COALESCE(SUM(l.est_value_rupees) FILTER (WHERE l.ladder_stage NOT IN ('lost','parked')), 0),
         COALESCE(ROUND(AVG(l.fit_score)::numeric, 1), 0),
         (SELECT COUNT(*) FROM public.founder_hospital_cross_sell_action_queue q
          JOIN public.founder_hospital_cross_sell_ladder l2 ON l2.id=q.ladder_id
          WHERE l2.product_slug = l.product_slug AND q.status='open')
  FROM public.founder_hospital_cross_sell_ladder l
  GROUP BY l.product_slug
  ORDER BY 4 DESC;
END $$;

-- =====================================================================
-- RPC 5 (READ) — top hospitals by ladder progress
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_top_hospitals()
RETURNS TABLE (
  hospital_org_id uuid,
  hospital_name text,
  ladder_rows bigint,
  won_rows bigint,
  pipeline_rupees bigint,
  open_queue bigint,
  avg_fit numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.hospital_org_id, o.name,
         COUNT(*),
         COUNT(*) FILTER (WHERE l.ladder_stage='won'),
         COALESCE(SUM(l.est_value_rupees) FILTER (WHERE l.ladder_stage NOT IN ('lost','parked')), 0),
         (SELECT COUNT(*) FROM public.founder_hospital_cross_sell_action_queue q
          JOIN public.founder_hospital_cross_sell_ladder l2 ON l2.id=q.ladder_id
          WHERE l2.hospital_org_id = l.hospital_org_id AND q.status='open'),
         COALESCE(ROUND(AVG(l.fit_score)::numeric, 1), 0)
  FROM public.founder_hospital_cross_sell_ladder l
  LEFT JOIN public.organizations o ON o.id = l.hospital_org_id
  GROUP BY l.hospital_org_id, o.name
  ORDER BY 5 DESC NULLS LAST
  LIMIT 50;
END $$;

-- =====================================================================
-- RPC 6 (WRITE) — seed/suggest a ladder row
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_suggest(
  p_hospital_org_id uuid,
  p_product_slug text,
  p_fit_score int DEFAULT 50,
  p_est_value_rupees bigint DEFAULT 0,
  p_rationale text DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_hospital_cross_sell_ladder (hospital_org_id, product_slug, ladder_stage, fit_score, est_value_rupees, rationale)
  VALUES (p_hospital_org_id, p_product_slug, 'suggested', GREATEST(0, LEAST(100, p_fit_score)), GREATEST(0, p_est_value_rupees), p_rationale)
  ON CONFLICT (hospital_org_id, product_slug) DO UPDATE
    SET fit_score = EXCLUDED.fit_score,
        est_value_rupees = EXCLUDED.est_value_rupees,
        rationale = EXCLUDED.rationale,
        updated_at = now()
  RETURNING id INTO v_id;
  PERFORM public.log_founder_xsell_suggest(v_id, p_product_slug, p_fit_score);
  RETURN v_id;
END $$;

-- =====================================================================
-- RPC 7 (WRITE) — advance ladder stage
-- =====================================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_xsell_set_stage(
  p_ladder_id uuid,
  p_new_stage text,
  p_note text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_old text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT ladder_stage INTO v_old FROM public.founder_hospital_cross_sell_ladder WHERE id = p_ladder_id;
  IF v_old IS NULL THEN RAISE EXCEPTION 'ladder row not found'; END IF;
  UPDATE public.founder_hospital_cross_sell_ladder
     SET ladder_stage = p_new_stage,
         last_action_note = COALESCE(p_note, last_action_note),
         updated_at = now()
   WHERE id = p_ladder_id;
  PERFORM public.log_founder_xsell_stage_change(p_ladder_id, v_old, p_new_stage);
  IF p_new_stage IN ('won','lost') THEN
    PERFORM public.log_founder_xsell_close(p_ladder_id, p_new_stage);
  END IF;
END $$;

-- =====================================================================
-- GRANTS
-- =====================================================================
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_overview()        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_ladder_list()     FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_queue_list()      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_by_product()      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_top_hospitals()   FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_suggest(uuid,text,int,bigint,text)        FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_hospital_xsell_set_stage(uuid,text,text)                 FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_overview()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_ladder_list()     TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_queue_list()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_by_product()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_top_hospitals()   TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_suggest(uuid,text,int,bigint,text)        TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_hospital_xsell_set_stage(uuid,text,text)                 TO authenticated;

COMMIT;