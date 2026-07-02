BEGIN;

-- =========================================================================
-- r2297: Founder bank-relationship tracker
-- Two tables:
--   founder_bank_relationships_r2297  — one row per bank relationship
--   founder_bank_facilities_r2297     — facilities (LoC / term loan / OD) per relationship
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_bank_relationships_r2297 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name       text NOT NULL,
  branch_name     text,
  account_number_last4 text,
  relationship_status text NOT NULL DEFAULT 'active'
    CHECK (relationship_status IN ('active','watch','dormant','closed')),
  rm_name         text,
  rm_email        text,
  rm_phone        text,
  onboarded_on    date NOT NULL DEFAULT CURRENT_DATE,
  next_review_on  date,
  notes           text,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fbr_r2297_status ON public.founder_bank_relationships_r2297(relationship_status);
CREATE INDEX IF NOT EXISTS idx_fbr_r2297_review ON public.founder_bank_relationships_r2297(next_review_on);

CREATE TABLE IF NOT EXISTS public.founder_bank_facilities_r2297 (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id uuid NOT NULL REFERENCES public.founder_bank_relationships_r2297(id) ON DELETE CASCADE,
  facility_kind   text NOT NULL
    CHECK (facility_kind IN ('line_of_credit','term_loan','overdraft','working_capital','letter_of_credit')),
  facility_label  text NOT NULL,
  sanctioned_limit_rupees bigint NOT NULL DEFAULT 0 CHECK (sanctioned_limit_rupees >= 0),
  drawn_amount_rupees     bigint NOT NULL DEFAULT 0 CHECK (drawn_amount_rupees >= 0),
  interest_rate_bps int CHECK (interest_rate_bps IS NULL OR interest_rate_bps BETWEEN 0 AND 5000),
  sanctioned_on   date,
  matures_on      date,
  renewal_due_on  date,
  facility_status text NOT NULL DEFAULT 'live'
    CHECK (facility_status IN ('live','renewed','closed','defaulted')),
  collateral_note text,
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fbf_r2297_rel ON public.founder_bank_facilities_r2297(relationship_id);
CREATE INDEX IF NOT EXISTS idx_fbf_r2297_status ON public.founder_bank_facilities_r2297(facility_status);
CREATE INDEX IF NOT EXISTS idx_fbf_r2297_renewal ON public.founder_bank_facilities_r2297(renewal_due_on);
CREATE INDEX IF NOT EXISTS idx_fbf_r2297_matures ON public.founder_bank_facilities_r2297(matures_on);

-- =========================================================================
-- RLS — founder_all
-- =========================================================================
ALTER TABLE public.founder_bank_relationships_r2297 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_bank_facilities_r2297    ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_fbr_r2297 ON public.founder_bank_relationships_r2297;
CREATE POLICY founder_all_fbr_r2297 ON public.founder_bank_relationships_r2297
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_fbf_r2297 ON public.founder_bank_facilities_r2297;
CREATE POLICY founder_all_fbf_r2297 ON public.founder_bank_facilities_r2297
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs (7) — all is_founder gated
-- =========================================================================

-- 1. list_bank_relationships
CREATE OR REPLACE FUNCTION public.list_bank_relationships_r2297()
RETURNS TABLE (
  id uuid,
  bank_name text,
  branch_name text,
  account_number_last4 text,
  relationship_status text,
  rm_name text,
  rm_email text,
  rm_phone text,
  onboarded_on date,
  next_review_on date,
  facility_count int,
  total_sanctioned_rupees bigint,
  total_drawn_rupees bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id, r.bank_name, r.branch_name, r.account_number_last4,
    r.relationship_status, r.rm_name, r.rm_email, r.rm_phone,
    r.onboarded_on, r.next_review_on,
    (SELECT COUNT(*) FROM public.founder_bank_facilities_r2297 f WHERE f.relationship_id = r.id)::int,
    COALESCE((SELECT SUM(f.sanctioned_limit_rupees) FROM public.founder_bank_facilities_r2297 f WHERE f.relationship_id = r.id AND f.facility_status = 'live'), 0)::bigint,
    COALESCE((SELECT SUM(f.drawn_amount_rupees) FROM public.founder_bank_facilities_r2297 f WHERE f.relationship_id = r.id AND f.facility_status = 'live'), 0)::bigint
  FROM public.founder_bank_relationships_r2297 r
  ORDER BY r.onboarded_on DESC, r.bank_name ASC;
END
$$;
REVOKE ALL ON FUNCTION public.list_bank_relationships_r2297() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bank_relationships_r2297() TO authenticated;

-- 2. list_bank_facilities
CREATE OR REPLACE FUNCTION public.list_bank_facilities_r2297()
RETURNS TABLE (
  id uuid,
  relationship_id uuid,
  bank_name text,
  facility_kind text,
  facility_label text,
  sanctioned_limit_rupees bigint,
  drawn_amount_rupees bigint,
  utilisation_pct numeric,
  interest_rate_bps int,
  sanctioned_on date,
  matures_on date,
  renewal_due_on date,
  facility_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, f.relationship_id, r.bank_name,
    f.facility_kind, f.facility_label,
    f.sanctioned_limit_rupees, f.drawn_amount_rupees,
    CASE WHEN f.sanctioned_limit_rupees > 0
         THEN ROUND((f.drawn_amount_rupees::numeric / f.sanctioned_limit_rupees::numeric) * 100, 2)
         ELSE 0::numeric
    END,
    f.interest_rate_bps, f.sanctioned_on, f.matures_on, f.renewal_due_on, f.facility_status
  FROM public.founder_bank_facilities_r2297 f
  JOIN public.founder_bank_relationships_r2297 r ON r.id = f.relationship_id
  ORDER BY f.facility_status, f.renewal_due_on NULLS LAST, r.bank_name;
END
$$;
REVOKE ALL ON FUNCTION public.list_bank_facilities_r2297() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_bank_facilities_r2297() TO authenticated;

-- 3. renewals_due_soon
CREATE OR REPLACE FUNCTION public.renewals_due_soon_r2297(p_window_days int DEFAULT 60)
RETURNS TABLE (
  id uuid,
  bank_name text,
  facility_kind text,
  facility_label text,
  sanctioned_limit_rupees bigint,
  renewal_due_on date,
  days_until_renewal int,
  rm_name text,
  rm_email text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.id, r.bank_name, f.facility_kind, f.facility_label,
    f.sanctioned_limit_rupees, f.renewal_due_on,
    (f.renewal_due_on - CURRENT_DATE)::int,
    r.rm_name, r.rm_email
  FROM public.founder_bank_facilities_r2297 f
  JOIN public.founder_bank_relationships_r2297 r ON r.id = f.relationship_id
  WHERE f.facility_status = 'live'
    AND f.renewal_due_on IS NOT NULL
    AND f.renewal_due_on <= CURRENT_DATE + p_window_days
  ORDER BY f.renewal_due_on ASC;
END
$$;
REVOKE ALL ON FUNCTION public.renewals_due_soon_r2297(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renewals_due_soon_r2297(int) TO authenticated;

-- 4. summary_by_facility_kind
CREATE OR REPLACE FUNCTION public.summary_by_facility_kind_r2297()
RETURNS TABLE (
  facility_kind text,
  live_count int,
  total_sanctioned_rupees bigint,
  total_drawn_rupees bigint,
  avg_utilisation_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    f.facility_kind,
    (COUNT(*) FILTER (WHERE f.facility_status = 'live'))::int,
    COALESCE(SUM(f.sanctioned_limit_rupees) FILTER (WHERE f.facility_status = 'live'), 0)::bigint,
    COALESCE(SUM(f.drawn_amount_rupees) FILTER (WHERE f.facility_status = 'live'), 0)::bigint,
    COALESCE(ROUND(AVG(
      CASE WHEN f.sanctioned_limit_rupees > 0 AND f.facility_status = 'live'
           THEN (f.drawn_amount_rupees::numeric / f.sanctioned_limit_rupees::numeric) * 100
           ELSE NULL END
    ), 2), 0::numeric)
  FROM public.founder_bank_facilities_r2297 f
  GROUP BY f.facility_kind
  ORDER BY f.facility_kind;
END
$$;
REVOKE ALL ON FUNCTION public.summary_by_facility_kind_r2297() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.summary_by_facility_kind_r2297() TO authenticated;

-- 5. relationship_review_calendar — upcoming relationship reviews
CREATE OR REPLACE FUNCTION public.relationship_review_calendar_r2297()
RETURNS TABLE (
  id uuid,
  bank_name text,
  rm_name text,
  rm_email text,
  rm_phone text,
  next_review_on date,
  days_until_review int,
  relationship_status text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    r.id, r.bank_name, r.rm_name, r.rm_email, r.rm_phone,
    r.next_review_on,
    (r.next_review_on - CURRENT_DATE)::int,
    r.relationship_status
  FROM public.founder_bank_relationships_r2297 r
  WHERE r.next_review_on IS NOT NULL
    AND r.relationship_status IN ('active','watch')
  ORDER BY r.next_review_on ASC;
END
$$;
REVOKE ALL ON FUNCTION public.relationship_review_calendar_r2297() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.relationship_review_calendar_r2297() TO authenticated;

-- 6. add_bank_relationship
CREATE OR REPLACE FUNCTION public.add_bank_relationship_r2297(
  p_bank_name text,
  p_branch_name text,
  p_account_last4 text,
  p_rm_name text,
  p_rm_email text,
  p_rm_phone text,
  p_next_review_on date,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_caller uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_caller := (SELECT p.id FROM public.profiles p WHERE p.email = (auth.jwt()->>'email') LIMIT 1);
  INSERT INTO public.founder_bank_relationships_r2297
    (bank_name, branch_name, account_number_last4, rm_name, rm_email, rm_phone, next_review_on, notes, created_by)
  VALUES
    (p_bank_name, p_branch_name, p_account_last4, p_rm_name, p_rm_email, p_rm_phone, p_next_review_on, p_notes, v_caller)
  RETURNING id INTO v_id;
  RETURN v_id;
END
$$;
REVOKE ALL ON FUNCTION public.add_bank_relationship_r2297(text,text,text,text,text,text,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_bank_relationship_r2297(text,text,text,text,text,text,date,text) TO authenticated;

-- 7. add_bank_facility
CREATE OR REPLACE FUNCTION public.add_bank_facility_r2297(
  p_relationship_id uuid,
  p_facility_kind text,
  p_facility_label text,
  p_sanctioned_limit_rupees bigint,
  p_drawn_amount_rupees bigint,
  p_interest_rate_bps int,
  p_sanctioned_on date,
  p_matures_on date,
  p_renewal_due_on date,
  p_collateral_note text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_caller uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_caller := (SELECT p.id FROM public.profiles p WHERE p.email = (auth.jwt()->>'email') LIMIT 1);
  INSERT INTO public.founder_bank_facilities_r2297
    (relationship_id, facility_kind, facility_label, sanctioned_limit_rupees, drawn_amount_rupees,
     interest_rate_bps, sanctioned_on, matures_on, renewal_due_on, collateral_note, created_by)
  VALUES
    (p_relationship_id, p_facility_kind, p_facility_label, p_sanctioned_limit_rupees, p_drawn_amount_rupees,
     p_interest_rate_bps, p_sanctioned_on, p_matures_on, p_renewal_due_on, p_collateral_note, v_caller)
  RETURNING id INTO v_id;
  RETURN v_id;
END
$$;
REVOKE ALL ON FUNCTION public.add_bank_facility_r2297(uuid,text,text,bigint,bigint,int,date,date,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_bank_facility_r2297(uuid,text,text,bigint,bigint,int,date,date,date,text) TO authenticated;

COMMIT;
