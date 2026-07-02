BEGIN;

CREATE TABLE IF NOT EXISTS public.customer_renewal_objections_r2356 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objection_code text NOT NULL UNIQUE,
  objection_label text NOT NULL,
  objection_category text NOT NULL CHECK (objection_category IN ('price','value','competitor','timing','authority','trust','feature_gap','other')),
  customer_quote text NOT NULL,
  scripted_response text NOT NULL,
  rebuttal_followup text,
  evidence_links text[] DEFAULT ARRAY[]::text[],
  recommended_concession text,
  escalation_path text,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_renewal_objections_r2356_cat
  ON public.customer_renewal_objections_r2356(objection_category, is_active);

CREATE TABLE IF NOT EXISTS public.customer_renewal_objection_attempts_r2356 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  objection_id uuid NOT NULL REFERENCES public.customer_renewal_objections_r2356(id) ON DELETE CASCADE,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  handled_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  amc_contract_id uuid,
  attempted_at timestamptz NOT NULL DEFAULT now(),
  outcome text NOT NULL CHECK (outcome IN ('saved','lost','pending','escalated')),
  concession_offered_rupees integer NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_renewal_obj_attempts_r2356_obj
  ON public.customer_renewal_objection_attempts_r2356(objection_id, outcome);
CREATE INDEX IF NOT EXISTS idx_renewal_obj_attempts_r2356_time
  ON public.customer_renewal_objection_attempts_r2356(attempted_at DESC);

ALTER TABLE public.customer_renewal_objections_r2356 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_renewal_objection_attempts_r2356 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.customer_renewal_objections_r2356;
CREATE POLICY founder_all ON public.customer_renewal_objections_r2356
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.customer_renewal_objection_attempts_r2356;
CREATE POLICY founder_all ON public.customer_renewal_objection_attempts_r2356
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. List active objections with computed success rate
CREATE OR REPLACE FUNCTION public.list_renewal_objections_r2356()
RETURNS TABLE (
  id uuid,
  objection_code text,
  objection_label text,
  objection_category text,
  customer_quote text,
  scripted_response text,
  total_attempts bigint,
  saved_count bigint,
  lost_count bigint,
  pending_count bigint,
  success_rate_pct numeric,
  avg_concession_rupees numeric,
  is_active boolean
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
    o.id,
    o.objection_code,
    o.objection_label,
    o.objection_category,
    o.customer_quote,
    o.scripted_response,
    COUNT(a.id) AS total_attempts,
    COUNT(*) FILTER (WHERE a.outcome = 'saved') AS saved_count,
    COUNT(*) FILTER (WHERE a.outcome = 'lost') AS lost_count,
    COUNT(*) FILTER (WHERE a.outcome = 'pending') AS pending_count,
    CASE
      WHEN COUNT(*) FILTER (WHERE a.outcome IN ('saved','lost')) = 0 THEN 0::numeric
      ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE a.outcome = 'saved')::numeric
        / COUNT(*) FILTER (WHERE a.outcome IN ('saved','lost'))::numeric, 1)
    END AS success_rate_pct,
    COALESCE(AVG(a.concession_offered_rupees) FILTER (WHERE a.outcome = 'saved'), 0)::numeric AS avg_concession_rupees,
    o.is_active
  FROM public.customer_renewal_objections_r2356 o
  LEFT JOIN public.customer_renewal_objection_attempts_r2356 a ON a.objection_id = o.id
  GROUP BY o.id
  ORDER BY o.is_active DESC, success_rate_pct DESC NULLS LAST, o.objection_label;
END;
$$;

