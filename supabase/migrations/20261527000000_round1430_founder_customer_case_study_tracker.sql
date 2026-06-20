BEGIN;
-- r1430 founder_customer_case_study_tracker
-- Hospital reference + case study + permission tracker
-- 2 tables + 7 RPCs

CREATE TABLE IF NOT EXISTS public.founder_customer_case_studies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_study_label text NOT NULL UNIQUE,
  hospital_user_id uuid,
  case_study_kind text NOT NULL CHECK (case_study_kind IN ('uptime_win','cost_savings','quality_improvement','vertical_expansion','code_red_save','dispute_resolution','platform_referral')),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','permission_pending','permission_granted','published','retired','permission_denied')),
  permission_granted_at timestamptz,
  permission_signed_by text,
  headline text,
  body_md text,
  kpis_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  publication_uris text[] NOT NULL DEFAULT ARRAY[]::text[],
  use_in_pitch_deck boolean NOT NULL DEFAULT false,
  use_in_website boolean NOT NULL DEFAULT false,
  use_in_press boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  retired_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fccs_status ON public.founder_customer_case_studies(status);
CREATE INDEX IF NOT EXISTS idx_fccs_kind ON public.founder_customer_case_studies(case_study_kind);
CREATE INDEX IF NOT EXISTS idx_fccs_hospital ON public.founder_customer_case_studies(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_fccs_created ON public.founder_customer_case_studies(created_at DESC);

CREATE TABLE IF NOT EXISTS public.founder_customer_case_study_references (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_study_id uuid NOT NULL REFERENCES public.founder_customer_case_studies(id) ON DELETE CASCADE,
  referrer_contact_name text,
  referrer_contact_email text,
  prospect_name text,
  reference_call_at timestamptz,
  outcome text NOT NULL DEFAULT 'pending' CHECK (outcome IN ('pending','positive','neutral','negative','no_show','withdrawn')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fccsr_case ON public.founder_customer_case_study_references(case_study_id);
CREATE INDEX IF NOT EXISTS idx_fccsr_outcome ON public.founder_customer_case_study_references(outcome);
CREATE INDEX IF NOT EXISTS idx_fccsr_created ON public.founder_customer_case_study_references(created_at DESC);

ALTER TABLE public.founder_customer_case_studies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_customer_case_study_references ENABLE ROW LEVEL SECURITY;

-- RPC 1: 15-KPI summary
CREATE OR REPLACE FUNCTION public.founder_case_study_tracker_summary()
RETURNS TABLE (
  total_case_studies int,
  draft_count int,
  permission_pending_count int,
  permission_granted_count int,
  published_count int,
  retired_count int,
  permission_denied_count int,
  in_pitch_deck_count int,
  in_website_count int,
  in_press_count int,
  total_references int,
  positive_outcomes int,
  negative_outcomes int,
  pending_references int,
  conversion_rate_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  WITH c AS (SELECT * FROM public.founder_customer_case_studies),
  r AS (SELECT * FROM public.founder_customer_case_study_references)
  SELECT
    (SELECT count(*)::int FROM c),
    (SELECT count(*)::int FROM c WHERE status='draft'),
    (SELECT count(*)::int FROM c WHERE status='permission_pending'),
    (SELECT count(*)::int FROM c WHERE status='permission_granted'),
    (SELECT count(*)::int FROM c WHERE status='published'),
    (SELECT count(*)::int FROM c WHERE status='retired'),
    (SELECT count(*)::int FROM c WHERE status='permission_denied'),
    (SELECT count(*)::int FROM c WHERE use_in_pitch_deck = true),
    (SELECT count(*)::int FROM c WHERE use_in_website = true),
    (SELECT count(*)::int FROM c WHERE use_in_press = true),
    (SELECT count(*)::int FROM r),
    (SELECT count(*)::int FROM r WHERE outcome='positive'),
    (SELECT count(*)::int FROM r WHERE outcome='negative'),
    (SELECT count(*)::int FROM r WHERE outcome='pending'),
    (SELECT CASE WHEN count(*) FILTER (WHERE outcome IN ('positive','neutral','negative','no_show','withdrawn')) > 0
       THEN round(100.0 * count(*) FILTER (WHERE outcome='positive') / count(*) FILTER (WHERE outcome IN ('positive','neutral','negative','no_show','withdrawn')), 2)
       ELSE 0 END FROM r);
END;
$$;

-- RPC 2: recent 30 case studies
CREATE OR REPLACE FUNCTION public.founder_case_studies_recent()
RETURNS SETOF public.founder_customer_case_studies
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM public.founder_customer_case_studies ORDER BY created_at DESC LIMIT 30;
END;
$$;

-- RPC 3: recent 30 references
CREATE OR REPLACE FUNCTION public.founder_case_study_references_recent(p_case_study_id uuid DEFAULT NULL)
RETURNS SETOF public.founder_customer_case_study_references
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
    SELECT * FROM public.founder_customer_case_study_references
    WHERE p_case_study_id IS NULL OR case_study_id = p_case_study_id
    ORDER BY created_at DESC LIMIT 30;
END;
$$;

-- RPC 4: published-only feed
CREATE OR REPLACE FUNCTION public.founder_case_studies_published()
RETURNS SETOF public.founder_customer_case_studies
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY SELECT * FROM public.founder_customer_case_studies
    WHERE status='published' ORDER BY published_at DESC NULLS LAST LIMIT 30;
END;
$$;

-- RPC 5: register a new case study (draft)
CREATE OR REPLACE FUNCTION public.log_founder_case_study_register(
  p_case_study_label text,
  p_case_study_kind text,
  p_hospital_user_id uuid DEFAULT NULL,
  p_headline text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_case_study_kind NOT IN ('uptime_win','cost_savings','quality_improvement','vertical_expansion','code_red_save','dispute_resolution','platform_referral') THEN
    RAISE EXCEPTION 'invalid kind' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.founder_customer_case_studies(case_study_label, case_study_kind, hospital_user_id, headline, status)
  VALUES (p_case_study_label, p_case_study_kind, p_hospital_user_id, p_headline, 'draft')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- RPC 6: status transition
CREATE OR REPLACE FUNCTION public.log_founder_case_study_status(
  p_case_study_id uuid,
  p_new_status text,
  p_permission_signed_by text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_new_status NOT IN ('draft','permission_pending','permission_granted','published','retired','permission_denied') THEN
    RAISE EXCEPTION 'invalid status' USING ERRCODE='22023';
  END IF;
  UPDATE public.founder_customer_case_studies
    SET status = p_new_status,
        permission_granted_at = CASE WHEN p_new_status='permission_granted' THEN COALESCE(permission_granted_at, now()) ELSE permission_granted_at END,
        permission_signed_by = COALESCE(p_permission_signed_by, permission_signed_by),
        published_at = CASE WHEN p_new_status='published' THEN COALESCE(published_at, now()) ELSE published_at END,
        retired_at = CASE WHEN p_new_status='retired' THEN COALESCE(retired_at, now()) ELSE retired_at END,
        updated_at = now()
  WHERE id = p_case_study_id;
END;
$$;

-- RPC 7: record a reference call outcome
CREATE OR REPLACE FUNCTION public.log_founder_case_study_record_reference(
  p_case_study_id uuid,
  p_referrer_contact_name text,
  p_referrer_contact_email text,
  p_prospect_name text,
  p_outcome text DEFAULT 'pending',
  p_notes text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  IF p_outcome NOT IN ('pending','positive','neutral','negative','no_show','withdrawn') THEN
    RAISE EXCEPTION 'invalid outcome' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.founder_customer_case_study_references(
    case_study_id, referrer_contact_name, referrer_contact_email, prospect_name,
    reference_call_at, outcome, notes
  ) VALUES (
    p_case_study_id, p_referrer_contact_name, p_referrer_contact_email, p_prospect_name,
    CASE WHEN p_outcome <> 'pending' THEN now() ELSE NULL END, p_outcome, p_notes
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.founder_case_study_tracker_summary() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_case_studies_recent() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_case_study_references_recent(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.founder_case_studies_published() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_case_study_register(text,text,uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_case_study_status(uuid,text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.log_founder_case_study_record_reference(uuid,text,text,text,text,text) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.founder_case_study_tracker_summary() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_case_studies_recent() TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_case_study_references_recent(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.founder_case_studies_published() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_case_study_register(text,text,uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_case_study_status(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_founder_case_study_record_reference(uuid,text,text,text,text,text) TO authenticated;

COMMIT;