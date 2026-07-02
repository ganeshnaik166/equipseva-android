BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_tender_bids_r2359 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_user_id uuid NOT NULL REFERENCES public.profiles(id),
  tender_ref text NOT NULL,
  tender_title text NOT NULL,
  tender_region text,
  category text NOT NULL CHECK (category IN ('amc','spare_parts','repair','capex','consumables','training')),
  closed_at timestamptz NOT NULL,
  won boolean NOT NULL DEFAULT true,
  our_bid_rupees bigint NOT NULL CHECK (our_bid_rupees >= 0),
  winning_competitor_bid_rupees bigint CHECK (winning_competitor_bid_rupees IS NULL OR winning_competitor_bid_rupees >= 0),
  competitor_name text,
  our_estimated_cost_rupees bigint NOT NULL CHECK (our_estimated_cost_rupees >= 0),
  margin_pct numeric(6,2),
  bid_source text CHECK (bid_source IS NULL OR bid_source IN ('public_disclosure','hospital_share','rumored','internal')),
  intel_confidence text DEFAULT 'medium' CHECK (intel_confidence IN ('low','medium','high')),
  recorded_by_email text,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_bid_margin_notes_r2359 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bid_id uuid NOT NULL REFERENCES public.hospital_chain_tender_bids_r2359(id) ON DELETE CASCADE,
  note text NOT NULL,
  by_email text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_tender_bids_r2359 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_bid_margin_notes_r2359 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2359_bids ON public.hospital_chain_tender_bids_r2359;
