BEGIN;

-- ============================================================
-- Round r2801 — Founder Quarterly Strategic Board Deck Archive
-- Deck x meeting x key slide x decision x follow-up x archive verdict
-- ============================================================

-- ---------- TABLE 1: board_deck_archive_r2801 ----------
CREATE TABLE IF NOT EXISTS public.board_deck_archive_r2801 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_code       text NOT NULL UNIQUE,
  quarter_label   text NOT NULL,
  meeting_date    date NOT NULL,
  meeting_kind    text NOT NULL CHECK (meeting_kind IN ('quarterly','annual','special','offsite')),
  slide_count     integer NOT NULL CHECK (slide_count >= 0),
  key_slide_title text NOT NULL,
  key_metric      text NOT NULL,
  decision_summary text NOT NULL,
  follow_up_owner text NOT NULL,
  follow_up_due   date NOT NULL,
  archive_verdict text NOT NULL CHECK (archive_verdict IN ('canonical','reference','superseded','draft','restricted')),
  confidence_score numeric(5,2) NOT NULL CHECK (confidence_score >= 0 AND confidence_score <= 100),
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.board_deck_archive_r2801 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.board_deck_archive_r2801;
CREATE POLICY founder_all ON public.board_deck_archive_r2801
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.board_deck_archive_r2801
  (deck_code, quarter_label, meeting_date, meeting_kind, slide_count, key_slide_title, key_metric, decision_summary, follow_up_owner, follow_up_due, archive_verdict, confidence_score)
VALUES
  ('DECK-Q1-26','Q1-FY26','2026-04-12'::date,'quarterly',42,'India Ops Burn vs Plan','Burn -18% vs plan','Approved Series A extension memo','CFO','2026-05-10'::date,'canonical',96.50),
  ('DECK-Q2-26','Q2-FY26','2026-07-15'::date,'quarterly',38,'AMC ARR Trajectory','AMC ARR Rs 4.8 Cr run-rate','Greenlit Tier-1 city expansion','Founder','2026-08-20'::date,'canonical',94.20),
  ('DECK-OFF-26','H1-FY26 Offsite','2026-05-22'::date,'offsite',56,'5-Year Vertical Map','3 verticals chosen: dental/imaging/cath-lab','Killed pathology vertical','PSM','2026-06-05'::date,'reference',88.75),
  ('DECK-SPL-26A','Series A Extension','2026-06-01'::date,'special',24,'Cashfree Activation Status','KYC pending 14d','Bridge round ratified','Founder','2026-06-30'::date,'restricted',91.00),
  ('DECK-Q3-26-D','Q3-FY26 (draft)','2026-10-12'::date,'quarterly',31,'Engineer Density Map','Engineer fill 78%','Draft pending CFO review','CFO','2026-10-25'::date,'draft',62.40),
  ('DECK-Q4-25-SUP','Q4-FY25','2026-01-18'::date,'quarterly',45,'Counterfeit Parts Risk','3 incidents resolved','Superseded by bonded-parts memo','Ops Head','2026-02-15'::date,'superseded',71.10);

