BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_tender_bids_r1715 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tender_name text NOT NULL,
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  submission_date date,
  bid_amount_rupees bigint NOT NULL DEFAULT 0,
  deadline_date date,
  status text NOT NULL DEFAULT 'drafting' CHECK (status IN ('drafting','submitted','shortlisted','awarded','lost','withdrawn')),
  win_probability_pct numeric(5,2) DEFAULT 0,
  lead_owner_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_tender_documents_r1715 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bid_id uuid NOT NULL REFERENCES public.hospital_tender_bids_r1715(id) ON DELETE CASCADE,
  doc_name text NOT NULL,
  doc_url text NOT NULL,
  doc_type text NOT NULL CHECK (doc_type IN ('spec','financial','compliance','profile')),
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_tender_bids_r1715 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_tender_documents_r1715 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_tender_bids_r1715 ON public.hospital_tender_bids_r1715;
CREATE POLICY founder_all_tender_bids_r1715 ON public.hospital_tender_bids_r1715
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_tender_docs_r1715 ON public.hospital_tender_documents_r1715;
CREATE POLICY founder_all_tender_docs_r1715 ON public.hospital_tender_documents_r1715
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- 1. list_bids
CREATE OR REPLACE FUNCTION public.list_tender_bids_r1715()
RETURNS TABLE(
  id uuid,
  tender_name text,
  hospital_org_id uuid,
  hospital_name text,
  submission_date date,
  bid_amount_rupees bigint,
  deadline_date date,
  status text,
  win_probability_pct numeric,
  lead_owner_email text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.tender_name, b.hospital_org_id, o.name, b.submission_date,
         b.bid_amount_rupees, b.deadline_date, b.status, b.win_probability_pct,
         b.lead_owner_email, b.created_at
  FROM public.hospital_tender_bids_r1715 b
  LEFT JOIN public.organizations o ON o.id = b.hospital_org_id
  ORDER BY b.created_at DESC
  LIMIT 200;
END;
$$;

-- 2. submit_bid
CREATE OR REPLACE FUNCTION public.submit_tender_bid_r1715(
  p_tender_name text,
  p_hospital_org_id uuid,
  p_bid_amount_rupees bigint,
  p_deadline_date date,
  p_win_probability_pct numeric,
  p_lead_owner_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_tender_bids_r1715(tender_name, hospital_org_id, submission_date, bid_amount_rupees, deadline_date, status, win_probability_pct, lead_owner_email)
  VALUES (p_tender_name, p_hospital_org_id, CURRENT_DATE, p_bid_amount_rupees, p_deadline_date, 'submitted', p_win_probability_pct, p_lead_owner_email)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'submit_tender_bid_r1715',
          jsonb_build_object('bid_id', v_id, 'tender_name', p_tender_name, 'amount', p_bid_amount_rupees));
  RETURN v_id;
END;
$$;

-- 3. list_documents
CREATE OR REPLACE FUNCTION public.list_tender_documents_r1715(p_bid_id uuid)
RETURNS TABLE(
  id uuid,
  bid_id uuid,
  doc_name text,
  doc_url text,
  doc_type text,
  uploaded_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.bid_id, d.doc_name, d.doc_url, d.doc_type, d.uploaded_at
  FROM public.hospital_tender_documents_r1715 d
  WHERE p_bid_id IS NULL OR d.bid_id = p_bid_id
  ORDER BY d.uploaded_at DESC
  LIMIT 500;
END;
$$;

-- 4. attach_document
CREATE OR REPLACE FUNCTION public.attach_tender_document_r1715(
  p_bid_id uuid,
  p_doc_name text,
  p_doc_url text,
  p_doc_type text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_tender_documents_r1715(bid_id, doc_name, doc_url, doc_type)
  VALUES (p_bid_id, p_doc_name, p_doc_url, p_doc_type)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'attach_tender_document_r1715',
          jsonb_build_object('doc_id', v_id, 'bid_id', p_bid_id, 'doc_type', p_doc_type));
  RETURN v_id;
END;
$$;

-- 5. update_status
CREATE OR REPLACE FUNCTION public.update_tender_bid_status_r1715(
  p_bid_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('drafting','submitted','shortlisted','awarded','lost','withdrawn') THEN
    RAISE EXCEPTION 'invalid status %', p_status;
  END IF;
  UPDATE public.hospital_tender_bids_r1715
  SET status = p_status, updated_at = now()
  WHERE id = p_bid_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_tender_bid_status_r1715',
          jsonb_build_object('bid_id', p_bid_id, 'status', p_status));
END;
$$;

-- 6. win_rate_summary
CREATE OR REPLACE FUNCTION public.tender_win_rate_summary_r1715()
RETURNS TABLE(
  total_bids int,
  submitted_bids int,
  awarded_bids int,
  lost_bids int,
  win_rate_pct numeric,
  total_award_value_rupees bigint,
  avg_bid_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE status = 'submitted'))::int,
    (COUNT(*) FILTER (WHERE status = 'awarded'))::int,
    (COUNT(*) FILTER (WHERE status = 'lost'))::int,
    CASE WHEN (COUNT(*) FILTER (WHERE status IN ('awarded','lost'))) > 0
         THEN ROUND(100.0 * (COUNT(*) FILTER (WHERE status = 'awarded'))::numeric / NULLIF((COUNT(*) FILTER (WHERE status IN ('awarded','lost'))), 0), 2)
         ELSE 0 END,
    COALESCE(SUM(bid_amount_rupees) FILTER (WHERE status = 'awarded'), 0)::bigint,
    COALESCE(AVG(bid_amount_rupees), 0)::bigint
  FROM public.hospital_tender_bids_r1715;
END;
$$;

-- 7. upcoming_deadlines
CREATE OR REPLACE FUNCTION public.tender_upcoming_deadlines_r1715()
RETURNS TABLE(
  id uuid,
  tender_name text,
  hospital_name text,
  deadline_date date,
  days_remaining int,
  bid_amount_rupees bigint,
  status text,
  lead_owner_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT b.id, b.tender_name, o.name, b.deadline_date,
         (b.deadline_date - CURRENT_DATE)::int,
         b.bid_amount_rupees, b.status, b.lead_owner_email
  FROM public.hospital_tender_bids_r1715 b
  LEFT JOIN public.organizations o ON o.id = b.hospital_org_id
  WHERE b.deadline_date IS NOT NULL
    AND b.deadline_date >= CURRENT_DATE
    AND b.status IN ('drafting','submitted','shortlisted')
  ORDER BY b.deadline_date ASC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_tender_bids_r1715() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.submit_tender_bid_r1715(text, uuid, bigint, date, numeric, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_tender_documents_r1715(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.attach_tender_document_r1715(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_tender_bid_status_r1715(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.tender_win_rate_summary_r1715() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.tender_upcoming_deadlines_r1715() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tender_bids_r1715() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_tender_bid_r1715(text, uuid, bigint, date, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_tender_documents_r1715(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.attach_tender_document_r1715(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_tender_bid_status_r1715(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tender_win_rate_summary_r1715() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tender_upcoming_deadlines_r1715() TO authenticated;

COMMIT;