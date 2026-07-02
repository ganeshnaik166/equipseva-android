BEGIN;

-- =========================================================================
-- Round 1847: Hospital Customer Concentration Risk
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.hospital_concentration_metrics_r1847 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date date NOT NULL UNIQUE,
  top_1_revenue_pct numeric(6,2) NOT NULL DEFAULT 0,
  top_3_revenue_pct numeric(6,2) NOT NULL DEFAULT 0,
  top_5_revenue_pct numeric(6,2) NOT NULL DEFAULT 0,
  top_10_revenue_pct numeric(6,2) NOT NULL DEFAULT 0,
  total_arr_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_concentration_at_risk_r1847 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid NOT NULL REFERENCES public.hospital_concentration_metrics_r1847(id) ON DELETE CASCADE,
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  arr_pct numeric(6,2) NOT NULL DEFAULT 0,
  revenue_share_class text NOT NULL CHECK (revenue_share_class IN ('critical','high','medium')),
  risk_signal_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hcm_r1847_date ON public.hospital_concentration_metrics_r1847(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_hcm_r1847_status ON public.hospital_concentration_metrics_r1847(status);
CREATE INDEX IF NOT EXISTS idx_hcar_r1847_snap ON public.hospital_concentration_at_risk_r1847(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_hcar_r1847_hosp ON public.hospital_concentration_at_risk_r1847(hospital_user_id);

ALTER TABLE public.hospital_concentration_metrics_r1847 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_concentration_at_risk_r1847 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p_hcm_r1847_founder ON public.hospital_concentration_metrics_r1847;
CREATE POLICY p_hcm_r1847_founder ON public.hospital_concentration_metrics_r1847
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS p_hcar_r1847_founder ON public.hospital_concentration_at_risk_r1847;
CREATE POLICY p_hcar_r1847_founder ON public.hospital_concentration_at_risk_r1847
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.list_snapshots_r1847();
CREATE OR REPLACE FUNCTION public.list_snapshots_r1847()
RETURNS TABLE (
  id uuid,
  snapshot_date date,
  top_1_revenue_pct numeric,
  top_3_revenue_pct numeric,
  top_5_revenue_pct numeric,
  top_10_revenue_pct numeric,
  total_arr_rupees bigint,
  status text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.snapshot_date, m.top_1_revenue_pct, m.top_3_revenue_pct,
         m.top_5_revenue_pct, m.top_10_revenue_pct, m.total_arr_rupees,
         m.status, m.created_at
  FROM public.hospital_concentration_metrics_r1847 m
  ORDER BY m.snapshot_date DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.take_snapshot_r1847(date, numeric, numeric, numeric, numeric, bigint);
CREATE OR REPLACE FUNCTION public.take_snapshot_r1847(
  p_snapshot_date date,
  p_top_1 numeric,
  p_top_3 numeric,
  p_top_5 numeric,
  p_top_10 numeric,
  p_total_arr bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  UPDATE public.hospital_concentration_metrics_r1847
    SET status = 'superseded', updated_at = now()
    WHERE status = 'current';

  INSERT INTO public.hospital_concentration_metrics_r1847
    (snapshot_date, top_1_revenue_pct, top_3_revenue_pct, top_5_revenue_pct,
     top_10_revenue_pct, total_arr_rupees, status)
  VALUES (p_snapshot_date, p_top_1, p_top_3, p_top_5, p_top_10, p_total_arr, 'current')
  ON CONFLICT (snapshot_date) DO UPDATE
    SET top_1_revenue_pct = EXCLUDED.top_1_revenue_pct,
        top_3_revenue_pct = EXCLUDED.top_3_revenue_pct,
        top_5_revenue_pct = EXCLUDED.top_5_revenue_pct,
        top_10_revenue_pct = EXCLUDED.top_10_revenue_pct,
        total_arr_rupees = EXCLUDED.total_arr_rupees,
        status = 'current',
        updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1847.take_snapshot',
    jsonb_build_object(
      'snapshot_id', v_id,
      'snapshot_date', p_snapshot_date,
      'top_1', p_top_1,
      'top_3', p_top_3,
      'top_5', p_top_5,
      'top_10', p_top_10,
      'total_arr', p_total_arr
    )
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_at_risk_r1847(uuid);
CREATE OR REPLACE FUNCTION public.list_at_risk_r1847(p_snapshot_id uuid)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  arr_pct numeric,
  revenue_share_class text,
  risk_signal_md text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.hospital_user_id, p.email::text, r.arr_pct,
         r.revenue_share_class, r.risk_signal_md, r.created_at
  FROM public.hospital_concentration_at_risk_r1847 r
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  WHERE r.snapshot_id = p_snapshot_id
  ORDER BY r.arr_pct DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_at_risk_r1847(uuid, uuid, numeric, text, text);
CREATE OR REPLACE FUNCTION public.log_at_risk_r1847(
  p_snapshot_id uuid,
  p_hospital_user_id uuid,
  p_arr_pct numeric,
  p_revenue_share_class text,
  p_risk_signal_md text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.hospital_concentration_at_risk_r1847
    (snapshot_id, hospital_user_id, arr_pct, revenue_share_class, risk_signal_md)
  VALUES (p_snapshot_id, p_hospital_user_id, p_arr_pct, p_revenue_share_class, p_risk_signal_md)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'r1847.log_at_risk',
    jsonb_build_object(
      'risk_id', v_id,
      'snapshot_id', p_snapshot_id,
      'hospital_user_id', p_hospital_user_id,
      'arr_pct', p_arr_pct,
      'class', p_revenue_share_class
    )
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.top_concentrated_r1847();
CREATE OR REPLACE FUNCTION public.top_concentrated_r1847()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  arr_pct numeric,
  revenue_share_class text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.hospital_user_id, p.email::text, r.arr_pct, r.revenue_share_class
  FROM public.hospital_concentration_at_risk_r1847 r
  JOIN public.hospital_concentration_metrics_r1847 m ON m.id = r.snapshot_id
  LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
  WHERE m.status = 'current'
  ORDER BY r.arr_pct DESC
  LIMIT 25;
END;
$$;

DROP FUNCTION IF EXISTS public.trend_top_5_r1847();
CREATE OR REPLACE FUNCTION public.trend_top_5_r1847()
RETURNS TABLE (
  snapshot_date date,
  top_5_revenue_pct numeric,
  total_arr_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.snapshot_date, m.top_5_revenue_pct, m.total_arr_rupees
  FROM public.hospital_concentration_metrics_r1847 m
  ORDER BY m.snapshot_date DESC
  LIMIT 24;
END;
$$;

DROP FUNCTION IF EXISTS public.risk_summary_r1847();
CREATE OR REPLACE FUNCTION public.risk_summary_r1847()
RETURNS TABLE (
  total_snapshots int,
  current_top_1 numeric,
  current_top_5 numeric,
  current_top_10 numeric,
  current_arr_rupees bigint,
  critical_count int,
  high_count int,
  medium_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_snap_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT id INTO v_snap_id
  FROM public.hospital_concentration_metrics_r1847
  WHERE status = 'current'
  ORDER BY snapshot_date DESC
  LIMIT 1;

  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::int FROM public.hospital_concentration_metrics_r1847),
    COALESCE((SELECT top_1_revenue_pct FROM public.hospital_concentration_metrics_r1847 WHERE id = v_snap_id), 0::numeric),
    COALESCE((SELECT top_5_revenue_pct FROM public.hospital_concentration_metrics_r1847 WHERE id = v_snap_id), 0::numeric),
    COALESCE((SELECT top_10_revenue_pct FROM public.hospital_concentration_metrics_r1847 WHERE id = v_snap_id), 0::numeric),
    COALESCE((SELECT total_arr_rupees FROM public.hospital_concentration_metrics_r1847 WHERE id = v_snap_id), 0::bigint),
    (COUNT(*) FILTER (WHERE r.revenue_share_class = 'critical' AND r.snapshot_id = v_snap_id))::int,
    (COUNT(*) FILTER (WHERE r.revenue_share_class = 'high' AND r.snapshot_id = v_snap_id))::int,
    (COUNT(*) FILTER (WHERE r.revenue_share_class = 'medium' AND r.snapshot_id = v_snap_id))::int
  FROM public.hospital_concentration_at_risk_r1847 r;
END;
$$;

-- =========================================================================
-- Grants
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_snapshots_r1847() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.take_snapshot_r1847(date, numeric, numeric, numeric, numeric, bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_at_risk_r1847(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_at_risk_r1847(uuid, uuid, numeric, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_concentrated_r1847() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.trend_top_5_r1847() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.risk_summary_r1847() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_snapshots_r1847() TO authenticated;
GRANT EXECUTE ON FUNCTION public.take_snapshot_r1847(date, numeric, numeric, numeric, numeric, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_at_risk_r1847(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_at_risk_r1847(uuid, uuid, numeric, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_concentrated_r1847() TO authenticated;
GRANT EXECUTE ON FUNCTION public.trend_top_5_r1847() TO authenticated;
GRANT EXECUTE ON FUNCTION public.risk_summary_r1847() TO authenticated;

COMMIT;