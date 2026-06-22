BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_customer_saturation_index_r2007 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  region_label text NOT NULL,
  hospital_category text NOT NULL CHECK (hospital_category IN ('tier1','tier2','super_specialty','teaching','government','private')),
  total_addressable bigint NOT NULL DEFAULT 0,
  customers_won int NOT NULL DEFAULT 0,
  customers_lost int NOT NULL DEFAULT 0,
  saturation_pct numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'growing' CHECK (status IN ('growing','saturated','declining','recovering')),
  captured_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_saturation_action_log_r2007 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  saturation_id uuid NOT NULL REFERENCES public.hospital_customer_saturation_index_r2007(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('market_expansion','penetration_call','competitive_review','region_pivot')),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_customer_saturation_index_r2007 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_saturation_action_log_r2007 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2007_idx ON public.hospital_customer_saturation_index_r2007;
CREATE POLICY founder_all_r2007_idx ON public.hospital_customer_saturation_index_r2007
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2007_act ON public.hospital_saturation_action_log_r2007;
CREATE POLICY founder_all_r2007_act ON public.hospital_saturation_action_log_r2007
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_saturation_indices_r2007()
RETURNS SETOF public.hospital_customer_saturation_index_r2007
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_saturation_index_r2007 ORDER BY captured_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_saturation_index_r2007(
  p_region text,
  p_category text,
  p_total bigint,
  p_won int,
  p_lost int,
  p_pct numeric,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_customer_saturation_index_r2007(region_label, hospital_category, total_addressable, customers_won, customers_lost, saturation_pct, status)
  VALUES (p_region, p_category, p_total, p_won, p_lost, p_pct, p_status)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_saturation_index_r2007', jsonb_build_object('id', v_id, 'region', p_region, 'category', p_category));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_saturation_actions_r2007(p_id uuid)
RETURNS SETOF public.hospital_saturation_action_log_r2007
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_saturation_action_log_r2007 WHERE saturation_id = p_id ORDER BY taken_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.log_saturation_action_r2007(
  p_saturation_id uuid,
  p_action_type text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_saturation_action_log_r2007(saturation_id, action_type, by_email, notes_md)
  VALUES (p_saturation_id, p_action_type, (auth.jwt()->>'email'), p_notes)
  RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_saturation_action_r2007', jsonb_build_object('id', v_id, 'saturation_id', p_saturation_id, 'action_type', p_action_type));
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.mark_saturation_status_r2007(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_customer_saturation_index_r2007 SET status = p_status, updated_at = now() WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_saturation_status_r2007', jsonb_build_object('id', p_id, 'status', p_status));
END $$;

CREATE OR REPLACE FUNCTION public.saturated_regions_r2007()
RETURNS SETOF public.hospital_customer_saturation_index_r2007
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_customer_saturation_index_r2007 WHERE status = 'saturated' ORDER BY saturation_pct DESC;
END $$;

CREATE OR REPLACE FUNCTION public.recent_saturation_actions_r2007(p_limit int DEFAULT 50)
RETURNS SETOF public.hospital_saturation_action_log_r2007
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT * FROM public.hospital_saturation_action_log_r2007 ORDER BY taken_at DESC LIMIT p_limit;
END $$;

REVOKE EXECUTE ON FUNCTION public.list_saturation_indices_r2007() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_saturation_index_r2007(text, text, bigint, int, int, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_saturation_actions_r2007(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_saturation_action_r2007(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_saturation_status_r2007(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.saturated_regions_r2007() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_saturation_actions_r2007(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_saturation_indices_r2007() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_saturation_index_r2007(text, text, bigint, int, int, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_saturation_actions_r2007(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_saturation_action_r2007(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_saturation_status_r2007(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.saturated_regions_r2007() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_saturation_actions_r2007(int) TO authenticated;

COMMIT;
