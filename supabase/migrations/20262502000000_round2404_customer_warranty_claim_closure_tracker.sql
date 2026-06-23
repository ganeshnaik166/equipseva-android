BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_warranty_claims_r2404 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_model text NOT NULL,
  serial_no text,
  vendor_name text NOT NULL,
  defect_summary text NOT NULL,
  claim_opened_at timestamptz NOT NULL DEFAULT now(),
  rma_number text,
  rma_status text NOT NULL DEFAULT 'pending' CHECK (rma_status IN ('pending','approved','shipped','received','rejected','closed')),
  rma_requested_at timestamptz,
  rma_approved_at timestamptz,
  closed_at timestamptz,
  resolution text CHECK (resolution IN ('repair','replace','refund','denied') OR resolution IS NULL),
  satisfaction_score int CHECK (satisfaction_score BETWEEN 1 AND 5 OR satisfaction_score IS NULL),
  satisfaction_comment text,
  satisfaction_collected_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_warranty_claim_events_r2404 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.founder_warranty_claims_r2404(id) ON DELETE CASCADE,
  event_type text NOT NULL CHECK (event_type IN ('opened','rma_requested','rma_approved','rma_shipped','rma_received','closed','satisfaction_logged','note')),
  event_at timestamptz NOT NULL DEFAULT now(),
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_warranty_claims_r2404 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_warranty_claim_events_r2404 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_warranty_claims_r2404 ON public.founder_warranty_claims_r2404;
CREATE POLICY founder_all_warranty_claims_r2404 ON public.founder_warranty_claims_r2404
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_warranty_events_r2404 ON public.founder_warranty_claim_events_r2404;
CREATE POLICY founder_all_warranty_events_r2404 ON public.founder_warranty_claim_events_r2404
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS idx_wclaims_r2404_status ON public.founder_warranty_claims_r2404(rma_status);
CREATE INDEX IF NOT EXISTS idx_wclaims_r2404_customer ON public.founder_warranty_claims_r2404(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_wclaims_r2404_vendor ON public.founder_warranty_claims_r2404(vendor_name);
CREATE INDEX IF NOT EXISTS idx_wclaims_r2404_opened ON public.founder_warranty_claims_r2404(claim_opened_at);
CREATE INDEX IF NOT EXISTS idx_wclaim_events_r2404_claim ON public.founder_warranty_claim_events_r2404(claim_id);
CREATE INDEX IF NOT EXISTS idx_wclaim_events_r2404_type ON public.founder_warranty_claim_events_r2404(event_type);

DROP FUNCTION IF EXISTS public.list_warranty_claims_r2404();
CREATE OR REPLACE FUNCTION public.list_warranty_claims_r2404()
RETURNS TABLE (
  id uuid,
  customer_user_id uuid,
  equipment_model text,
  serial_no text,
  vendor_name text,
  defect_summary text,
  claim_opened_at timestamptz,
  rma_number text,
  rma_status text,
  rma_requested_at timestamptz,
  rma_approved_at timestamptz,
  closed_at timestamptz,
  resolution text,
  satisfaction_score int,
  satisfaction_comment text,
  satisfaction_collected_at timestamptz,
  days_open int,
  is_open boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.customer_user_id, c.equipment_model, c.serial_no, c.vendor_name,
         c.defect_summary, c.claim_opened_at, c.rma_number, c.rma_status,
         c.rma_requested_at, c.rma_approved_at, c.closed_at, c.resolution,
         c.satisfaction_score, c.satisfaction_comment, c.satisfaction_collected_at,
         (EXTRACT(EPOCH FROM (COALESCE(c.closed_at, now()) - c.claim_opened_at)) / 86400.0)::int AS days_open,
         (c.closed_at IS NULL) AS is_open
  FROM public.founder_warranty_claims_r2404 c
  ORDER BY (c.closed_at IS NULL) DESC, c.claim_opened_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.open_warranty_claim_r2404(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.open_warranty_claim_r2404(
  p_customer_user_id uuid,
  p_equipment_model text,
  p_serial_no text,
  p_vendor_name text,
  p_defect_summary text
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
  INSERT INTO public.founder_warranty_claims_r2404(
    customer_user_id, equipment_model, serial_no, vendor_name, defect_summary
  ) VALUES (
    p_customer_user_id, p_equipment_model, p_serial_no, p_vendor_name, p_defect_summary
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_warranty_claim_events_r2404(claim_id, event_type, note)
  VALUES (v_id, 'opened', p_defect_summary);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'open_warranty_claim_r2404',
    jsonb_build_object('id', v_id, 'customer_user_id', p_customer_user_id, 'vendor', p_vendor_name));

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.update_rma_status_r2404(uuid, text, text);
CREATE OR REPLACE FUNCTION public.update_rma_status_r2404(
  p_claim_id uuid,
  p_new_status text,
  p_rma_number text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_new_status NOT IN ('pending','approved','shipped','received','rejected','closed') THEN
    RAISE EXCEPTION 'invalid rma_status %', p_new_status;
  END IF;

  UPDATE public.founder_warranty_claims_r2404
     SET rma_status = p_new_status,
         rma_number = COALESCE(p_rma_number, rma_number),
         rma_requested_at = CASE WHEN p_new_status = 'pending' AND rma_requested_at IS NULL THEN now() ELSE rma_requested_at END,
         rma_approved_at = CASE WHEN p_new_status = 'approved' AND rma_approved_at IS NULL THEN now() ELSE rma_approved_at END,
         updated_at = now()
   WHERE id = p_claim_id;

  INSERT INTO public.founder_warranty_claim_events_r2404(claim_id, event_type, note)
  VALUES (
    p_claim_id,
    CASE p_new_status
      WHEN 'pending' THEN 'rma_requested'
      WHEN 'approved' THEN 'rma_approved'
      WHEN 'shipped' THEN 'rma_shipped'
      WHEN 'received' THEN 'rma_received'
      ELSE 'note'
    END,
    'status -> ' || p_new_status
  );

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_rma_status_r2404',
    jsonb_build_object('id', p_claim_id, 'status', p_new_status));

  RETURN p_claim_id;
END;
$$;

DROP FUNCTION IF EXISTS public.close_warranty_claim_r2404(uuid, text);
CREATE OR REPLACE FUNCTION public.close_warranty_claim_r2404(
  p_claim_id uuid,
  p_resolution text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_resolution NOT IN ('repair','replace','refund','denied') THEN
    RAISE EXCEPTION 'invalid resolution %', p_resolution;
  END IF;

  UPDATE public.founder_warranty_claims_r2404
     SET closed_at = now(),
         rma_status = 'closed',
         resolution = p_resolution,
         updated_at = now()
   WHERE id = p_claim_id
     AND closed_at IS NULL;

  INSERT INTO public.founder_warranty_claim_events_r2404(claim_id, event_type, note)
  VALUES (p_claim_id, 'closed', 'resolution=' || p_resolution);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'close_warranty_claim_r2404',
    jsonb_build_object('id', p_claim_id, 'resolution', p_resolution));

  RETURN p_claim_id;
END;
$$;

DROP FUNCTION IF EXISTS public.log_warranty_satisfaction_r2404(uuid, int, text);
CREATE OR REPLACE FUNCTION public.log_warranty_satisfaction_r2404(
  p_claim_id uuid,
  p_score int,
  p_comment text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_score IS NULL OR p_score < 1 OR p_score > 5 THEN
    RAISE EXCEPTION 'score must be 1..5';
  END IF;

  UPDATE public.founder_warranty_claims_r2404
     SET satisfaction_score = p_score,
         satisfaction_comment = p_comment,
         satisfaction_collected_at = now(),
         updated_at = now()
   WHERE id = p_claim_id;

  INSERT INTO public.founder_warranty_claim_events_r2404(claim_id, event_type, note)
  VALUES (p_claim_id, 'satisfaction_logged', 'score=' || p_score::text);

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_warranty_satisfaction_r2404',
    jsonb_build_object('id', p_claim_id, 'score', p_score));

  RETURN p_claim_id;
END;
$$;

DROP FUNCTION IF EXISTS public.vendor_warranty_summary_r2404();
CREATE OR REPLACE FUNCTION public.vendor_warranty_summary_r2404()
RETURNS TABLE (
  vendor_name text,
  total_claims int,
  open_claims int,
  closed_claims int,
  avg_days_to_close numeric,
  avg_satisfaction numeric,
  last_claim_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.vendor_name,
         COUNT(*)::int AS total_claims,
         COUNT(*) FILTER (WHERE c.closed_at IS NULL)::int AS open_claims,
         COUNT(*) FILTER (WHERE c.closed_at IS NOT NULL)::int AS closed_claims,
         ROUND(AVG(EXTRACT(EPOCH FROM (c.closed_at - c.claim_opened_at)) / 86400.0)
               FILTER (WHERE c.closed_at IS NOT NULL)::numeric, 2) AS avg_days_to_close,
         ROUND(AVG(c.satisfaction_score)::numeric, 2) AS avg_satisfaction,
         MAX(c.claim_opened_at) AS last_claim_at
  FROM public.founder_warranty_claims_r2404 c
  GROUP BY c.vendor_name
  ORDER BY open_claims DESC, total_claims DESC
  LIMIT 50;
END;
$$;

DROP FUNCTION IF EXISTS public.list_warranty_events_r2404(uuid);
CREATE OR REPLACE FUNCTION public.list_warranty_events_r2404(p_claim_id uuid)
RETURNS TABLE (
  id uuid,
  claim_id uuid,
  event_type text,
  event_at timestamptz,
  note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.claim_id, e.event_type, e.event_at, e.note
  FROM public.founder_warranty_claim_events_r2404 e
  WHERE e.claim_id = p_claim_id
  ORDER BY e.event_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_warranty_claims_r2404() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_warranty_claim_r2404(uuid, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_rma_status_r2404(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.close_warranty_claim_r2404(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_warranty_satisfaction_r2404(uuid, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vendor_warranty_summary_r2404() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_warranty_events_r2404(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_warranty_claims_r2404() TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_warranty_claim_r2404(uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_rma_status_r2404(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_warranty_claim_r2404(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_warranty_satisfaction_r2404(uuid, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendor_warranty_summary_r2404() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_warranty_events_r2404(uuid) TO authenticated;

COMMIT;
