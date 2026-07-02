BEGIN;

-- ============================================================================
-- Round 2225 — Founder Vendor Relationship Score
-- Score each key vendor on responsiveness, quality, price; log issues/wins
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.vendor_relationship_scores_r2225 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  vendor_name text NOT NULL,
  vendor_category text NOT NULL CHECK (vendor_category IN ('spare_parts','logistics','calibration','software','infra','marketing','legal','other')),
  responsiveness_score int NOT NULL DEFAULT 50 CHECK (responsiveness_score BETWEEN 0 AND 100),
  quality_score int NOT NULL DEFAULT 50 CHECK (quality_score BETWEEN 0 AND 100),
  price_score int NOT NULL DEFAULT 50 CHECK (price_score BETWEEN 0 AND 100),
  overall_score int NOT NULL DEFAULT 50 CHECK (overall_score BETWEEN 0 AND 100),
  monthly_spend_rupees bigint NOT NULL DEFAULT 0,
  contract_status text NOT NULL DEFAULT 'active' CHECK (contract_status IN ('active','review','at_risk','terminated','prospective')),
  primary_contact_name text,
  primary_contact_email text,
  last_review_at timestamptz,
  next_review_at timestamptz,
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vrs_r2225_overall ON public.vendor_relationship_scores_r2225(overall_score DESC);
CREATE INDEX IF NOT EXISTS idx_vrs_r2225_status ON public.vendor_relationship_scores_r2225(contract_status);
CREATE INDEX IF NOT EXISTS idx_vrs_r2225_category ON public.vendor_relationship_scores_r2225(vendor_category);

ALTER TABLE public.vendor_relationship_scores_r2225 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.vendor_relationship_scores_r2225;
CREATE POLICY founder_all ON public.vendor_relationship_scores_r2225
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.vendor_relationship_scores_r2225 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vendor_relationship_scores_r2225 TO authenticated;


CREATE TABLE IF NOT EXISTS public.vendor_action_log_r2225 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_score_id uuid NOT NULL REFERENCES public.vendor_relationship_scores_r2225(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('issue','win','review','meeting','quote','dispute','renewal','escalation')),
  severity text NOT NULL DEFAULT 'normal' CHECK (severity IN ('low','normal','high','critical')),
  title text NOT NULL,
  detail text,
  amount_rupees bigint NOT NULL DEFAULT 0,
  resolved boolean NOT NULL DEFAULT false,
  logged_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  logged_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vlog_r2225_vendor ON public.vendor_action_log_r2225(vendor_score_id, logged_at DESC);
CREATE INDEX IF NOT EXISTS idx_vlog_r2225_event ON public.vendor_action_log_r2225(event_type);

ALTER TABLE public.vendor_action_log_r2225 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.vendor_action_log_r2225;
CREATE POLICY founder_all ON public.vendor_action_log_r2225
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

REVOKE ALL ON public.vendor_action_log_r2225 FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vendor_action_log_r2225 TO authenticated;


-- ============================================================================
-- RPCs — 7 gated functions
-- ============================================================================

DROP FUNCTION IF EXISTS public.list_vendor_scores_r2225();
CREATE OR REPLACE FUNCTION public.list_vendor_scores_r2225()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_category text,
  responsiveness_score int,
  quality_score int,
  price_score int,
  overall_score int,
  monthly_spend_rupees bigint,
  contract_status text,
  last_review_at timestamptz,
  next_review_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.vendor_name, v.vendor_category, v.responsiveness_score,
           v.quality_score, v.price_score, v.overall_score,
           v.monthly_spend_rupees, v.contract_status,
           v.last_review_at, v.next_review_at
    FROM public.vendor_relationship_scores_r2225 v
    ORDER BY v.overall_score ASC, v.monthly_spend_rupees DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.list_vendor_scores_r2225() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_vendor_scores_r2225() TO authenticated;


