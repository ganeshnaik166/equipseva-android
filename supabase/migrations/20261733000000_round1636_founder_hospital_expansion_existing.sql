BEGIN;

-- =============================================================
-- r1636 — Founder Hospital Expansion (Existing AMC base)
-- Identify upsell candidates from current AMC contracts,
-- per-hospital expansion playbook, founder action queue.
-- =============================================================

-- ---- Tables ----
CREATE TABLE IF NOT EXISTS public.founder_hospital_expansion_plays (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL,
  play_kind text NOT NULL CHECK (play_kind IN ('tier_upgrade','category_expand','multi_site','cross_sell_parts','cross_sell_training')),
  current_tier text,
  target_tier text,
  current_categories text[] DEFAULT ARRAY[]::text[],
  target_categories text[] DEFAULT ARRAY[]::text[],
  monthly_uplift_rupees numeric(14,2) DEFAULT 0,
  confidence_score numeric(5,2) DEFAULT 0,
  rationale text,
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','contacted','negotiating','won','lost','dropped')),
  founder_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fhep_hospital ON public.founder_hospital_expansion_plays(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fhep_status ON public.founder_hospital_expansion_plays(status);

ALTER TABLE public.founder_hospital_expansion_plays ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fhep_founder_only ON public.founder_hospital_expansion_plays;
CREATE POLICY fhep_founder_only ON public.founder_hospital_expansion_plays
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.founder_hospital_expansion_action_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL,
  play_id uuid REFERENCES public.founder_hospital_expansion_plays(id) ON DELETE CASCADE,
  action_kind text NOT NULL CHECK (action_kind IN ('call','email','site_visit','quote_send','contract_draft')),
  due_date date NOT NULL DEFAULT (now()::date),
  priority int NOT NULL DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
  done boolean NOT NULL DEFAULT false,
  done_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fheaq_hospital ON public.founder_hospital_expansion_action_queue(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fheaq_due ON public.founder_hospital_expansion_action_queue(due_date) WHERE done = false;

ALTER TABLE public.founder_hospital_expansion_action_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fheaq_founder_only ON public.founder_hospital_expansion_action_queue;
CREATE POLICY fheaq_founder_only ON public.founder_hospital_expansion_action_queue
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ---- log helper ----
CREATE OR REPLACE FUNCTION public.log_founder_hospital_expansion_existing(p_op text, p_after jsonb)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value, created_at)
  VALUES (auth.uid(), (auth.jwt()->>'email'), p_op, p_after, now());
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_hospital_expansion_existing(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_hospital_expansion_existing(text, jsonb) TO authenticated;

-- =============================================================
-- RPC 1: upsell candidates from existing AMC base
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_candidates()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_name text,
  state text,
  active_amcs bigint,
  current_tier text,
  current_categories text[],
  ltm_repair_spend_rupees numeric,
  jobs_ltm bigint,
  avg_rating numeric,
  upgrade_signal_score numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH amc AS (
    SELECT a.hospital_user_id,
           count(*) AS active_amcs,
           max(a.amc_tier) AS current_tier,
           coalesce(array_agg(DISTINCT cat) FILTER (WHERE cat IS NOT NULL), ARRAY[]::text[]) AS current_categories
    FROM public.amc_contracts a
    LEFT JOIN LATERAL unnest(a.equipment_categories) cat ON true
    GROUP BY a.hospital_user_id
  ),
  jobs AS (
    SELECT r.hospital_org_id,
           coalesce(sum(r.contracted_amount_rupees),0) AS spend,
           count(*) AS jobs_ltm,
           avg(r.hospital_rating) AS avg_rating
    FROM public.repair_jobs r
    WHERE r.created_at > now() - interval '365 days'
    GROUP BY r.hospital_org_id
  )
  SELECT p.id,
         coalesce(o.legal_name, p.full_name, p.email) AS hospital_name,
         o.state,
         coalesce(amc.active_amcs,0),
         amc.current_tier,
         coalesce(amc.current_categories, ARRAY[]::text[]),
         coalesce(j.spend, 0),
         coalesce(j.jobs_ltm, 0),
         round(coalesce(j.avg_rating,0)::numeric, 2),
         round(
           (coalesce(j.spend,0)/10000.0)
           + (coalesce(j.jobs_ltm,0) * 2)
           + (coalesce(j.avg_rating,0) * 5)
         , 2) AS upgrade_signal_score
  FROM public.profiles p
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  LEFT JOIN amc ON amc.hospital_user_id = p.id
  LEFT JOIN jobs j ON j.hospital_org_id = p.organization_id
  WHERE amc.active_amcs > 0
  ORDER BY upgrade_signal_score DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_candidates() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_candidates() TO authenticated;

-- =============================================================
-- RPC 2: per-hospital playbook
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_playbook(p_hospital_user_id uuid)
RETURNS TABLE (
  play_kind text,
  suggested_target text,
  monthly_uplift_rupees numeric,
  confidence_score numeric,
  rationale text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  WITH a AS (
    SELECT max(amc_tier) AS tier,
           coalesce(sum(monthly_fee_rupees),0) AS monthly_fee,
           coalesce(array_agg(DISTINCT cat) FILTER (WHERE cat IS NOT NULL), ARRAY[]::text[]) AS cats
    FROM public.amc_contracts ac
    LEFT JOIN LATERAL unnest(ac.equipment_categories) cat ON true
    WHERE ac.hospital_user_id = p_hospital_user_id
  ),
  j AS (
    SELECT count(*) AS jobs_ltm,
           coalesce(sum(contracted_amount_rupees),0) AS spend,
           avg(hospital_rating) AS rating
    FROM public.repair_jobs r
    JOIN public.profiles p ON p.organization_id = r.hospital_org_id
    WHERE p.id = p_hospital_user_id
      AND r.created_at > now() - interval '365 days'
  )
  SELECT 'tier_upgrade'::text,
         CASE WHEN (SELECT tier FROM a) = 'basic' THEN 'standard'
              WHEN (SELECT tier FROM a) = 'standard' THEN 'premium'
              ELSE 'enterprise' END,
         round((SELECT monthly_fee FROM a) * 0.6, 2),
         round(least(95, 40 + coalesce((SELECT rating FROM j),0) * 10)::numeric, 2),
         'Stable AMC + positive ratings indicate upsell to next tier'
  UNION ALL
  SELECT 'category_expand',
         'add adjacent equipment categories',
         round(coalesce((SELECT monthly_fee FROM a),0) * 0.35, 2),
         70.0,
         'Customer covers ' || coalesce(array_length((SELECT cats FROM a),1),0)::text || ' categories; expansion likely'
  UNION ALL
  SELECT 'cross_sell_parts',
         'spare-parts subscription bundle',
         round(coalesce((SELECT spend FROM j),0) * 0.10 / 12.0, 2),
         60.0,
         'LTM repair spend suggests recurring parts demand'
  UNION ALL
  SELECT 'cross_sell_training',
         'biomed staff training package',
         15000.0,
         50.0,
         'Training reduces preventable failures, anchors retention';
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_playbook(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_playbook(uuid) TO authenticated;

-- =============================================================
-- RPC 3: action queue list
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_action_queue()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  action_kind text,
  due_date date,
  priority int,
  done boolean,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT q.id,
         q.hospital_user_id,
         coalesce(o.legal_name, p.full_name, p.email) AS hospital_name,
         q.action_kind,
         q.due_date,
         q.priority,
         q.done,
         q.notes,
         q.created_at
  FROM public.founder_hospital_expansion_action_queue q
  LEFT JOIN public.profiles p ON p.id = q.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY q.done ASC, q.priority ASC, q.due_date ASC
  LIMIT 300;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_action_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_action_queue() TO authenticated;

-- =============================================================
-- RPC 4: plays list
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_plays_list()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_name text,
  play_kind text,
  current_tier text,
  target_tier text,
  monthly_uplift_rupees numeric,
  confidence_score numeric,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT pl.id,
         pl.hospital_user_id,
         coalesce(o.legal_name, p.full_name, p.email),
         pl.play_kind,
         pl.current_tier,
         pl.target_tier,
         pl.monthly_uplift_rupees,
         pl.confidence_score,
         pl.status,
         pl.created_at
  FROM public.founder_hospital_expansion_plays pl
  LEFT JOIN public.profiles p ON p.id = pl.hospital_user_id
  LEFT JOIN public.organizations o ON o.id = p.organization_id
  ORDER BY pl.created_at DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_plays_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_plays_list() TO authenticated;

-- =============================================================
-- RPC 5: summary KPIs
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_summary()
RETURNS TABLE (
  candidate_hospitals bigint,
  open_plays bigint,
  pipeline_monthly_uplift_rupees numeric,
  won_monthly_uplift_rupees numeric,
  open_actions bigint,
  overdue_actions bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    (SELECT count(DISTINCT hospital_user_id) FROM public.amc_contracts),
    (SELECT count(*) FROM public.founder_hospital_expansion_plays WHERE status IN ('queued','contacted','negotiating')),
    (SELECT coalesce(sum(monthly_uplift_rupees),0) FROM public.founder_hospital_expansion_plays WHERE status IN ('queued','contacted','negotiating')),
    (SELECT coalesce(sum(monthly_uplift_rupees),0) FROM public.founder_hospital_expansion_plays WHERE status = 'won'),
    (SELECT count(*) FROM public.founder_hospital_expansion_action_queue WHERE done = false),
    (SELECT count(*) FROM public.founder_hospital_expansion_action_queue WHERE done = false AND due_date < (now()::date));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_summary() TO authenticated;

-- =============================================================
-- RPC 6: create play (VOLATILE write)
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_create_play(
  p_hospital_user_id uuid,
  p_play_kind text,
  p_target_tier text,
  p_monthly_uplift_rupees numeric,
  p_rationale text
)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_hospital_expansion_plays(
    hospital_user_id, play_kind, target_tier, monthly_uplift_rupees, rationale
  ) VALUES (
    p_hospital_user_id, p_play_kind, p_target_tier, p_monthly_uplift_rupees, p_rationale
  ) RETURNING id INTO v_id;

  PERFORM public.log_founder_hospital_expansion_existing(
    'create_play',
    jsonb_build_object('play_id', v_id, 'hospital_user_id', p_hospital_user_id, 'kind', p_play_kind)
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_create_play(uuid, text, text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_create_play(uuid, text, text, numeric, text) TO authenticated;

-- =============================================================
-- RPC 7: mark action done (VOLATILE write)
-- =============================================================
CREATE OR REPLACE FUNCTION public.founder_hospital_expansion_existing_action_done(p_action_id uuid)
RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_hospital_expansion_action_queue
  SET done = true, done_at = now()
  WHERE id = p_action_id;

  PERFORM public.log_founder_hospital_expansion_existing(
    'action_done',
    jsonb_build_object('action_id', p_action_id)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_action_done(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_hospital_expansion_existing_action_done(uuid) TO authenticated;

COMMIT;