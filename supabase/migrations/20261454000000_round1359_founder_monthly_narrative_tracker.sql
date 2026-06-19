BEGIN;
-- r1359 — Founder monthly narrative tracker.
--
-- Every month the founder owes investors, board, and themselves a single
-- coherent story: what shipped, what broke, what was learned, what's next,
-- and what specific asks the company has. Without a forcing function this
-- decays into ad-hoc updates that drift, contradict, or stop happening
-- altogether — and that's exactly when investors lose conviction.
--
-- This module is the institutional log of that monthly narrative:
--   * one row per calendar month (unique month_label, e.g. '2026-06')
--   * draft → reviewed → sent → published state machine
--   * structured slots: headline, wins, losses, asks, KPI snapshot
--   * cadence telemetry: days_since_last_sent, avg_send_delay_days
--
-- The single biggest investor-relations sin is silence followed by
-- explanation. This table makes that physically painful to commit.

-- ============================================================================
-- Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_monthly_narratives (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label                 text NOT NULL UNIQUE,
  status                      text NOT NULL DEFAULT 'draft'
                                CHECK (status IN ('draft','reviewed','sent','published')),
  headline                    text,
  win_summary                 text,
  loss_summary                text,
  ask_summary                 text,
  kpis_snapshot               jsonb NOT NULL DEFAULT '{}'::jsonb,
  mrr_eom_rupees              numeric,
  mrr_delta_mom_pct           numeric,
  active_amcs_eom             int,
  active_engineers_eom        int,
  total_gmv_month_rupees      numeric,
  total_payouts_month_rupees  numeric,
  code_red_count_month        int NOT NULL DEFAULT 0,
  dispute_count_month         int NOT NULL DEFAULT 0,
  drafted_at                  timestamptz,
  reviewed_at                 timestamptz,
  sent_at                     timestamptz,
  sent_to                     text[],
  notes                       text,
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_monthly_narratives IS
  'Monthly investor narrative log — one row per month. Draft→reviewed→sent→published. The forcing function against IR silence.';

CREATE INDEX IF NOT EXISTS idx_founder_monthly_narratives_status ON public.founder_monthly_narratives (status);
CREATE INDEX IF NOT EXISTS idx_founder_monthly_narratives_sent   ON public.founder_monthly_narratives (sent_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_founder_monthly_narratives_month  ON public.founder_monthly_narratives (month_label DESC);

ALTER TABLE public.founder_monthly_narratives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_monthly_narratives_no_direct ON public.founder_monthly_narratives;
CREATE POLICY founder_monthly_narratives_no_direct ON public.founder_monthly_narratives FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_monthly_narratives FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Write-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_monthly_narrative_create(text, text, text, text, text, jsonb);
CREATE OR REPLACE FUNCTION public.log_founder_monthly_narrative_create(
  p_month_label    text,
  p_headline       text,
  p_win_summary    text,
  p_loss_summary   text,
  p_ask_summary    text,
  p_kpis_snapshot  jsonb DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_month_label IS NULL OR length(trim(p_month_label)) = 0 THEN
    RAISE EXCEPTION 'month_label required' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.founder_monthly_narratives
    (month_label, status, headline, win_summary, loss_summary, ask_summary,
     kpis_snapshot, drafted_at)
  VALUES
    (p_month_label, 'draft', p_headline, p_win_summary, p_loss_summary, p_ask_summary,
     coalesce(p_kpis_snapshot, '{}'::jsonb), now())
  ON CONFLICT (month_label) DO UPDATE
    SET headline      = coalesce(EXCLUDED.headline,      public.founder_monthly_narratives.headline),
        win_summary   = coalesce(EXCLUDED.win_summary,   public.founder_monthly_narratives.win_summary),
        loss_summary  = coalesce(EXCLUDED.loss_summary,  public.founder_monthly_narratives.loss_summary),
        ask_summary   = coalesce(EXCLUDED.ask_summary,   public.founder_monthly_narratives.ask_summary),
        kpis_snapshot = CASE WHEN EXCLUDED.kpis_snapshot = '{}'::jsonb
                             THEN public.founder_monthly_narratives.kpis_snapshot
                             ELSE EXCLUDED.kpis_snapshot END,
        drafted_at    = coalesce(public.founder_monthly_narratives.drafted_at, now()),
        updated_at    = now()
    RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_monthly_narrative_create(text, text, text, text, text, jsonb) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_monthly_narrative_create(text, text, text, text, text, jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_monthly_narrative_status(uuid, text, text[]);
CREATE OR REPLACE FUNCTION public.log_founder_monthly_narrative_status(
  p_id         uuid,
  p_new_status text,
  p_sent_to    text[] DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_new_status NOT IN ('draft','reviewed','sent','published') THEN
    RAISE EXCEPTION 'invalid status %', p_new_status USING ERRCODE = '22023';
  END IF;
  UPDATE public.founder_monthly_narratives
    SET status      = p_new_status,
        reviewed_at = CASE WHEN p_new_status IN ('reviewed','sent','published') AND reviewed_at IS NULL THEN now() ELSE reviewed_at END,
        sent_at     = CASE WHEN p_new_status IN ('sent','published') AND sent_at IS NULL THEN now() ELSE sent_at END,
        sent_to     = CASE WHEN p_sent_to IS NULL THEN sent_to ELSE p_sent_to END,
        updated_at  = now()
    WHERE id = p_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_monthly_narrative_status(uuid, text, text[]) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_monthly_narrative_status(uuid, text, text[]) TO authenticated;

-- ============================================================================
-- Read-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_monthly_narrative_summary();
CREATE OR REPLACE FUNCTION public.founder_monthly_narrative_summary()
RETURNS TABLE (
  latest_month_label      text,
  latest_status           text,
  latest_headline         text,
  total_narratives        bigint,
  draft_count             bigint,
  reviewed_count          bigint,
  sent_count              bigint,
  published_count         bigint,
  latest_mrr_eom          numeric,
  latest_mrr_delta_mom_pct numeric,
  last_sent_at            timestamptz,
  days_since_last_sent    int,
  narratives_ytd          bigint,
  avg_send_delay_days     numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    (SELECT month_label FROM public.founder_monthly_narratives ORDER BY month_label DESC LIMIT 1),
    (SELECT status      FROM public.founder_monthly_narratives ORDER BY month_label DESC LIMIT 1),
    (SELECT headline    FROM public.founder_monthly_narratives ORDER BY month_label DESC LIMIT 1),
    coalesce((SELECT count(*)::bigint FROM public.founder_monthly_narratives), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_monthly_narratives WHERE status = 'draft'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_monthly_narratives WHERE status = 'reviewed'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_monthly_narratives WHERE status = 'sent'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_monthly_narratives WHERE status = 'published'), 0),
    (SELECT mrr_eom_rupees       FROM public.founder_monthly_narratives ORDER BY month_label DESC LIMIT 1),
    (SELECT mrr_delta_mom_pct    FROM public.founder_monthly_narratives ORDER BY month_label DESC LIMIT 1),
    (SELECT max(sent_at)         FROM public.founder_monthly_narratives WHERE sent_at IS NOT NULL),
    coalesce((SELECT extract(day from (now() - max(sent_at)))::int FROM public.founder_monthly_narratives WHERE sent_at IS NOT NULL), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_monthly_narratives WHERE month_label >= to_char(date_trunc('year', now()), 'YYYY-01')), 0),
    coalesce((SELECT round(avg(extract(day from (sent_at - drafted_at)))::numeric, 1)
              FROM public.founder_monthly_narratives
              WHERE sent_at IS NOT NULL AND drafted_at IS NOT NULL), 0)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_monthly_narrative_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_monthly_narrative_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_monthly_narratives_recent(int);
CREATE OR REPLACE FUNCTION public.founder_monthly_narratives_recent(p_limit int DEFAULT 12)
RETURNS TABLE (
  id                          uuid,
  month_label                 text,
  status                      text,
  headline                    text,
  win_summary                 text,
  loss_summary                text,
  ask_summary                 text,
  kpis_snapshot               jsonb,
  mrr_eom_rupees              numeric,
  mrr_delta_mom_pct           numeric,
  active_amcs_eom             int,
  active_engineers_eom        int,
  total_gmv_month_rupees      numeric,
  total_payouts_month_rupees  numeric,
  code_red_count_month        int,
  dispute_count_month         int,
  drafted_at                  timestamptz,
  reviewed_at                 timestamptz,
  sent_at                     timestamptz,
  sent_to                     text[],
  notes                       text,
  created_at                  timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT n.id, n.month_label, n.status, n.headline,
         n.win_summary, n.loss_summary, n.ask_summary, n.kpis_snapshot,
         n.mrr_eom_rupees, n.mrr_delta_mom_pct, n.active_amcs_eom, n.active_engineers_eom,
         n.total_gmv_month_rupees, n.total_payouts_month_rupees,
         n.code_red_count_month, n.dispute_count_month,
         n.drafted_at, n.reviewed_at, n.sent_at, n.sent_to, n.notes, n.created_at
    FROM public.founder_monthly_narratives n
    ORDER BY n.month_label DESC
    LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_monthly_narratives_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_monthly_narratives_recent(int) TO authenticated;

COMMIT;