DROP FUNCTION IF EXISTS public.recent_actions_vendor_r2225(int);
CREATE OR REPLACE FUNCTION public.recent_actions_vendor_r2225(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  vendor_score_id uuid,
  vendor_name text,
  event_type text,
  severity text,
  title text,
  detail text,
  amount_rupees bigint,
  resolved boolean,
  logged_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.vendor_score_id, v.vendor_name, l.event_type, l.severity,
           l.title, l.detail, l.amount_rupees, l.resolved, l.logged_at
    FROM public.vendor_action_log_r2225 l
    JOIN public.vendor_relationship_scores_r2225 v ON v.id = l.vendor_score_id
    ORDER BY l.logged_at DESC
    LIMIT GREATEST(1, COALESCE(p_limit, 50));
END;
$$;

REVOKE ALL ON FUNCTION public.recent_actions_vendor_r2225(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.recent_actions_vendor_r2225(int) TO authenticated;


DROP FUNCTION IF EXISTS public.top_vendors_at_risk_r2225();
CREATE OR REPLACE FUNCTION public.top_vendors_at_risk_r2225()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  overall_score int,
  monthly_spend_rupees bigint,
  contract_status text,
  open_issues int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT v.id, v.vendor_name, v.overall_score, v.monthly_spend_rupees, v.contract_status,
           (SELECT COUNT(*) FILTER (WHERE l.event_type = 'issue' AND NOT l.resolved)
              FROM public.vendor_action_log_r2225 l WHERE l.vendor_score_id = v.id)::int AS open_issues
    FROM public.vendor_relationship_scores_r2225 v
    WHERE v.overall_score < 60 OR v.contract_status IN ('at_risk','review')
    ORDER BY v.overall_score ASC, v.monthly_spend_rupees DESC
    LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.top_vendors_at_risk_r2225() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_vendors_at_risk_r2225() TO authenticated;


DROP FUNCTION IF EXISTS public.log_vendor_score_r2225(text, text, int, int, int, bigint, text, text);
CREATE OR REPLACE FUNCTION public.log_vendor_score_r2225(
  p_vendor_name text,
  p_vendor_category text,
  p_responsiveness int,
  p_quality int,
  p_price int,
  p_monthly_spend_rupees bigint,
  p_contract_status text,
  p_primary_contact_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_overall int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_overall := GREATEST(0, LEAST(100, ((COALESCE(p_responsiveness,50) + COALESCE(p_quality,50) + COALESCE(p_price,50)) / 3)));

  INSERT INTO public.vendor_relationship_scores_r2225(
    vendor_name, vendor_category, responsiveness_score, quality_score, price_score,
    overall_score, monthly_spend_rupees, contract_status, primary_contact_email,
    last_review_at, created_by
  ) VALUES (
    p_vendor_name, p_vendor_category, COALESCE(p_responsiveness,50),
    COALESCE(p_quality,50), COALESCE(p_price,50), v_overall,
    COALESCE(p_monthly_spend_rupees, 0), COALESCE(p_contract_status, 'active'),
    p_primary_contact_email, now(), auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2225_score_vendor',
    jsonb_build_object('vendor_score_id', v_id, 'vendor_name', p_vendor_name, 'overall', v_overall));

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_vendor_score_r2225(text, text, int, int, int, bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_vendor_score_r2225(text, text, int, int, int, bigint, text, text) TO authenticated;


DROP FUNCTION IF EXISTS public.log_action_vendor_event_r2225(uuid, text, text, text, text, bigint);
CREATE OR REPLACE FUNCTION public.log_action_vendor_event_r2225(
  p_vendor_score_id uuid,
  p_event_type text,
  p_severity text,
  p_title text,
  p_detail text,
  p_amount_rupees bigint
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

  INSERT INTO public.vendor_action_log_r2225(
    vendor_score_id, event_type, severity, title, detail, amount_rupees, logged_by
  ) VALUES (
    p_vendor_score_id, p_event_type, COALESCE(p_severity, 'normal'),
    p_title, p_detail, COALESCE(p_amount_rupees, 0), auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2225_log_event',
    jsonb_build_object('event_id', v_id, 'vendor_score_id', p_vendor_score_id, 'event_type', p_event_type));

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.log_action_vendor_event_r2225(uuid, text, text, text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_action_vendor_event_r2225(uuid, text, text, text, text, bigint) TO authenticated;


DROP FUNCTION IF EXISTS public.mark_status_vendor_r2225(uuid, text);
CREATE OR REPLACE FUNCTION public.mark_status_vendor_r2225(
  p_vendor_score_id uuid,
  p_contract_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.vendor_relationship_scores_r2225
     SET contract_status = p_contract_status,
         updated_at = now(),
         last_review_at = now()
   WHERE id = p_vendor_score_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'op_r2225_mark_status',
    jsonb_build_object('vendor_score_id', p_vendor_score_id, 'contract_status', p_contract_status));
END;
$$;

REVOKE ALL ON FUNCTION public.mark_status_vendor_r2225(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_status_vendor_r2225(uuid, text) TO authenticated;


DROP FUNCTION IF EXISTS public.aggregate_vendor_scores_r2225();
CREATE OR REPLACE FUNCTION public.aggregate_vendor_scores_r2225()
RETURNS TABLE (
  total_vendors int,
  active_vendors int,
  at_risk_vendors int,
  avg_overall_score int,
  avg_responsiveness int,
  avg_quality int,
  avg_price int,
  total_monthly_spend bigint,
  open_issues int,
  wins_30d int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (COUNT(*))::int AS total_vendors,
      (COUNT(*) FILTER (WHERE v.contract_status = 'active'))::int AS active_vendors,
      (COUNT(*) FILTER (WHERE v.contract_status IN ('at_risk','review') OR v.overall_score < 60))::int AS at_risk_vendors,
      (COALESCE(AVG(v.overall_score), 0))::int AS avg_overall_score,
      (COALESCE(AVG(v.responsiveness_score), 0))::int AS avg_responsiveness,
      (COALESCE(AVG(v.quality_score), 0))::int AS avg_quality,
      (COALESCE(AVG(v.price_score), 0))::int AS avg_price,
      (COALESCE(SUM(v.monthly_spend_rupees), 0))::bigint AS total_monthly_spend,
      (SELECT COUNT(*) FILTER (WHERE l.event_type = 'issue' AND NOT l.resolved)
         FROM public.vendor_action_log_r2225 l)::int AS open_issues,
      (SELECT COUNT(*) FILTER (WHERE l.event_type = 'win' AND l.logged_at > now() - interval '30 days')
         FROM public.vendor_action_log_r2225 l)::int AS wins_30d
    FROM public.vendor_relationship_scores_r2225 v;
END;
$$;

REVOKE ALL ON FUNCTION public.aggregate_vendor_scores_r2225() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.aggregate_vendor_scores_r2225() TO authenticated;

COMMIT;
