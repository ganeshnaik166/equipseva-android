BEGIN;
-- r1335 — Founder cap-table snapshot.
--
-- Equity dilution model + cap-table tracker. The founder needs a single
-- console that shows: how much of the company is owned by which class
-- (founders / employees / angels / VCs / strategic / ESOP pool), what
-- rounds have closed, what the latest post-money valuation is, and how
-- much ESOP pool is still un-granted (= hireable headroom).
--
-- This is internal corp-dev infra — board meetings, investor updates,
-- ESOP grant decisions, secondary-sale negotiations all hang off this.
--
-- Schema discipline:
--   1. shareholder_name UNIQUE — one canonical row per beneficial owner.
--      Multi-grant founders/employees aggregate offline before insert.
--   2. round_label UNIQUE — every priced round / convertible is one row.
--   3. shares_count NUMERIC bigint to support large authorised pools.
--   4. vested_pct + cliff_months + vesting_total_months are descriptive
--      only — actual vested-shares math is NOT auto-computed (founder
--      reviews quarterly + re-stamps vested_pct manually).
--
-- All RPCs are founder-only (is_founder gate). LANGUAGE plpgsql STABLE.

-- ============================================================================
-- Tables
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_cap_table_shareholders (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shareholder_name          text NOT NULL,
  shareholder_kind          text NOT NULL
    CHECK (shareholder_kind IN ('founder','employee','angel','vc','strategic','esop_pool')),
  shares_count              bigint NOT NULL CHECK (shares_count >= 0),
  investment_amount_rupees  numeric NOT NULL DEFAULT 0 CHECK (investment_amount_rupees >= 0),
  vested_pct                numeric NOT NULL DEFAULT 100
                              CHECK (vested_pct >= 0 AND vested_pct <= 100),
  cliff_months              int NOT NULL DEFAULT 0 CHECK (cliff_months >= 0),
  vesting_total_months      int NOT NULL DEFAULT 0 CHECK (vesting_total_months >= 0),
  granted_at                date,
  notes                     text,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT founder_cap_table_shareholders_name_uq UNIQUE (shareholder_name)
);
COMMENT ON TABLE public.founder_cap_table_shareholders IS
  'One row per beneficial owner. Aggregate multi-grant holders offline. esop_pool kind = un-granted headroom row.';

CREATE INDEX IF NOT EXISTS idx_cap_table_share_kind   ON public.founder_cap_table_shareholders (shareholder_kind);
CREATE INDEX IF NOT EXISTS idx_cap_table_share_count  ON public.founder_cap_table_shareholders (shares_count DESC);
CREATE INDEX IF NOT EXISTS idx_cap_table_share_granted ON public.founder_cap_table_shareholders (granted_at DESC NULLS LAST);

ALTER TABLE public.founder_cap_table_shareholders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cap_table_share_no_direct ON public.founder_cap_table_shareholders;
CREATE POLICY cap_table_share_no_direct ON public.founder_cap_table_shareholders FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_cap_table_shareholders FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.founder_cap_table_rounds (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  round_label                 text NOT NULL,
  round_kind                  text NOT NULL
    CHECK (round_kind IN ('preseed','seed','seriesA','seriesB','bridge','seed_extension','convertible')),
  pre_money_valuation_rupees  numeric NOT NULL CHECK (pre_money_valuation_rupees >= 0),
  raise_amount_rupees         numeric NOT NULL CHECK (raise_amount_rupees >= 0),
  closed_at                   date,
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT founder_cap_table_rounds_label_uq UNIQUE (round_label)
);
COMMENT ON TABLE public.founder_cap_table_rounds IS
  'One row per priced round / convertible event. post_money = pre_money + raise (computed in RPC).';