-- 2. Add new objection
CREATE OR REPLACE FUNCTION public.add_renewal_objection_r2356(
  p_code text,
  p_label text,
  p_category text,
  p_customer_quote text,
  p_scripted_response text,
  p_rebuttal_followup text DEFAULT NULL,
  p_recommended_concession text DEFAULT NULL,
  p_escalation_path text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_user_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_user_id FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;

  INSERT INTO public.customer_renewal_objections_r2356
    (objection_code, objection_label, objection_category, customer_quote, scripted_response,
     rebuttal_followup, recommended_concession, escalation_path, created_by)
  VALUES (p_code, p_label, p_category, p_customer_quote, p_scripted_response,
          p_rebuttal_followup, p_recommended_concession, p_escalation_path, v_user_id)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- 3. Update objection script
CREATE OR REPLACE FUNCTION public.update_renewal_objection_r2356(
  p_id uuid,
  p_scripted_response text,
  p_rebuttal_followup text DEFAULT NULL,
  p_recommended_concession text DEFAULT NULL
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

  UPDATE public.customer_renewal_objections_r2356
  SET scripted_response = p_scripted_response,
      rebuttal_followup = COALESCE(p_rebuttal_followup, rebuttal_followup),
      recommended_concession = COALESCE(p_recommended_concession, recommended_concession),
      updated_at = now()
  WHERE id = p_id;
END;
$$;

-- 4. Toggle active flag
CREATE OR REPLACE FUNCTION public.toggle_renewal_objection_active_r2356(p_id uuid, p_is_active boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.customer_renewal_objections_r2356
  SET is_active = p_is_active, updated_at = now()
  WHERE id = p_id;
END;
$$;

-- 5. Log attempt
CREATE OR REPLACE FUNCTION public.log_renewal_objection_attempt_r2356(
  p_objection_id uuid,
  p_hospital_user_id uuid,
  p_outcome text,
  p_concession_offered_rupees integer DEFAULT 0,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_handler uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_handler FROM public.profiles WHERE email = auth.jwt()->>'email' LIMIT 1;

  INSERT INTO public.customer_renewal_objection_attempts_r2356
    (objection_id, hospital_user_id, handled_by, outcome, concession_offered_rupees, notes)
  VALUES (p_objection_id, p_hospital_user_id, v_handler, p_outcome, p_concession_offered_rupees, p_notes)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

-- 6. Category-level rollup
CREATE OR REPLACE FUNCTION public.renewal_objection_category_rollup_r2356()
RETURNS TABLE (
  objection_category text,
  objection_count bigint,
  total_attempts bigint,
  saved_attempts bigint,
  success_rate_pct numeric,
  total_concession_rupees bigint
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
    o.objection_category,
    COUNT(DISTINCT o.id) AS objection_count,
    COUNT(a.id) AS total_attempts,
    COUNT(*) FILTER (WHERE a.outcome = 'saved') AS saved_attempts,
    CASE
      WHEN COUNT(*) FILTER (WHERE a.outcome IN ('saved','lost')) = 0 THEN 0::numeric
      ELSE ROUND(100.0 * COUNT(*) FILTER (WHERE a.outcome = 'saved')::numeric
        / COUNT(*) FILTER (WHERE a.outcome IN ('saved','lost'))::numeric, 1)
    END AS success_rate_pct,
    COALESCE(SUM(a.concession_offered_rupees) FILTER (WHERE a.outcome = 'saved'), 0)::bigint AS total_concession_rupees
  FROM public.customer_renewal_objections_r2356 o
  LEFT JOIN public.customer_renewal_objection_attempts_r2356 a ON a.objection_id = o.id
  GROUP BY o.objection_category
  ORDER BY total_attempts DESC;
END;
$$;

-- 7. Recent attempts feed
CREATE OR REPLACE FUNCTION public.recent_renewal_objection_attempts_r2356(p_limit integer DEFAULT 30)
RETURNS TABLE (
  attempt_id uuid,
  attempted_at timestamptz,
  objection_label text,
  objection_category text,
  outcome text,
  concession_offered_rupees integer,
  handler_email text,
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
    a.id AS attempt_id,
    a.attempted_at,
    o.objection_label,
    o.objection_category,
    a.outcome,
    a.concession_offered_rupees,
    p.email AS handler_email,
    a.notes
  FROM public.customer_renewal_objection_attempts_r2356 a
  JOIN public.customer_renewal_objections_r2356 o ON o.id = a.objection_id
  LEFT JOIN public.profiles p ON p.id = a.handled_by
  ORDER BY a.attempted_at DESC
  LIMIT GREATEST(1, LEAST(p_limit, 200));
END;
$$;

REVOKE ALL ON FUNCTION public.list_renewal_objections_r2356() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.add_renewal_objection_r2356(text, text, text, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_renewal_objection_r2356(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.toggle_renewal_objection_active_r2356(uuid, boolean) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_renewal_objection_attempt_r2356(uuid, uuid, text, integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.renewal_objection_category_rollup_r2356() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_renewal_objection_attempts_r2356(integer) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_renewal_objections_r2356() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_renewal_objection_r2356(text, text, text, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_renewal_objection_r2356(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_renewal_objection_active_r2356(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_renewal_objection_attempt_r2356(uuid, uuid, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.renewal_objection_category_rollup_r2356() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_renewal_objection_attempts_r2356(integer) TO authenticated;

COMMIT;