-- ---------- TABLE 2: board_deck_followup_log_r2801 ----------
CREATE TABLE IF NOT EXISTS public.board_deck_followup_log_r2801 (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deck_code     text NOT NULL REFERENCES public.board_deck_archive_r2801(deck_code) ON DELETE CASCADE,
  action_item   text NOT NULL,
  status        text NOT NULL CHECK (status IN ('open','in_progress','done','blocked','dropped')),
  owner_role    text NOT NULL,
  raised_on     date NOT NULL,
  closed_on     date,
  impact_rupees bigint NOT NULL DEFAULT 0 CHECK (impact_rupees >= 0),
  notes         text NOT NULL DEFAULT '',
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.board_deck_followup_log_r2801 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.board_deck_followup_log_r2801;
CREATE POLICY founder_all ON public.board_deck_followup_log_r2801
  FOR ALL TO authenticated USING (is_founder()) WITH CHECK (is_founder());

INSERT INTO public.board_deck_followup_log_r2801
  (deck_code, action_item, status, owner_role, raised_on, closed_on, impact_rupees, notes)
VALUES
  ('DECK-Q1-26','Lock Series A extension term sheet','done','Founder','2026-04-12'::date,'2026-05-08'::date,250000000,'15 Cr commit signed'),
  ('DECK-Q1-26','Reduce monthly burn by 18%','in_progress','CFO','2026-04-12'::date,NULL,4800000,'Headcount freeze + tooling cuts'),
  ('DECK-Q2-26','Expand to 6 Tier-1 cities','in_progress','Founder','2026-07-15'::date,NULL,32000000,'Pune + Ahmedabad live, 4 pending'),
  ('DECK-OFF-26','Kill pathology vertical cleanly','done','PSM','2026-05-22'::date,'2026-06-04'::date,0,'3 pilot orgs migrated to imaging'),
  ('DECK-SPL-26A','Close Cashfree KYC activation','blocked','Founder','2026-06-01'::date,NULL,0,'Awaiting Cashfree compliance team'),
  ('DECK-Q4-25-SUP','Counterfeit parts audit closeout','dropped','Ops Head','2026-01-18'::date,'2026-02-20'::date,1500000,'Superseded by bonded-parts SOP'),
  ('DECK-Q3-26-D','Engineer density rebalance plan','open','Ops Head','2026-10-12'::date,NULL,8200000,'Draft model in progress');

-- ============================================================
-- RPCs (7+, all SECDEF, is_founder gated)
-- ============================================================

-- RPC 1: list_decks
DROP FUNCTION IF EXISTS public.r2801_list_decks();
CREATE FUNCTION public.r2801_list_decks()
RETURNS TABLE (
  deck_code text, quarter_label text, meeting_date date, meeting_kind text,
  slide_count integer, key_slide_title text, key_metric text,
  decision_summary text, follow_up_owner text, follow_up_due date,
  archive_verdict text, confidence_score numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.deck_code, d.quarter_label, d.meeting_date, d.meeting_kind,
           d.slide_count, d.key_slide_title, d.key_metric,
           d.decision_summary, d.follow_up_owner, d.follow_up_due,
           d.archive_verdict, d.confidence_score
    FROM public.board_deck_archive_r2801 d
    ORDER BY d.meeting_date DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_list_decks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_list_decks() TO authenticated;

-- RPC 2: list_followups
DROP FUNCTION IF EXISTS public.r2801_list_followups();
CREATE FUNCTION public.r2801_list_followups()
RETURNS TABLE (
  deck_code text, action_item text, status text, owner_role text,
  raised_on date, closed_on date, impact_rupees bigint, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.deck_code, f.action_item, f.status, f.owner_role,
           f.raised_on, f.closed_on, f.impact_rupees, f.notes
    FROM public.board_deck_followup_log_r2801 f
    ORDER BY f.raised_on DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_list_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_list_followups() TO authenticated;

-- RPC 3: verdict_breakdown
DROP FUNCTION IF EXISTS public.r2801_verdict_breakdown();
CREATE FUNCTION public.r2801_verdict_breakdown()
RETURNS TABLE (archive_verdict text, deck_count bigint, avg_confidence numeric)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.archive_verdict, COUNT(*)::bigint, ROUND(AVG(d.confidence_score),2)
    FROM public.board_deck_archive_r2801 d
    GROUP BY d.archive_verdict
    ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_verdict_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_verdict_breakdown() TO authenticated;

-- RPC 4: followup_status_summary
DROP FUNCTION IF EXISTS public.r2801_followup_status_summary();
CREATE FUNCTION public.r2801_followup_status_summary()
RETURNS TABLE (status text, item_count bigint, total_impact_rupees bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.status, COUNT(*)::bigint, COALESCE(SUM(f.impact_rupees),0)::bigint
    FROM public.board_deck_followup_log_r2801 f
    GROUP BY f.status
    ORDER BY 3 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_followup_status_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_followup_status_summary() TO authenticated;

-- RPC 5: kpi_summary
DROP FUNCTION IF EXISTS public.r2801_kpi_summary();
CREATE FUNCTION public.r2801_kpi_summary()
RETURNS TABLE (
  total_decks bigint,
  canonical_decks bigint,
  draft_decks bigint,
  total_followups bigint,
  open_followups bigint,
  blocked_followups bigint,
  avg_confidence numeric,
  total_impact_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      (SELECT COUNT(*) FROM public.board_deck_archive_r2801)::bigint,
      (SELECT COUNT(*) FROM public.board_deck_archive_r2801 WHERE archive_verdict='canonical')::bigint,
      (SELECT COUNT(*) FROM public.board_deck_archive_r2801 WHERE archive_verdict='draft')::bigint,
      (SELECT COUNT(*) FROM public.board_deck_followup_log_r2801)::bigint,
      (SELECT COUNT(*) FROM public.board_deck_followup_log_r2801 WHERE status='open')::bigint,
      (SELECT COUNT(*) FROM public.board_deck_followup_log_r2801 WHERE status='blocked')::bigint,
      (SELECT ROUND(AVG(confidence_score),2) FROM public.board_deck_archive_r2801),
      (SELECT COALESCE(SUM(impact_rupees),0) FROM public.board_deck_followup_log_r2801)::bigint;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_kpi_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_kpi_summary() TO authenticated;

-- RPC 6: meeting_kind_distribution
DROP FUNCTION IF EXISTS public.r2801_meeting_kind_distribution();
CREATE FUNCTION public.r2801_meeting_kind_distribution()
RETURNS TABLE (meeting_kind text, deck_count bigint, total_slides bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT d.meeting_kind, COUNT(*)::bigint, COALESCE(SUM(d.slide_count),0)::bigint
    FROM public.board_deck_archive_r2801 d
    GROUP BY d.meeting_kind
    ORDER BY 2 DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_meeting_kind_distribution() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_meeting_kind_distribution() TO authenticated;

-- RPC 7: overdue_followups
DROP FUNCTION IF EXISTS public.r2801_overdue_followups();
CREATE FUNCTION public.r2801_overdue_followups()
RETURNS TABLE (
  deck_code text, action_item text, owner_role text,
  raised_on date, days_open integer, impact_rupees bigint, status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT f.deck_code, f.action_item, f.owner_role,
           f.raised_on,
           (CURRENT_DATE - f.raised_on)::integer,
           f.impact_rupees, f.status
    FROM public.board_deck_followup_log_r2801 f
    WHERE f.status IN ('open','in_progress','blocked')
    ORDER BY (CURRENT_DATE - f.raised_on) DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_overdue_followups() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_overdue_followups() TO authenticated;

-- RPC 8: deck_with_followup_counts
DROP FUNCTION IF EXISTS public.r2801_deck_with_followup_counts();
CREATE FUNCTION public.r2801_deck_with_followup_counts()
RETURNS TABLE (
  deck_code text, quarter_label text, archive_verdict text,
  total_followups bigint, open_count bigint, done_count bigint, total_impact bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT
      d.deck_code, d.quarter_label, d.archive_verdict,
      COUNT(f.id)::bigint,
      COUNT(*) FILTER (WHERE f.status IN ('open','in_progress','blocked'))::bigint,
      COUNT(*) FILTER (WHERE f.status='done')::bigint,
      COALESCE(SUM(f.impact_rupees),0)::bigint
    FROM public.board_deck_archive_r2801 d
    LEFT JOIN public.board_deck_followup_log_r2801 f ON f.deck_code=d.deck_code
    GROUP BY d.deck_code, d.quarter_label, d.archive_verdict
    ORDER BY d.deck_code;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.r2801_deck_with_followup_counts() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.r2801_deck_with_followup_counts() TO authenticated;

COMMIT;
