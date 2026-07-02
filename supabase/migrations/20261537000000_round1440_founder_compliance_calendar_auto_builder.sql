BEGIN;
-- r1440 ★★★★ — Founder compliance calendar auto-builder.
--
-- Auto-generates the company's regulatory filing calendar from existing
-- founder_gst_filings (r1316), founder_compliance_documents (r1358), and
-- founder_tax_filing_runs (r1403) plus statutory cadences (monthly TDS,
-- quarterly GST, annual IT return, annual NABH/CDSCO/MSME/Udyam renewals,
-- board meetings, statutory audit, privacy notice review, DPDP quarterly
-- report). Founder sees one consolidated timeline: what's overdue, what's
-- due in 30d, what's coming up. Cron auto-seeds 12 months of recurring
-- events so the calendar stays self-populated.
--
-- 1 table:
--   founder_compliance_calendar_events
--
-- 7 RPCs:
--   founder_compliance_calendar_summary               — 16 KPIs
--   founder_compliance_calendar_events_recent         — 100-row ledger
--   founder_compliance_calendar_overdue               — overdue banner data
--   founder_compliance_calendar_due_30d               — due-30d banner data
--   founder_compliance_calendar_auto_seed_year        — cron seeder
--   log_founder_compliance_calendar_register_event    — manual register
--   log_founder_compliance_calendar_complete_event    — mark done