CREATE POLICY founder_all_r2359_bids ON public.hospital_chain_tender_bids_r2359
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2359_notes ON public.hospital_chain_bid_margin_notes_r2359;
CREATE POLICY founder_all_r2359_notes ON public.hospital_chain_bid_margin_notes_r2359
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list bids with margin + delta-vs-competitor calc
CREATE OR REPLACE FUNCTION public.list_chain_tender_bids_r2359()
RETURNS TABLE (
  id uuid,
  chain_user_id uuid,
  chain_email text,
  tender_ref text,
  tender_title text,
  tender_region text,
  category text,
  closed_at timestamptz,
  won boolean,
  our_bid_rupees bigint,
  winning_competitor_bid_rupees bigint,
  competitor_name text,
  our_estimated_cost_rupees bigint,
  margin_pct numeric,
  delta_to_competitor_rupees bigint,
  delta_to_competitor_pct numeric,
  bid_source text,
  intel_confidence text,
  recorded_by_email text,
  recorded_at timestamptz,
  note_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.id,
    b.chain_user_id,
    p.email,
    b.tender_ref,
    b.tender_title,
    b.tender_region,
    b.category,
    b.closed_at,
    b.won,
    b.our_bid_rupees,
    b.winning_competitor_bid_rupees,
    b.competitor_name,
    b.our_estimated_cost_rupees,
    b.margin_pct,
    CASE WHEN b.winning_competitor_bid_rupees IS NOT NULL
         THEN (b.winning_competitor_bid_rupees - b.our_bid_rupees)::bigint
         ELSE NULL END,
    CASE WHEN b.winning_competitor_bid_rupees IS NOT NULL AND b.winning_competitor_bid_rupees > 0
         THEN ROUND(((b.winning_competitor_bid_rupees - b.our_bid_rupees)::numeric * 100.0
                     / b.winning_competitor_bid_rupees::numeric), 2)
         ELSE NULL END,
    b.bid_source,
    b.intel_confidence,
    b.recorded_by_email,
    b.recorded_at,
    (SELECT (COUNT(*))::int FROM public.hospital_chain_bid_margin_notes_r2359 n WHERE n.bid_id = b.id)
  FROM public.hospital_chain_tender_bids_r2359 b
  LEFT JOIN public.profiles p ON p.id = b.chain_user_id
  ORDER BY b.closed_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: record bid
CREATE OR REPLACE FUNCTION public.record_chain_tender_bid_r2359(
  p_chain_user_id uuid,
  p_tender_ref text,
  p_tender_title text,
  p_tender_region text,
  p_category text,
  p_closed_at timestamptz,
  p_won boolean,
  p_our_bid_rupees bigint,
  p_winning_competitor_bid_rupees bigint,
  p_competitor_name text,
  p_our_estimated_cost_rupees bigint,
  p_bid_source text,
  p_intel_confidence text,
  p_recorded_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_margin numeric(6,2);
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_our_bid_rupees > 0 THEN
    v_margin := ROUND(((p_our_bid_rupees - p_our_estimated_cost_rupees)::numeric * 100.0 / p_our_bid_rupees::numeric), 2);
  ELSE
    v_margin := NULL;
  END IF;

  INSERT INTO public.hospital_chain_tender_bids_r2359(
    chain_user_id, tender_ref, tender_title, tender_region, category, closed_at, won,
    our_bid_rupees, winning_competitor_bid_rupees, competitor_name, our_estimated_cost_rupees,
    margin_pct, bid_source, intel_confidence, recorded_by_email
  ) VALUES (
    p_chain_user_id, p_tender_ref, p_tender_title, p_tender_region, p_category, p_closed_at, COALESCE(p_won, true),
    p_our_bid_rupees, p_winning_competitor_bid_rupees, p_competitor_name, p_our_estimated_cost_rupees,
    v_margin, p_bid_source, COALESCE(p_intel_confidence,'medium'), p_recorded_by_email
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2359_record_chain_tender_bid',
    jsonb_build_object('id', v_id, 'tender_ref', p_tender_ref, 'our_bid', p_our_bid_rupees, 'margin_pct', v_margin));
  RETURN v_id;
END;
$$;

-- RPC 3: list notes
CREATE OR REPLACE FUNCTION public.list_chain_tender_bid_notes_r2359(p_bid_id uuid)
RETURNS TABLE (
  id uuid,
  bid_id uuid,
  note text,
  by_email text,
  at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.bid_id, n.note, n.by_email, n.at
  FROM public.hospital_chain_bid_margin_notes_r2359 n
  WHERE n.bid_id = p_bid_id
  ORDER BY n.at DESC
  LIMIT 200;
END;
$$;

-- RPC 4: add margin note
CREATE OR REPLACE FUNCTION public.add_chain_tender_bid_note_r2359(
  p_bid_id uuid,
  p_note text,
  p_by_email text
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
  INSERT INTO public.hospital_chain_bid_margin_notes_r2359(bid_id, note, by_email)
  VALUES (p_bid_id, p_note, p_by_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2359_add_chain_tender_bid_note',
    jsonb_build_object('id', v_id, 'bid_id', p_bid_id));
  RETURN v_id;
END;
$$;

-- RPC 5: thinnest-margin won bids (risk surface)
CREATE OR REPLACE FUNCTION public.thinnest_margin_chain_bids_r2359()
RETURNS TABLE (
  id uuid,
  chain_user_id uuid,
  chain_email text,
  tender_ref text,
  tender_title text,
  category text,
  our_bid_rupees bigint,
  our_estimated_cost_rupees bigint,
  margin_pct numeric,
  closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.id,
    b.chain_user_id,
    p.email,
    b.tender_ref,
    b.tender_title,
    b.category,
    b.our_bid_rupees,
    b.our_estimated_cost_rupees,
    b.margin_pct,
    b.closed_at
  FROM public.hospital_chain_tender_bids_r2359 b
  LEFT JOIN public.profiles p ON p.id = b.chain_user_id
  WHERE b.won = true
    AND b.margin_pct IS NOT NULL
  ORDER BY b.margin_pct ASC
  LIMIT 25;
END;
$$;

-- RPC 6: closest competitor deltas (where we won by a sliver)
CREATE OR REPLACE FUNCTION public.closest_competitor_deltas_r2359()
RETURNS TABLE (
  id uuid,
  tender_ref text,
  tender_title text,
  competitor_name text,
  our_bid_rupees bigint,
  winning_competitor_bid_rupees bigint,
  delta_rupees bigint,
  delta_pct numeric,
  intel_confidence text,
  closed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.id,
    b.tender_ref,
    b.tender_title,
    b.competitor_name,
    b.our_bid_rupees,
    b.winning_competitor_bid_rupees,
    (b.winning_competitor_bid_rupees - b.our_bid_rupees)::bigint,
    CASE WHEN b.winning_competitor_bid_rupees > 0
         THEN ROUND(((b.winning_competitor_bid_rupees - b.our_bid_rupees)::numeric * 100.0
                     / b.winning_competitor_bid_rupees::numeric), 2)
         ELSE NULL END,
    b.intel_confidence,
    b.closed_at
  FROM public.hospital_chain_tender_bids_r2359 b
  WHERE b.won = true
    AND b.winning_competitor_bid_rupees IS NOT NULL
    AND b.winning_competitor_bid_rupees > 0
  ORDER BY ((b.winning_competitor_bid_rupees - b.our_bid_rupees)::numeric / b.winning_competitor_bid_rupees::numeric) ASC
  LIMIT 25;
END;
$$;

-- RPC 7: category margin rollup
CREATE OR REPLACE FUNCTION public.category_margin_rollup_r2359()
RETURNS TABLE (
  category text,
  bid_count bigint,
  total_value_rupees numeric,
  avg_margin_pct numeric,
  min_margin_pct numeric,
  max_margin_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    b.category,
    COUNT(*)::bigint,
    SUM(b.our_bid_rupees)::numeric,
    ROUND(AVG(b.margin_pct), 2),
    ROUND(MIN(b.margin_pct), 2),
    ROUND(MAX(b.margin_pct), 2)
  FROM public.hospital_chain_tender_bids_r2359 b
  WHERE b.won = true
  GROUP BY b.category
  ORDER BY SUM(b.our_bid_rupees) DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_tender_bids_r2359() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.record_chain_tender_bid_r2359(uuid, text, text, text, text, timestamptz, boolean, bigint, bigint, text, bigint, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_tender_bid_notes_r2359(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_chain_tender_bid_note_r2359(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.thinnest_margin_chain_bids_r2359() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.closest_competitor_deltas_r2359() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.category_margin_rollup_r2359() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_tender_bids_r2359() TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_chain_tender_bid_r2359(uuid, text, text, text, text, timestamptz, boolean, bigint, bigint, text, bigint, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_tender_bid_notes_r2359(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_chain_tender_bid_note_r2359(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.thinnest_margin_chain_bids_r2359() TO authenticated;
GRANT EXECUTE ON FUNCTION public.closest_competitor_deltas_r2359() TO authenticated;
GRANT EXECUTE ON FUNCTION public.category_margin_rollup_r2359() TO authenticated;

COMMIT;
