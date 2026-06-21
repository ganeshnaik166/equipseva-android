BEGIN;

-- Tables ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.hospital_vendor_listings_r1683 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  vendor_name text NOT NULL,
  equipment_category text NOT NULL,
  annual_spend_rupees bigint NOT NULL DEFAULT 0,
  contract_end date,
  replaceable boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hvl_r1683_hospital ON public.hospital_vendor_listings_r1683(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hvl_r1683_replaceable ON public.hospital_vendor_listings_r1683(replaceable);

CREATE TABLE IF NOT EXISTS public.hospital_vendor_consolidation_actions_r1683 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id uuid NOT NULL REFERENCES public.hospital_vendor_listings_r1683(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('switch_to_us','co_market','wait','skip')),
  decided_at timestamptz NOT NULL DEFAULT now(),
  decided_by_email text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done')),
  projected_saving_rupees bigint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hvca_r1683_listing ON public.hospital_vendor_consolidation_actions_r1683(listing_id);
CREATE INDEX IF NOT EXISTS idx_hvca_r1683_status ON public.hospital_vendor_consolidation_actions_r1683(status);

ALTER TABLE public.hospital_vendor_listings_r1683 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_vendor_consolidation_actions_r1683 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hvl_r1683_founder ON public.hospital_vendor_listings_r1683;
CREATE POLICY hvl_r1683_founder ON public.hospital_vendor_listings_r1683
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hvca_r1683_founder ON public.hospital_vendor_consolidation_actions_r1683;
CREATE POLICY hvca_r1683_founder ON public.hospital_vendor_consolidation_actions_r1683
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPCs -----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.list_listings_r1683()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  vendor_name text,
  equipment_category text,
  annual_spend_rupees bigint,
  contract_end date,
  replaceable boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.hospital_user_id, p.email::text, l.vendor_name, l.equipment_category,
         l.annual_spend_rupees, l.contract_end, l.replaceable, l.created_at
  FROM public.hospital_vendor_listings_r1683 l
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  ORDER BY l.annual_spend_rupees DESC NULLS LAST, l.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_listing_r1683(
  p_hospital_user_id uuid,
  p_vendor_name text,
  p_equipment_category text,
  p_annual_spend_rupees bigint,
  p_contract_end date,
  p_replaceable boolean
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_vendor_listings_r1683(
    hospital_user_id, vendor_name, equipment_category, annual_spend_rupees, contract_end, replaceable
  ) VALUES (
    p_hospital_user_id, p_vendor_name, p_equipment_category,
    COALESCE(p_annual_spend_rupees,0), p_contract_end, COALESCE(p_replaceable,false)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1683_add_listing',
    jsonb_build_object('listing_id', v_id, 'hospital_user_id', p_hospital_user_id,
                       'vendor_name', p_vendor_name, 'annual_spend_rupees', p_annual_spend_rupees));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_actions_r1683()
RETURNS TABLE (
  id uuid,
  listing_id uuid,
  vendor_name text,
  hospital_email text,
  action_type text,
  decided_at timestamptz,
  decided_by_email text,
  status text,
  projected_saving_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.listing_id, l.vendor_name, p.email::text, a.action_type, a.decided_at,
         a.decided_by_email, a.status, a.projected_saving_rupees
  FROM public.hospital_vendor_consolidation_actions_r1683 a
  JOIN public.hospital_vendor_listings_r1683 l ON l.id = a.listing_id
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  ORDER BY a.decided_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_action_r1683(
  p_listing_id uuid,
  p_action_type text,
  p_projected_saving_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_vendor_consolidation_actions_r1683(
    listing_id, action_type, decided_by_email, projected_saving_rupees
  ) VALUES (
    p_listing_id, p_action_type, (auth.jwt()->>'email'), COALESCE(p_projected_saving_rupees,0)
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1683_log_action',
    jsonb_build_object('action_id', v_id, 'listing_id', p_listing_id,
                       'action_type', p_action_type,
                       'projected_saving_rupees', p_projected_saving_rupees));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_action_r1683(p_action_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_vendor_consolidation_actions_r1683
     SET status = 'done', updated_at = now()
   WHERE id = p_action_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1683_complete_action',
    jsonb_build_object('action_id', p_action_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.savings_summary_r1683()
RETURNS TABLE (
  total_listings int,
  total_replaceable int,
  total_annual_spend_rupees bigint,
  pending_actions int,
  in_progress_actions int,
  done_actions int,
  projected_saving_rupees bigint,
  realized_saving_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*) FROM public.hospital_vendor_listings_r1683)::int,
    (SELECT (COUNT(*) FILTER (WHERE replaceable))::int FROM public.hospital_vendor_listings_r1683),
    COALESCE((SELECT SUM(annual_spend_rupees) FROM public.hospital_vendor_listings_r1683),0)::bigint,
    (SELECT (COUNT(*) FILTER (WHERE status = 'pending'))::int FROM public.hospital_vendor_consolidation_actions_r1683),
    (SELECT (COUNT(*) FILTER (WHERE status = 'in_progress'))::int FROM public.hospital_vendor_consolidation_actions_r1683),
    (SELECT (COUNT(*) FILTER (WHERE status = 'done'))::int FROM public.hospital_vendor_consolidation_actions_r1683),
    COALESCE((SELECT SUM(projected_saving_rupees) FROM public.hospital_vendor_consolidation_actions_r1683),0)::bigint,
    COALESCE((SELECT SUM(projected_saving_rupees) FROM public.hospital_vendor_consolidation_actions_r1683 WHERE status = 'done'),0)::bigint;
END;
$$;

CREATE OR REPLACE FUNCTION public.replaceable_vendors_top_n_r1683(p_limit int)
RETURNS TABLE (
  id uuid,
  vendor_name text,
  equipment_category text,
  hospital_email text,
  annual_spend_rupees bigint,
  contract_end date
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.vendor_name, l.equipment_category, p.email::text,
         l.annual_spend_rupees, l.contract_end
  FROM public.hospital_vendor_listings_r1683 l
  LEFT JOIN public.profiles p ON p.id = l.hospital_user_id
  WHERE l.replaceable = true
  ORDER BY l.annual_spend_rupees DESC NULLS LAST
  LIMIT COALESCE(p_limit, 10);
END;
$$;

-- Grants ---------------------------------------------------------------------

REVOKE EXECUTE ON FUNCTION public.list_listings_r1683() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_listing_r1683(uuid, text, text, bigint, date, boolean) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_actions_r1683() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_action_r1683(uuid, text, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.complete_action_r1683(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.savings_summary_r1683() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.replaceable_vendors_top_n_r1683(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_listings_r1683() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_listing_r1683(uuid, text, text, bigint, date, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_actions_r1683() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r1683(uuid, text, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_action_r1683(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.savings_summary_r1683() TO authenticated;
GRANT EXECUTE ON FUNCTION public.replaceable_vendors_top_n_r1683(int) TO authenticated;

COMMIT;