-- ============================================================================
-- 1. TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_compliance_calendar_events (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_label              text NOT NULL,
  event_kind               text NOT NULL CHECK (event_kind IN (
    'gst_filing','tds_filing','it_return','udyam_renewal','msme_renewal',
    'cdsco_renewal','nabh_renewal','board_meeting','statutory_audit',
    'privacy_notice_review','dpdp_quarterly_report','other'
  )),
  due_date                 date NOT NULL,
  frequency                text NOT NULL DEFAULT 'one_time' CHECK (frequency IN (
    'monthly','quarterly','annual','one_time'
  )),
  recurrence_anchor_date   date,
  source_table             text,
  source_record_id         uuid,
  status                   text NOT NULL DEFAULT 'upcoming' CHECK (status IN (
    'upcoming','due_soon','overdue','completed','waived','rescheduled'
  )),
  completed_at             timestamptz,
  owner_user_id            uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  notes                    text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_founder_compliance_calendar_due_date
  ON public.founder_compliance_calendar_events (due_date)
  WHERE status NOT IN ('completed','waived');
CREATE INDEX IF NOT EXISTS idx_founder_compliance_calendar_kind_due
  ON public.founder_compliance_calendar_events (event_kind, due_date DESC);
CREATE INDEX IF NOT EXISTS idx_founder_compliance_calendar_status
  ON public.founder_compliance_calendar_events (status, due_date);
CREATE UNIQUE INDEX IF NOT EXISTS idx_founder_compliance_calendar_dedup
  ON public.founder_compliance_calendar_events (event_kind, due_date, event_label);

ALTER TABLE public.founder_compliance_calendar_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_only_compliance_calendar_events
  ON public.founder_compliance_calendar_events;
CREATE POLICY founder_only_compliance_calendar_events
  ON public.founder_compliance_calendar_events
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- 2. SUMMARY — 16 KPIs
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_compliance_calendar_summary();
CREATE OR REPLACE FUNCTION public.founder_compliance_calendar_summary()
RETURNS TABLE (
  total_events             int,
  upcoming_count           int,
  due_soon_count           int,
  overdue_count            int,
  completed_count          int,
  waived_count             int,
  rescheduled_count        int,
  gst_filing_count         int,
  tds_filing_count         int,
  it_return_count          int,
  renewal_count            int,
  board_audit_count        int,
  privacy_dpdp_count       int,
  due_next_7d_count        int,
  due_next_30d_count       int,
  next_due_date            date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE status = 'upcoming')::int,
    COUNT(*) FILTER (WHERE status = 'due_soon')::int,
    COUNT(*) FILTER (WHERE status = 'overdue' OR (due_date < CURRENT_DATE AND status NOT IN ('completed','waived')))::int,
    COUNT(*) FILTER (WHERE status = 'completed')::int,
    COUNT(*) FILTER (WHERE status = 'waived')::int,
    COUNT(*) FILTER (WHERE status = 'rescheduled')::int,
    COUNT(*) FILTER (WHERE event_kind = 'gst_filing')::int,
    COUNT(*) FILTER (WHERE event_kind = 'tds_filing')::int,
    COUNT(*) FILTER (WHERE event_kind = 'it_return')::int,
    COUNT(*) FILTER (WHERE event_kind IN ('udyam_renewal','msme_renewal','cdsco_renewal','nabh_renewal'))::int,
    COUNT(*) FILTER (WHERE event_kind IN ('board_meeting','statutory_audit'))::int,
    COUNT(*) FILTER (WHERE event_kind IN ('privacy_notice_review','dpdp_quarterly_report'))::int,
    COUNT(*) FILTER (WHERE due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
                       AND status NOT IN ('completed','waived'))::int,
    COUNT(*) FILTER (WHERE due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
                       AND status NOT IN ('completed','waived'))::int,
    (SELECT MIN(due_date) FROM public.founder_compliance_calendar_events
       WHERE status NOT IN ('completed','waived') AND due_date >= CURRENT_DATE)
  FROM public.founder_compliance_calendar_events;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_compliance_calendar_summary() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_compliance_calendar_summary() TO authenticated;

-- ============================================================================
-- 3. RECENT — 100-row ledger
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_compliance_calendar_events_recent();
CREATE OR REPLACE FUNCTION public.founder_compliance_calendar_events_recent()
RETURNS TABLE (
  id                       uuid,
  event_label              text,
  event_kind               text,
  due_date                 date,
  frequency                text,
  status                   text,
  source_table             text,
  source_record_id         uuid,
  days_until_due           int,
  is_overdue               boolean,
  completed_at             timestamptz,
  notes                    text,
  created_at               timestamptz,
  updated_at               timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.event_label,
    e.event_kind,
    e.due_date,
    e.frequency,
    e.status,
    e.source_table,
    e.source_record_id,
    (e.due_date - CURRENT_DATE)::int,
    (e.due_date < CURRENT_DATE AND e.status NOT IN ('completed','waived')),
    e.completed_at,
    e.notes,
    e.created_at,
    e.updated_at
  FROM public.founder_compliance_calendar_events e
  ORDER BY
    CASE WHEN e.status IN ('completed','waived') THEN 1 ELSE 0 END,
    e.due_date ASC
  LIMIT 100;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_compliance_calendar_events_recent() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_compliance_calendar_events_recent() TO authenticated;

-- ============================================================================
-- 4. OVERDUE
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_compliance_calendar_overdue();
CREATE OR REPLACE FUNCTION public.founder_compliance_calendar_overdue()
RETURNS TABLE (
  id            uuid,
  event_label   text,
  event_kind    text,
  due_date      date,
  days_overdue  int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.event_label,
    e.event_kind,
    e.due_date,
    (CURRENT_DATE - e.due_date)::int
  FROM public.founder_compliance_calendar_events e
  WHERE e.due_date < CURRENT_DATE
    AND e.status NOT IN ('completed','waived')
  ORDER BY e.due_date ASC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_compliance_calendar_overdue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_compliance_calendar_overdue() TO authenticated;

-- ============================================================================
-- 5. DUE 30d
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_compliance_calendar_due_30d();
CREATE OR REPLACE FUNCTION public.founder_compliance_calendar_due_30d()
RETURNS TABLE (
  id            uuid,
  event_label   text,
  event_kind    text,
  due_date      date,
  days_until    int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  RETURN QUERY
  SELECT
    e.id,
    e.event_label,
    e.event_kind,
    e.due_date,
    (e.due_date - CURRENT_DATE)::int
  FROM public.founder_compliance_calendar_events e
  WHERE e.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
    AND e.status NOT IN ('completed','waived')
  ORDER BY e.due_date ASC
  LIMIT 50;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_compliance_calendar_due_30d() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_compliance_calendar_due_30d() TO authenticated;

-- ============================================================================
-- 6. AUTO-SEED — cron seeds 12 months of recurring events
-- ============================================================================
DROP FUNCTION IF EXISTS public.founder_compliance_calendar_auto_seed_year();
CREATE OR REPLACE FUNCTION public.founder_compliance_calendar_auto_seed_year()
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  inserted_count int := 0;
  m int;
  q int;
  qtr_end date;
  tds_due date;
  base_year int := EXTRACT(year FROM CURRENT_DATE)::int;
BEGIN
  -- Monthly TDS — 7th of next month
  FOR m IN 1..12 LOOP
    tds_due := make_date(base_year, m, 1) + INTERVAL '1 month' + INTERVAL '6 days';
    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date, source_table)
    VALUES
      ('TDS deposit — ' || to_char(make_date(base_year, m, 1), 'Mon YYYY'),
       'tds_filing', tds_due::date, 'monthly', make_date(base_year, m, 1), 'founder_tax_filing_runs')
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;
  END LOOP;

  -- Quarterly GST (GSTR-1/3B) — 20th of month after qtr end
  FOR q IN 1..4 LOOP
    qtr_end := make_date(base_year, q*3, 1) + INTERVAL '1 month' - INTERVAL '1 day';
    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date, source_table)
    VALUES
      ('GST quarterly filing Q' || q || ' ' || base_year,
       'gst_filing', (qtr_end + INTERVAL '20 days')::date, 'quarterly', qtr_end, 'founder_gst_filings')
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;

    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date)
    VALUES
      ('DPDP quarterly report Q' || q || ' ' || base_year,
       'dpdp_quarterly_report', (qtr_end + INTERVAL '30 days')::date, 'quarterly', qtr_end)
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;

    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, recurrence_anchor_date)
    VALUES
      ('Board meeting Q' || q || ' ' || base_year,
       'board_meeting', (qtr_end + INTERVAL '15 days')::date, 'quarterly', qtr_end)
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
    IF FOUND THEN inserted_count := inserted_count + 1; END IF;
  END LOOP;

  -- Annual filings
  INSERT INTO public.founder_compliance_calendar_events
    (event_label, event_kind, due_date, frequency, recurrence_anchor_date)
  VALUES
    ('Income-tax return AY ' || (base_year+1),
     'it_return', make_date(base_year, 10, 31), 'annual', make_date(base_year, 4, 1)),
    ('Statutory audit ' || base_year,
     'statutory_audit', make_date(base_year, 9, 30), 'annual', make_date(base_year, 4, 1)),
    ('Privacy notice annual review ' || base_year,
     'privacy_notice_review', make_date(base_year, 12, 31), 'annual', make_date(base_year, 1, 1))
  ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
  inserted_count := inserted_count + 3;

  -- Pull renewals from founder_compliance_documents (r1358) if any have renewal_due_date
  BEGIN
    INSERT INTO public.founder_compliance_calendar_events
      (event_label, event_kind, due_date, frequency, source_table, source_record_id)
    SELECT
      'Renewal: ' || COALESCE(d.document_label, d.document_kind),
      CASE d.document_kind
        WHEN 'udyam'  THEN 'udyam_renewal'
        WHEN 'msme'   THEN 'msme_renewal'
        WHEN 'cdsco'  THEN 'cdsco_renewal'
        WHEN 'nabh'   THEN 'nabh_renewal'
        ELSE 'other'
      END,
      d.renewal_due_date,
      'annual',
      'founder_compliance_documents',
      d.id
    FROM public.founder_compliance_documents d
    WHERE d.renewal_due_date IS NOT NULL
      AND d.renewal_due_date >= CURRENT_DATE
    ON CONFLICT (event_kind, due_date, event_label) DO NOTHING;
  EXCEPTION WHEN undefined_table OR undefined_column THEN
    NULL;
  END;

  -- Roll up statuses
  UPDATE public.founder_compliance_calendar_events
     SET status = 'overdue', updated_at = now()
   WHERE due_date < CURRENT_DATE
     AND status NOT IN ('completed','waived','overdue');

  UPDATE public.founder_compliance_calendar_events
     SET status = 'due_soon', updated_at = now()
   WHERE due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
     AND status NOT IN ('completed','waived','due_soon');

  RETURN inserted_count;
