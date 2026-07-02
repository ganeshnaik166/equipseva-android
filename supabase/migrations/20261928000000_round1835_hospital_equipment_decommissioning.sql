BEGIN;

-- ============================================================================
-- Round 1835 — Hospital Equipment Decommissioning
-- Track when hospitals decommission old equipment (signal for new sales)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hospital_equipment_decommissioning_r1835 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  equipment_name text NOT NULL,
  manufacturer text,
  install_year int,
  decommission_date date NOT NULL,
  reason text NOT NULL CHECK (reason IN ('obsolete','breakdown','regulatory','upgrade','cost')),
  our_sales_response text NOT NULL DEFAULT 'no_pitch' CHECK (our_sales_response IN ('pitched','quoted','won','lost','no_pitch')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_decomm_r1835_hospital ON public.hospital_equipment_decommissioning_r1835(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_decomm_r1835_date ON public.hospital_equipment_decommissioning_r1835(decommission_date DESC);
CREATE INDEX IF NOT EXISTS idx_decomm_r1835_response ON public.hospital_equipment_decommissioning_r1835(our_sales_response);

CREATE TABLE IF NOT EXISTS public.hospital_decommission_replacement_log_r1835 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  decomm_id uuid NOT NULL REFERENCES public.hospital_equipment_decommissioning_r1835(id) ON DELETE CASCADE,
  replacement_status text NOT NULL CHECK (replacement_status IN ('ours','competitor','none','pending')),
  replacement_make text,
  sale_value_rupees bigint DEFAULT 0,
  decided_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_decomm_repl_r1835_decomm ON public.hospital_decommission_replacement_log_r1835(decomm_id);
CREATE INDEX IF NOT EXISTS idx_decomm_repl_r1835_status ON public.hospital_decommission_replacement_log_r1835(replacement_status);

ALTER TABLE public.hospital_equipment_decommissioning_r1835 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_decommission_replacement_log_r1835 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_decomm_r1835 ON public.hospital_equipment_decommissioning_r1835;
CREATE POLICY founder_all_decomm_r1835 ON public.hospital_equipment_decommissioning_r1835
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_repl_r1835 ON public.hospital_decommission_replacement_log_r1835;
CREATE POLICY founder_all_repl_r1835 ON public.hospital_decommission_replacement_log_r1835
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_decommissioning
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_decommissioning_r1835()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_name text,
  manufacturer text,
  install_year int,
  decommission_date date,
  reason text,
  our_sales_response text,
  notes text,
  created_at timestamptz
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
  SELECT d.id, d.hospital_user_id, p.email, d.equipment_name, d.manufacturer,
         d.install_year, d.decommission_date, d.reason, d.our_sales_response, d.notes, d.created_at
  FROM public.hospital_equipment_decommissioning_r1835 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  ORDER BY d.decommission_date DESC NULLS LAST, d.created_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 2: log_decommissioning
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_decommissioning_r1835(
  p_hospital_user_id uuid,
  p_equipment_name text,
  p_manufacturer text,
  p_install_year int,
  p_decommission_date date,
  p_reason text,
  p_our_sales_response text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_equipment_decommissioning_r1835(
    hospital_user_id, equipment_name, manufacturer, install_year,
    decommission_date, reason, our_sales_response, notes
  ) VALUES (
    p_hospital_user_id, p_equipment_name, p_manufacturer, p_install_year,
    p_decommission_date, p_reason, COALESCE(p_our_sales_response, 'no_pitch'), p_notes
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_decommissioning_r1835',
    jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'equipment_name', p_equipment_name, 'reason', p_reason)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 3: list_replacements
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_replacements_r1835(p_decomm_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  decomm_id uuid,
  equipment_name text,
  hospital_email text,
  replacement_status text,
  replacement_make text,
  sale_value_rupees bigint,
  decided_at timestamptz,
  notes text,
  created_at timestamptz
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
  SELECT r.id, r.decomm_id, d.equipment_name, p.email, r.replacement_status,
         r.replacement_make, r.sale_value_rupees, r.decided_at, r.notes, r.created_at
  FROM public.hospital_decommission_replacement_log_r1835 r
  LEFT JOIN public.hospital_equipment_decommissioning_r1835 d ON d.id = r.decomm_id
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  WHERE (p_decomm_id IS NULL OR r.decomm_id = p_decomm_id)
  ORDER BY r.created_at DESC
  LIMIT 500;
END;
$$;

-- ============================================================================
-- RPC 4: log_replacement
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_replacement_r1835(
  p_decomm_id uuid,
  p_replacement_status text,
  p_replacement_make text,
  p_sale_value_rupees bigint,
  p_decided_at timestamptz,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  INSERT INTO public.hospital_decommission_replacement_log_r1835(
    decomm_id, replacement_status, replacement_make, sale_value_rupees, decided_at, notes
  ) VALUES (
    p_decomm_id, p_replacement_status, p_replacement_make,
    COALESCE(p_sale_value_rupees, 0), p_decided_at, p_notes
  ) RETURNING id INTO v_id;

  -- mirror sales response on parent decomm row when replacement is ours/competitor
  IF p_replacement_status = 'ours' THEN
    UPDATE public.hospital_equipment_decommissioning_r1835
       SET our_sales_response = 'won', updated_at = now()
     WHERE id = p_decomm_id;
  ELSIF p_replacement_status = 'competitor' THEN
    UPDATE public.hospital_equipment_decommissioning_r1835
       SET our_sales_response = 'lost', updated_at = now()
     WHERE id = p_decomm_id;
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_replacement_r1835',
    jsonb_build_object('id', v_id, 'decomm_id', p_decomm_id, 'replacement_status', p_replacement_status, 'sale_value_rupees', p_sale_value_rupees)
  );

  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: our_win_rate
-- ============================================================================
CREATE OR REPLACE FUNCTION public.our_win_rate_r1835()
RETURNS TABLE (
  total_decommissions int,
  pitched_count int,
  quoted_count int,
  won_count int,
  lost_count int,
  no_pitch_count int,
  win_rate_pct numeric,
  pitch_rate_pct numeric
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
    COUNT(*)::int AS total_decommissions,
    (COUNT(*) FILTER (WHERE our_sales_response = 'pitched'))::int AS pitched_count,
    (COUNT(*) FILTER (WHERE our_sales_response = 'quoted'))::int AS quoted_count,
    (COUNT(*) FILTER (WHERE our_sales_response = 'won'))::int AS won_count,
    (COUNT(*) FILTER (WHERE our_sales_response = 'lost'))::int AS lost_count,
    (COUNT(*) FILTER (WHERE our_sales_response = 'no_pitch'))::int AS no_pitch_count,
    CASE
      WHEN (COUNT(*) FILTER (WHERE our_sales_response IN ('won','lost'))) = 0 THEN 0::numeric
      ELSE ROUND(
        100.0 * (COUNT(*) FILTER (WHERE our_sales_response = 'won'))::numeric
             / NULLIF((COUNT(*) FILTER (WHERE our_sales_response IN ('won','lost')))::numeric, 0),
        2
      )
    END AS win_rate_pct,
    CASE
      WHEN COUNT(*) = 0 THEN 0::numeric
      ELSE ROUND(
        100.0 * (COUNT(*) FILTER (WHERE our_sales_response <> 'no_pitch'))::numeric
             / NULLIF(COUNT(*)::numeric, 0),
        2
      )
    END AS pitch_rate_pct
  FROM public.hospital_equipment_decommissioning_r1835;
END;
$$;

-- ============================================================================
-- RPC 6: upcoming_decommissioning
-- ============================================================================
CREATE OR REPLACE FUNCTION public.upcoming_decommissioning_r1835()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  equipment_name text,
  manufacturer text,
  install_year int,
  decommission_date date,
  reason text,
  our_sales_response text,
  days_until int
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
  SELECT d.id, d.hospital_user_id, p.email, d.equipment_name, d.manufacturer,
         d.install_year, d.decommission_date, d.reason, d.our_sales_response,
         (d.decommission_date - CURRENT_DATE)::int AS days_until
  FROM public.hospital_equipment_decommissioning_r1835 d
  LEFT JOIN public.profiles p ON p.id = d.hospital_user_id
  WHERE d.decommission_date >= CURRENT_DATE
  ORDER BY d.decommission_date ASC
  LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 7: replacement_revenue
-- ============================================================================
CREATE OR REPLACE FUNCTION public.replacement_revenue_r1835()
RETURNS TABLE (
  total_replacements int,
  ours_count int,
  competitor_count int,
  none_count int,
  pending_count int,
  our_revenue_rupees bigint,
  competitor_revenue_rupees bigint,
  total_market_rupees bigint
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
    COUNT(*)::int AS total_replacements,
    (COUNT(*) FILTER (WHERE replacement_status = 'ours'))::int AS ours_count,
    (COUNT(*) FILTER (WHERE replacement_status = 'competitor'))::int AS competitor_count,
    (COUNT(*) FILTER (WHERE replacement_status = 'none'))::int AS none_count,
    (COUNT(*) FILTER (WHERE replacement_status = 'pending'))::int AS pending_count,
    COALESCE(SUM(sale_value_rupees) FILTER (WHERE replacement_status = 'ours'), 0)::bigint AS our_revenue_rupees,
    COALESCE(SUM(sale_value_rupees) FILTER (WHERE replacement_status = 'competitor'), 0)::bigint AS competitor_revenue_rupees,
    COALESCE(SUM(sale_value_rupees), 0)::bigint AS total_market_rupees
  FROM public.hospital_decommission_replacement_log_r1835;
END;
$$;

-- ============================================================================
-- REVOKE + GRANT
-- ============================================================================
REVOKE EXECUTE ON FUNCTION public.list_decommissioning_r1835() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_decommissioning_r1835(uuid, text, text, int, date, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_replacements_r1835(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_replacement_r1835(uuid, text, text, bigint, timestamptz, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.our_win_rate_r1835() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upcoming_decommissioning_r1835() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.replacement_revenue_r1835() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_decommissioning_r1835() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_decommissioning_r1835(uuid, text, text, int, date, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_replacements_r1835(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_replacement_r1835(uuid, text, text, bigint, timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.our_win_rate_r1835() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upcoming_decommissioning_r1835() TO authenticated;
GRANT EXECUTE ON FUNCTION public.replacement_revenue_r1835() TO authenticated;

COMMIT;