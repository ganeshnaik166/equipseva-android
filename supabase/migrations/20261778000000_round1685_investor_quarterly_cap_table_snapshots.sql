BEGIN;

CREATE TABLE IF NOT EXISTS public.cap_table_quarterly_snapshots_r1685 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quarter text UNIQUE NOT NULL,
  total_shares bigint NOT NULL DEFAULT 0,
  total_diluted bigint NOT NULL DEFAULT 0,
  snapshot_taken_at timestamptz NOT NULL DEFAULT now(),
  fully_diluted_pct_founder numeric(6,2) NOT NULL DEFAULT 0,
  fully_diluted_pct_employees numeric(6,2) NOT NULL DEFAULT 0,
  fully_diluted_pct_investors numeric(6,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.cap_table_shareholder_snapshots_r1685 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_id uuid NOT NULL REFERENCES public.cap_table_quarterly_snapshots_r1685(id) ON DELETE CASCADE,
  shareholder_name text NOT NULL,
  shares bigint NOT NULL DEFAULT 0,
  pct numeric(6,2) NOT NULL DEFAULT 0,
  shareholder_type text NOT NULL CHECK (shareholder_type IN ('founder','employee','investor','advisor','option_pool')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cap_table_shareholder_r1685_snapshot ON public.cap_table_shareholder_snapshots_r1685(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_cap_table_shareholder_r1685_type ON public.cap_table_shareholder_snapshots_r1685(shareholder_type);

ALTER TABLE public.cap_table_quarterly_snapshots_r1685 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cap_table_shareholder_snapshots_r1685 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_cap_snap_r1685 ON public.cap_table_quarterly_snapshots_r1685;
CREATE POLICY founder_all_cap_snap_r1685 ON public.cap_table_quarterly_snapshots_r1685
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_sh_snap_r1685 ON public.cap_table_shareholder_snapshots_r1685;
CREATE POLICY founder_all_sh_snap_r1685 ON public.cap_table_shareholder_snapshots_r1685
  FOR ALL USING (public.is_founder()) WITH CHECK (public.is_founder());

CREATE OR REPLACE FUNCTION public.list_quarterly_snapshots_r1685()
RETURNS TABLE(id uuid, quarter text, total_shares bigint, total_diluted bigint, snapshot_taken_at timestamptz, fully_diluted_pct_founder numeric, fully_diluted_pct_employees numeric, fully_diluted_pct_investors numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.quarter, s.total_shares, s.total_diluted, s.snapshot_taken_at,
         s.fully_diluted_pct_founder, s.fully_diluted_pct_employees, s.fully_diluted_pct_investors
  FROM public.cap_table_quarterly_snapshots_r1685 s
  ORDER BY s.snapshot_taken_at DESC
  LIMIT 200;
END $$;

CREATE OR REPLACE FUNCTION public.take_snapshot_r1685(p_quarter text, p_total_shares bigint, p_total_diluted bigint, p_pct_founder numeric, p_pct_employees numeric, p_pct_investors numeric)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.cap_table_quarterly_snapshots_r1685(quarter, total_shares, total_diluted, fully_diluted_pct_founder, fully_diluted_pct_employees, fully_diluted_pct_investors)
  VALUES (p_quarter, p_total_shares, p_total_diluted, p_pct_founder, p_pct_employees, p_pct_investors)
  ON CONFLICT (quarter) DO UPDATE SET
    total_shares = EXCLUDED.total_shares,
    total_diluted = EXCLUDED.total_diluted,
    fully_diluted_pct_founder = EXCLUDED.fully_diluted_pct_founder,
    fully_diluted_pct_employees = EXCLUDED.fully_diluted_pct_employees,
    fully_diluted_pct_investors = EXCLUDED.fully_diluted_pct_investors,
    snapshot_taken_at = now(),
    updated_at = now()
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r1685_take_snapshot',
    jsonb_build_object('quarter', p_quarter, 'total_shares', p_total_shares, 'snapshot_id', v_id));

  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.list_shareholders_per_snapshot_r1685(p_snapshot_id uuid)
RETURNS TABLE(id uuid, shareholder_name text, shares bigint, pct numeric, shareholder_type text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT sh.id, sh.shareholder_name, sh.shares, sh.pct, sh.shareholder_type
  FROM public.cap_table_shareholder_snapshots_r1685 sh
  WHERE sh.snapshot_id = p_snapshot_id
  ORDER BY sh.shares DESC;
END $$;

CREATE OR REPLACE FUNCTION public.dilution_trend_r1685()
RETURNS TABLE(quarter text, snapshot_taken_at timestamptz, pct_founder numeric, pct_employees numeric, pct_investors numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter, s.snapshot_taken_at,
         s.fully_diluted_pct_founder, s.fully_diluted_pct_employees, s.fully_diluted_pct_investors
  FROM public.cap_table_quarterly_snapshots_r1685 s
  ORDER BY s.snapshot_taken_at ASC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.top_shareholders_latest_r1685()
RETURNS TABLE(shareholder_name text, shares bigint, pct numeric, shareholder_type text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_latest uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT s.id INTO v_latest FROM public.cap_table_quarterly_snapshots_r1685 s
  ORDER BY s.snapshot_taken_at DESC LIMIT 1;

  RETURN QUERY
  SELECT sh.shareholder_name, sh.shares, sh.pct, sh.shareholder_type
  FROM public.cap_table_shareholder_snapshots_r1685 sh
  WHERE sh.snapshot_id = v_latest
  ORDER BY sh.shares DESC
  LIMIT 10;
END $$;

CREATE OR REPLACE FUNCTION public.founder_dilution_trend_r1685()
RETURNS TABLE(quarter text, snapshot_taken_at timestamptz, pct_founder numeric, delta_pct numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.quarter, s.snapshot_taken_at, s.fully_diluted_pct_founder,
         (s.fully_diluted_pct_founder - LAG(s.fully_diluted_pct_founder) OVER (ORDER BY s.snapshot_taken_at ASC))::numeric AS delta_pct
  FROM public.cap_table_quarterly_snapshots_r1685 s
  ORDER BY s.snapshot_taken_at ASC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.snapshot_comparison_r1685(p_quarter_a text, p_quarter_b text)
RETURNS TABLE(metric text, value_a numeric, value_b numeric, delta numeric)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE a record; b record;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT * INTO a FROM public.cap_table_quarterly_snapshots_r1685 WHERE quarter = p_quarter_a;
  SELECT * INTO b FROM public.cap_table_quarterly_snapshots_r1685 WHERE quarter = p_quarter_b;

  RETURN QUERY
  SELECT 'total_shares'::text, a.total_shares::numeric, b.total_shares::numeric, (b.total_shares - a.total_shares)::numeric
  UNION ALL
  SELECT 'total_diluted'::text, a.total_diluted::numeric, b.total_diluted::numeric, (b.total_diluted - a.total_diluted)::numeric
  UNION ALL
  SELECT 'pct_founder'::text, a.fully_diluted_pct_founder, b.fully_diluted_pct_founder, (b.fully_diluted_pct_founder - a.fully_diluted_pct_founder)
  UNION ALL
  SELECT 'pct_employees'::text, a.fully_diluted_pct_employees, b.fully_diluted_pct_employees, (b.fully_diluted_pct_employees - a.fully_diluted_pct_employees)
  UNION ALL
  SELECT 'pct_investors'::text, a.fully_diluted_pct_investors, b.fully_diluted_pct_investors, (b.fully_diluted_pct_investors - a.fully_diluted_pct_investors);
END $$;

REVOKE EXECUTE ON FUNCTION public.list_quarterly_snapshots_r1685() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.take_snapshot_r1685(text,bigint,bigint,numeric,numeric,numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_shareholders_per_snapshot_r1685(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.dilution_trend_r1685() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_shareholders_latest_r1685() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_dilution_trend_r1685() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.snapshot_comparison_r1685(text,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_quarterly_snapshots_r1685() TO authenticated;
GRANT EXECUTE ON FUNCTION public.take_snapshot_r1685(text,bigint,bigint,numeric,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_shareholders_per_snapshot_r1685(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.dilution_trend_r1685() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_shareholders_latest_r1685() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_dilution_trend_r1685() TO authenticated;
GRANT EXECUTE ON FUNCTION public.snapshot_comparison_r1685(text,text) TO authenticated;

COMMIT;