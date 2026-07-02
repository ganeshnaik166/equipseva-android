BEGIN;

-- ============================================================================
-- r2202 — Investor Secondary Market Interest Tracker
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_secondary_interests_r2202 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text,
  investor_org text,
  side text NOT NULL CHECK (side IN ('buy','sell')),
  share_class text NOT NULL DEFAULT 'common' CHECK (share_class IN ('common','preferred','seed','seriesA','seriesB','esop')),
  shares_qty int NOT NULL CHECK (shares_qty > 0),
  price_min_rupees numeric(14,2) NOT NULL CHECK (price_min_rupees >= 0),
  price_max_rupees numeric(14,2) NOT NULL CHECK (price_max_rupees >= 0),
  implied_valuation_cr numeric(14,2),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','matched','executed','withdrawn','expired')),
  source text,
  notes text,
  expires_at timestamptz,
  submitted_by_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_secondary_matches_r2202 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  buy_interest_id uuid NOT NULL REFERENCES public.investor_secondary_interests_r2202(id) ON DELETE CASCADE,
  sell_interest_id uuid NOT NULL REFERENCES public.investor_secondary_interests_r2202(id) ON DELETE CASCADE,
  matched_shares_qty int NOT NULL CHECK (matched_shares_qty > 0),
  matched_price_rupees numeric(14,2) NOT NULL CHECK (matched_price_rupees >= 0),
  match_status text NOT NULL DEFAULT 'proposed' CHECK (match_status IN ('proposed','in_diligence','docs_sent','closed','cancelled')),
  match_notes text,
  matched_by_user_id uuid REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isi_r2202_side_status ON public.investor_secondary_interests_r2202(side, status);
