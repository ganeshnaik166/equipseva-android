BEGIN;

-- ============================================================
-- r1486 — Investor warm-intro graph
-- Logs who-introduced-whom in the investor network,
-- per-introducer conversion ladder, reciprocity score,
-- thank-you debt tracker.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_warm_intros (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  introducer_name text NOT NULL,
  introducer_org text,
  introducer_email text,
  target_investor_name text NOT NULL,
  target_investor_fund text,
  target_investor_email text,
  intro_channel text NOT NULL CHECK (intro_channel IN ('email','whatsapp','linkedin','in_person','call','event')),
  intro_warmth text NOT NULL CHECK (intro_warmth IN ('cold','warm','hot','double_opt_in')),
  intro_made_at timestamptz NOT NULL DEFAULT now(),
  first_reply_at timestamptz,
  first_meeting_at timestamptz,
  partner_meeting_at timestamptz,
  term_sheet_at timestamptz,
  closed_at timestamptz,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','no_reply','passed','meeting','partner_meeting','term_sheet','invested','ghosted')),
  cheque_amount_rupees bigint,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iwi_introducer ON public.investor_warm_intros(introducer_name);
CREATE INDEX IF NOT EXISTS idx_iwi_outcome ON public.investor_warm_intros(outcome);
CREATE INDEX IF NOT EXISTS idx_iwi_made_at ON public.investor_warm_intros(intro_made_at DESC);

ALTER TABLE public.investor_warm_intros ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS iwi_founder_all ON public.investor_warm_intros;
CREATE POLICY iwi_founder_all ON public.investor_warm_intros
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.investor_thank_you_debts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  intro_id uuid REFERENCES public.investor_warm_intros(id) ON DELETE CASCADE,
  introducer_name text NOT NULL,
  debt_type text NOT NULL CHECK (debt_type IN ('thank_you_note','gift','reciprocal_intro','update_email','dinner','equity_grant')),
  owed_since timestamptz NOT NULL DEFAULT now(),
  fulfilled_at timestamptz,
  fulfillment_note text,
  urgency text NOT NULL DEFAULT 'normal' CHECK (urgency IN ('low','normal','high','overdue')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_itd_introducer ON public.investor_thank_you_debts(introducer_name);
CREATE INDEX IF NOT EXISTS idx_itd_open ON public.investor_thank_you_debts(fulfilled_at) WHERE fulfilled_at IS NULL;

ALTER TABLE public.investor_thank_you_debts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS itd_founder_all ON public.investor_thank_you_debts;
CREATE POLICY itd_founder_all ON public.investor_thank_you_debts
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================
-- Read RPCs (STABLE)
-- ============================================================

CREATE OR REPLACE FUNCTION public.founder_iwi_overview()
RETURNS TABLE (
  total_intros bigint,
  open_intros bigint,
  invested_intros bigint,
  passed_intros bigint,
  unique_introducers bigint,
  total_cheque_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE outcome IN ('pending','meeting','partner_meeting','term_sheet'))::bigint,
    COUNT(*) FILTER (WHERE outcome = 'invested')::bigint,
    COUNT(*) FILTER (WHERE outcome IN ('passed','no_reply','ghosted'))::bigint,
    COUNT(DISTINCT introducer_name)::bigint,
    COALESCE(SUM(cheque_amount_rupees) FILTER (WHERE outcome = 'invested'), 0)::bigint
  FROM investor_warm_intros;
END $$;

CREATE OR REPLACE FUNCTION public.founder_iwi_introducer_ladder()
RETURNS TABLE (
  id text,
  introducer_name text,
  intros_made bigint,
  replied bigint,
  met bigint,
  partner_met bigint,
  term_sheets bigint,
  invested bigint,
  conv_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    md5(i.introducer_name) AS id,
    i.introducer_name,
    COUNT(*)::bigint AS intros_made,
    COUNT(*) FILTER (WHERE i.first_reply_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.first_meeting_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.partner_meeting_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.term_sheet_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.outcome = 'invested')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.outcome = 'invested') / NULLIF(COUNT(*), 0), 1) AS conv_rate
  FROM investor_warm_intros i
  GROUP BY i.introducer_name
  ORDER BY invested DESC, intros_made DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_iwi_recent_intros()
RETURNS TABLE (
  id uuid,
  introducer_name text,
  target_investor_name text,
  target_investor_fund text,
  intro_channel text,
  intro_warmth text,
  outcome text,
  intro_made_at timestamptz,
  days_since_intro integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    i.id, i.introducer_name, i.target_investor_name, i.target_investor_fund,
    i.intro_channel, i.intro_warmth, i.outcome, i.intro_made_at,
    EXTRACT(DAY FROM (now() - i.intro_made_at))::integer
  FROM investor_warm_intros i
  ORDER BY i.intro_made_at DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_iwi_reciprocity_score()
RETURNS TABLE (
  id text,
  introducer_name text,
  intros_received bigint,
  intros_given_back bigint,
  thank_yous_open bigint,
  thank_yous_done bigint,
  reciprocity_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH base AS (
    SELECT
      i.introducer_name,
      COUNT(*)::bigint AS intros_received,
      0::bigint AS intros_given_back
    FROM investor_warm_intros i
    GROUP BY i.introducer_name
  ),
  debts AS (
    SELECT
      d.introducer_name,
      COUNT(*) FILTER (WHERE d.fulfilled_at IS NULL)::bigint AS open_debt,
      COUNT(*) FILTER (WHERE d.fulfilled_at IS NOT NULL)::bigint AS done_debt
    FROM investor_thank_you_debts d
    GROUP BY d.introducer_name
  )
  SELECT
    md5(b.introducer_name) AS id,
    b.introducer_name,
    b.intros_received,
    b.intros_given_back,
    COALESCE(d.open_debt, 0),
    COALESCE(d.done_debt, 0),
    ROUND(100.0 * COALESCE(d.done_debt, 0) / NULLIF(b.intros_received, 0), 1) AS reciprocity_score
  FROM base b
  LEFT JOIN debts d ON d.introducer_name = b.introducer_name
  ORDER BY reciprocity_score ASC NULLS FIRST, b.intros_received DESC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_iwi_thank_you_debts()
RETURNS TABLE (
  id uuid,
  introducer_name text,
  debt_type text,
  urgency text,
  owed_since timestamptz,
  days_owed integer,
  fulfillment_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    d.id, d.introducer_name, d.debt_type, d.urgency, d.owed_since,
    EXTRACT(DAY FROM (now() - d.owed_since))::integer,
    d.fulfillment_note
  FROM investor_thank_you_debts d
  WHERE d.fulfilled_at IS NULL
  ORDER BY
    CASE d.urgency WHEN 'overdue' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END,
    d.owed_since ASC
  LIMIT 50;
END $$;

CREATE OR REPLACE FUNCTION public.founder_iwi_channel_mix()
RETURNS TABLE (
  id text,
  intro_channel text,
  intros bigint,
  reply_rate numeric,
  invest_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    md5(i.intro_channel) AS id,
    i.intro_channel,
    COUNT(*)::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.first_reply_at IS NOT NULL) / NULLIF(COUNT(*), 0), 1),
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.outcome = 'invested') / NULLIF(COUNT(*), 0), 1)
  FROM investor_warm_intros i
  GROUP BY i.intro_channel
  ORDER BY COUNT(*) DESC;
END $$;

CREATE OR REPLACE FUNCTION public.founder_iwi_warmth_funnel()
RETURNS TABLE (
  id text,
  intro_warmth text,
  intros bigint,
  met bigint,
  invested bigint,
  conv_rate numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    md5(i.intro_warmth) AS id,
    i.intro_warmth,
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE i.first_meeting_at IS NOT NULL)::bigint,
    COUNT(*) FILTER (WHERE i.outcome = 'invested')::bigint,
    ROUND(100.0 * COUNT(*) FILTER (WHERE i.outcome = 'invested') / NULLIF(COUNT(*), 0), 1)
  FROM investor_warm_intros i
  GROUP BY i.intro_warmth
  ORDER BY COUNT(*) DESC;
END $$;

-- ============================================================
-- Write helpers (VOLATILE)
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_founder_iwi_intro(
  p_introducer text,
  p_target text,
  p_fund text,
  p_channel text,
  p_warmth text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_warm_intros (introducer_name, target_investor_name, target_investor_fund, intro_channel, intro_warmth, notes)
  VALUES (p_introducer, p_target, p_fund, p_channel, p_warmth, p_notes)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_iwi_update_outcome(
  p_intro_id uuid,
  p_outcome text,
  p_cheque_rupees bigint
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_warm_intros
     SET outcome = p_outcome,
         cheque_amount_rupees = p_cheque_rupees,
         closed_at = CASE WHEN p_outcome IN ('invested','passed','ghosted') THEN now() ELSE closed_at END,
         updated_at = now()
   WHERE id = p_intro_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_iwi_open_debt(
  p_intro_id uuid,
  p_introducer text,
  p_debt_type text,
  p_urgency text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_thank_you_debts (intro_id, introducer_name, debt_type, urgency)
  VALUES (p_intro_id, p_introducer, p_debt_type, p_urgency)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.log_founder_iwi_fulfill_debt(
  p_debt_id uuid,
  p_note text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_thank_you_debts
     SET fulfilled_at = now(),
         fulfillment_note = p_note
   WHERE id = p_debt_id;
END $$;

-- ============================================================
-- Grants
-- ============================================================

REVOKE EXECUTE ON FUNCTION public.founder_iwi_overview() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_iwi_introducer_ladder() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_iwi_recent_intros() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_iwi_reciprocity_score() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_iwi_thank_you_debts() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_iwi_channel_mix() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.founder_iwi_warmth_funnel() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_iwi_intro(text,text,text,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_iwi_update_outcome(uuid,text,bigint) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_iwi_open_debt(uuid,text,text,text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_founder_iwi_fulfill_debt(uuid,text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.founder_iwi_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_iwi_introducer_ladder() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_iwi_recent_intros() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_iwi_reciprocity_score() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_iwi_thank_you_debts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_iwi_channel_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_iwi_warmth_funnel() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iwi_intro(text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iwi_update_outcome(uuid,text,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iwi_open_debt(uuid,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_iwi_fulfill_debt(uuid,text) TO authenticated;

COMMIT;