CREATE INDEX IF NOT EXISTS idx_cap_table_rounds_closed ON public.founder_cap_table_rounds (closed_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_cap_table_rounds_kind   ON public.founder_cap_table_rounds (round_kind);

ALTER TABLE public.founder_cap_table_rounds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS cap_table_rounds_no_direct ON public.founder_cap_table_rounds;
CREATE POLICY cap_table_rounds_no_direct ON public.founder_cap_table_rounds FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_cap_table_rounds FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- RPC: founder_cap_table_summary — 11 KPIs (single row)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_cap_table_summary();
CREATE OR REPLACE FUNCTION public.founder_cap_table_summary()
RETURNS TABLE (
  total_shares                bigint,
  founders_pct                numeric,
  employees_pct               numeric,
  angels_pct                  numeric,
  vcs_pct                     numeric,
  esop_pool_pct               numeric,
  available_esop_pct          numeric,
  total_raised_rupees         numeric,
  latest_round_label          text,
  latest_post_money_rupees    numeric,
  fully_diluted_shares        bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(SUM(s.shares_count), 0)::bigint INTO v_total
    FROM public.founder_cap_table_shareholders s;

  RETURN QUERY
  WITH agg AS (
    SELECT
      COALESCE(SUM(s.shares_count) FILTER (WHERE s.shareholder_kind = 'founder'),  0)::numeric AS founders_n,
      COALESCE(SUM(s.shares_count) FILTER (WHERE s.shareholder_kind = 'employee'), 0)::numeric AS employees_n,
      COALESCE(SUM(s.shares_count) FILTER (WHERE s.shareholder_kind = 'angel'),    0)::numeric AS angels_n,
      COALESCE(SUM(s.shares_count) FILTER (WHERE s.shareholder_kind IN ('vc','strategic')), 0)::numeric AS vcs_n,
      COALESCE(SUM(s.shares_count) FILTER (WHERE s.shareholder_kind = 'esop_pool'),0)::numeric AS pool_n,
      COALESCE(SUM(s.investment_amount_rupees), 0)::numeric AS invested_n
    FROM public.founder_cap_table_shareholders s
  ),
  latest AS (
    SELECT r.round_label,
           (r.pre_money_valuation_rupees + r.raise_amount_rupees)::numeric AS post_money
      FROM public.founder_cap_table_rounds r
     ORDER BY r.closed_at DESC NULLS LAST, r.created_at DESC
     LIMIT 1
  ),
  raised AS (
    SELECT COALESCE(SUM(r.raise_amount_rupees), 0)::numeric AS total_raised
      FROM public.founder_cap_table_rounds r
  )
  SELECT
    v_total                                                                            AS total_shares,
    CASE WHEN v_total > 0 THEN ROUND(agg.founders_n  * 100.0 / v_total, 2) ELSE 0 END  AS founders_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.employees_n * 100.0 / v_total, 2) ELSE 0 END  AS employees_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.angels_n    * 100.0 / v_total, 2) ELSE 0 END  AS angels_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.vcs_n       * 100.0 / v_total, 2) ELSE 0 END  AS vcs_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.pool_n      * 100.0 / v_total, 2) ELSE 0 END  AS esop_pool_pct,
    CASE WHEN v_total > 0 THEN ROUND(agg.pool_n      * 100.0 / v_total, 2) ELSE 0 END  AS available_esop_pct,
    raised.total_raised                                                                AS total_raised_rupees,
    latest.round_label                                                                 AS latest_round_label,
    latest.post_money                                                                  AS latest_post_money_rupees,
    v_total                                                                            AS fully_diluted_shares
  FROM agg, raised
  LEFT JOIN latest ON true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cap_table_summary() TO authenticated;

-- ============================================================================
-- RPC: founder_cap_table_shareholders_recent
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_cap_table_shareholders_recent(int);
CREATE OR REPLACE FUNCTION public.founder_cap_table_shareholders_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id                        uuid,
  shareholder_name          text,
  shareholder_kind          text,
  shares_count              bigint,
  ownership_pct             numeric,
  investment_amount_rupees  numeric,
  vested_pct                numeric,
  cliff_months              int,
  vesting_total_months      int,
  granted_at                date,
  notes                     text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  SELECT COALESCE(SUM(s.shares_count), 0)::bigint INTO v_total
    FROM public.founder_cap_table_shareholders s;

  RETURN QUERY
  SELECT
    s.id,
    s.shareholder_name,
    s.shareholder_kind,
    s.shares_count,
    CASE WHEN v_total > 0
         THEN ROUND(s.shares_count::numeric * 100.0 / v_total, 2)
         ELSE 0 END AS ownership_pct,
    s.investment_amount_rupees,
    s.vested_pct,
    s.cliff_months,
    s.vesting_total_months,
    s.granted_at,
    s.notes
  FROM public.founder_cap_table_shareholders s
  ORDER BY s.shares_count DESC, s.shareholder_name ASC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 500));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_shareholders_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cap_table_shareholders_recent(int) TO authenticated;