CREATE INDEX IF NOT EXISTS idx_isi_r2202_created ON public.investor_secondary_interests_r2202(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ism_r2202_status ON public.investor_secondary_matches_r2202(match_status);

ALTER TABLE public.investor_secondary_interests_r2202 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_secondary_matches_r2202 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.investor_secondary_interests_r2202;
CREATE POLICY founder_all ON public.investor_secondary_interests_r2202
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.investor_secondary_matches_r2202;
CREATE POLICY founder_all ON public.investor_secondary_matches_r2202
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- ============================================================================
-- RPC 1: list_interests_r2202
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_interests_r2202()
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_org text,
  side text,
  share_class text,
  shares_qty int,
  price_min_rupees numeric,
  price_max_rupees numeric,
  implied_valuation_cr numeric,
  status text,
  created_at timestamptz,
  expires_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.id, i.investor_name, i.investor_org, i.side, i.share_class,
           i.shares_qty, i.price_min_rupees, i.price_max_rupees,
           i.implied_valuation_cr, i.status, i.created_at, i.expires_at
      FROM public.investor_secondary_interests_r2202 i
     ORDER BY i.created_at DESC
     LIMIT 200;
END;
$$;

-- ============================================================================
-- RPC 2: recent_actions_r2202
-- ============================================================================
CREATE OR REPLACE FUNCTION public.recent_actions_r2202()
RETURNS TABLE (
  id bigint,
  op_name text,
  actor_email text,
  after_value jsonb,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT a.id, a.op_name, a.actor_email, a.after_value, a.created_at
      FROM public.founder_action_log a
     WHERE a.op_name LIKE '%_r2202'
     ORDER BY a.created_at DESC
     LIMIT 100;
END;
$$;

-- ============================================================================
-- RPC 3: top_side_r2202 — top side/status groupings
-- ============================================================================
CREATE OR REPLACE FUNCTION public.top_side_r2202()
RETURNS TABLE (
  side text,
  open_count int,
  matched_count int,
  total_shares bigint,
  avg_price_min numeric,
  avg_price_max numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT i.side,
           (COUNT(*) FILTER (WHERE i.status = 'open'))::int AS open_count,
           (COUNT(*) FILTER (WHERE i.status = 'matched'))::int AS matched_count,
           COALESCE(SUM(i.shares_qty), 0)::bigint AS total_shares,
           ROUND(AVG(i.price_min_rupees)::numeric, 2) AS avg_price_min,
           ROUND(AVG(i.price_max_rupees)::numeric, 2) AS avg_price_max
      FROM public.investor_secondary_interests_r2202 i
     GROUP BY i.side
     ORDER BY total_shares DESC;
END;
$$;

-- ============================================================================
-- RPC 4: log_interest_r2202 — insert a new investor interest
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_interest_r2202(
  p_investor_name text,
  p_investor_email text,
  p_investor_org text,
  p_side text,
  p_share_class text,
  p_shares_qty int,
  p_price_min_rupees numeric,
  p_price_max_rupees numeric,
  p_implied_valuation_cr numeric,
  p_source text,
  p_notes text,
  p_expires_at timestamptz
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_secondary_interests_r2202(
    investor_name, investor_email, investor_org, side, share_class,
    shares_qty, price_min_rupees, price_max_rupees, implied_valuation_cr,
    source, notes, expires_at, submitted_by_user_id
  ) VALUES (
    p_investor_name, p_investor_email, p_investor_org, p_side, p_share_class,
    p_shares_qty, p_price_min_rupees, p_price_max_rupees, p_implied_valuation_cr,
    p_source, p_notes, p_expires_at, auth.uid()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_interest_r2202',
          jsonb_build_object('id', v_id, 'side', p_side, 'shares_qty', p_shares_qty,
                             'price_min', p_price_min_rupees, 'price_max', p_price_max_rupees));
  RETURN v_id;
END;
$$;

-- ============================================================================
-- RPC 5: log_action_r2202 — append a free-form action note
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_action_r2202(
  p_op text,
  p_payload jsonb
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_action_r2202',
          jsonb_build_object('op', p_op, 'payload', COALESCE(p_payload, '{}'::jsonb)));
END;
$$;

-- ============================================================================
-- RPC 6: mark_status_r2202 — update interest status
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_status_r2202(p_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('open','matched','executed','withdrawn','expired') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.investor_secondary_interests_r2202
     SET status = p_status, updated_at = now()
   WHERE id = p_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r2202',
          jsonb_build_object('id', p_id, 'status', p_status));
END;
$$;

-- ============================================================================
-- RPC 7: list_matches_r2202 — recent match log joined with interest details
-- ============================================================================
CREATE OR REPLACE FUNCTION public.list_matches_r2202()
RETURNS TABLE (
  id uuid,
  buy_investor text,
  sell_investor text,
  matched_shares_qty int,
  matched_price_rupees numeric,
  match_status text,
  match_notes text,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id,
           ib.investor_name AS buy_investor,
           is2.investor_name AS sell_investor,
           m.matched_shares_qty,
           m.matched_price_rupees,
           m.match_status,
           m.match_notes,
           m.created_at
      FROM public.investor_secondary_matches_r2202 m
      LEFT JOIN public.investor_secondary_interests_r2202 ib ON ib.id = m.buy_interest_id
      LEFT JOIN public.investor_secondary_interests_r2202 is2 ON is2.id = m.sell_interest_id
     ORDER BY m.created_at DESC
     LIMIT 100;
END;
$$;

-- GRANTS
REVOKE ALL ON FUNCTION public.list_interests_r2202() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.recent_actions_r2202() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.top_side_r2202() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_interest_r2202(text,text,text,text,text,int,numeric,numeric,numeric,text,text,timestamptz) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.log_action_r2202(text,jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.mark_status_r2202(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.list_matches_r2202() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_interests_r2202() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_actions_r2202() TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_side_r2202() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_interest_r2202(text,text,text,text,text,int,numeric,numeric,numeric,text,text,timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_action_r2202(text,jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r2202(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_matches_r2202() TO authenticated;

COMMIT;