END;
$$;
REVOKE ALL ON FUNCTION public.founder_compliance_calendar_auto_seed_year() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.founder_compliance_calendar_auto_seed_year() TO authenticated;

-- ============================================================================
-- 7. REGISTER — manual event
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_compliance_calendar_register_event(text, text, date, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_compliance_calendar_register_event(
  p_event_label text,
  p_event_kind  text,
  p_due_date    date,
  p_frequency   text DEFAULT 'one_time',
  p_notes       text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.founder_compliance_calendar_events
    (event_label, event_kind, due_date, frequency, notes, owner_user_id)
  VALUES
    (p_event_label, p_event_kind, p_due_date, p_frequency, p_notes, auth.uid())
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_compliance_calendar_register_event(text, text, date, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_compliance_calendar_register_event(text, text, date, text, text) TO authenticated;

-- ============================================================================
-- 8. COMPLETE
-- ============================================================================
DROP FUNCTION IF EXISTS public.log_founder_compliance_calendar_complete_event(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_compliance_calendar_complete_event(
  p_event_id uuid,
  p_notes    text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_compliance_calendar_events
     SET status = 'completed',
         completed_at = now(),
         notes = COALESCE(p_notes, notes),
         updated_at = now()
   WHERE id = p_event_id;

  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.log_founder_compliance_calendar_complete_event(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.log_founder_compliance_calendar_complete_event(uuid, text) TO authenticated;

COMMIT;