-- ============================================================================
-- RPC: founder_cap_table_rounds_recent
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_cap_table_rounds_recent(int);
CREATE OR REPLACE FUNCTION public.founder_cap_table_rounds_recent(p_limit int DEFAULT 10)
RETURNS TABLE (
  id                          uuid,
  round_label                 text,
  round_kind                  text,
  pre_money_valuation_rupees  numeric,
  raise_amount_rupees         numeric,
  post_money_rupees           numeric,
  dilution_pct                numeric,
  closed_at                   date,
  notes                       text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    r.id,
    r.round_label,
    r.round_kind,
    r.pre_money_valuation_rupees,
    r.raise_amount_rupees,
    (r.pre_money_valuation_rupees + r.raise_amount_rupees)::numeric AS post_money_rupees,
    CASE WHEN (r.pre_money_valuation_rupees + r.raise_amount_rupees) > 0
         THEN ROUND(r.raise_amount_rupees * 100.0 / (r.pre_money_valuation_rupees + r.raise_amount_rupees), 2)
         ELSE 0 END AS dilution_pct,
    r.closed_at,
    r.notes
  FROM public.founder_cap_table_rounds r
  ORDER BY r.closed_at DESC NULLS LAST, r.created_at DESC
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 10), 100));
END;
$$;

REVOKE EXECUTE ON FUNCTION public.founder_cap_table_rounds_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_cap_table_rounds_recent(int) TO authenticated;

-- ============================================================================
-- RPC: log_founder_cap_table_register_shareholder
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_cap_table_register_shareholder(text, text, bigint, numeric, numeric, int, int, date, text);
CREATE OR REPLACE FUNCTION public.log_founder_cap_table_register_shareholder(
  p_shareholder_name         text,
  p_shareholder_kind         text,
  p_shares_count             bigint,
  p_investment_amount_rupees numeric DEFAULT 0,
  p_vested_pct               numeric DEFAULT 100,
  p_cliff_months             int     DEFAULT 0,
  p_vesting_total_months     int     DEFAULT 0,
  p_granted_at               date    DEFAULT NULL,
  p_notes                    text    DEFAULT NULL
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
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_cap_table_shareholders
    (shareholder_name, shareholder_kind, shares_count, investment_amount_rupees,
     vested_pct, cliff_months, vesting_total_months, granted_at, notes)
  VALUES
    (p_shareholder_name, p_shareholder_kind, p_shares_count, COALESCE(p_investment_amount_rupees, 0),
     COALESCE(p_vested_pct, 100), COALESCE(p_cliff_months, 0), COALESCE(p_vesting_total_months, 0),
     p_granted_at, p_notes)
  ON CONFLICT (shareholder_name) DO UPDATE
    SET shareholder_kind         = EXCLUDED.shareholder_kind,
        shares_count             = EXCLUDED.shares_count,
        investment_amount_rupees = EXCLUDED.investment_amount_rupees,
        vested_pct               = EXCLUDED.vested_pct,
        cliff_months             = EXCLUDED.cliff_months,
        vesting_total_months     = EXCLUDED.vesting_total_months,
        granted_at               = EXCLUDED.granted_at,
        notes                    = EXCLUDED.notes,
        updated_at               = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cap_table_register_shareholder(text, text, bigint, numeric, numeric, int, int, date, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_cap_table_register_shareholder(text, text, bigint, numeric, numeric, int, int, date, text) TO authenticated;

-- ============================================================================
-- RPC: log_founder_cap_table_register_round
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_cap_table_register_round(text, text, numeric, numeric, date, text);
CREATE OR REPLACE FUNCTION public.log_founder_cap_table_register_round(
  p_round_label                 text,
  p_round_kind                  text,
  p_pre_money_valuation_rupees  numeric,
  p_raise_amount_rupees         numeric,
  p_closed_at                   date DEFAULT NULL,
  p_notes                       text DEFAULT NULL
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
    RAISE EXCEPTION 'founder only' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.founder_cap_table_rounds
    (round_label, round_kind, pre_money_valuation_rupees, raise_amount_rupees, closed_at, notes)
  VALUES
    (p_round_label, p_round_kind, p_pre_money_valuation_rupees, p_raise_amount_rupees, p_closed_at, p_notes)
  ON CONFLICT (round_label) DO UPDATE
    SET round_kind                 = EXCLUDED.round_kind,
        pre_money_valuation_rupees = EXCLUDED.pre_money_valuation_rupees,
        raise_amount_rupees        = EXCLUDED.raise_amount_rupees,
        closed_at                  = EXCLUDED.closed_at,
        notes                      = EXCLUDED.notes
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_founder_cap_table_register_round(text, text, numeric, numeric, date, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_cap_table_register_round(text, text, numeric, numeric, date, text) TO authenticated;

COMMIT;