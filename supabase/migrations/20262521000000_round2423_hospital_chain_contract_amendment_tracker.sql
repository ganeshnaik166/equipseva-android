-- Round 2423: hospital chain contract amendment tracker
-- Tables: chain_contract_amendments_r2423, chain_amendment_revisions_r2423
-- 7 RPCs all founder-gated

CREATE TABLE IF NOT EXISTS public.chain_contract_amendments_r2423 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  amendment_kind text NOT NULL CHECK (amendment_kind IN ('price_change','scope_change','term_extension','sla_change','headcount_change','equipment_add','equipment_remove')),
  proposed_at timestamptz NOT NULL DEFAULT now(),
  signed_at timestamptz,
  arr_delta_rupees bigint NOT NULL DEFAULT 0,
  negotiation_owner_email text,
  counterparty_owner_email text,
  status text NOT NULL DEFAULT 'proposed' CHECK (status IN ('proposed','in_negotiation','signed','rejected','withdrawn')),
  revision_count int NOT NULL DEFAULT 0,
  key_terms_md text,
  blockers text,
  notes text
);

ALTER TABLE public.chain_contract_amendments_r2423 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_contract_amendments_r2423;
CREATE POLICY founder_all ON public.chain_contract_amendments_r2423
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.chain_amendment_revisions_r2423 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  amendment_id uuid NOT NULL REFERENCES public.chain_contract_amendments_r2423(id) ON DELETE CASCADE,
  revision_number int NOT NULL,
  proposed_by_side text NOT NULL CHECK (proposed_by_side IN ('ours','theirs')),
  changes_md text,
  proposed_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','superseded','accepted','rejected')),
  notes text
);

ALTER TABLE public.chain_amendment_revisions_r2423 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all ON public.chain_amendment_revisions_r2423;
CREATE POLICY founder_all ON public.chain_amendment_revisions_r2423
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed 4 amendments
INSERT INTO public.chain_contract_amendments_r2423 (chain_name, amendment_kind, proposed_at, signed_at, arr_delta_rupees, negotiation_owner_email, counterparty_owner_email, status, revision_count, key_terms_md, blockers, notes) VALUES
  ('Apollo Hospitals', 'price_change', now() - interval '21 days', now() - interval '4 days', 2400000, 'ganesh@equipseva.in', 'cfo@apollo.example', 'signed', 3, '5% AMC tier-2 price uplift across 14 sites', null, 'closed clean'),
  ('Manipal Hospitals', 'scope_change', now() - interval '12 days', null, 1850000, 'ganesh@equipseva.in', 'ops.head@manipal.example', 'in_negotiation', 2, 'Add cath-lab equipment to AMC scope at 6 hospitals', 'legal review pending on liability cap', 'targeting sign-off by next Friday'),
  ('Yashoda Hospitals', 'term_extension', now() - interval '8 days', null, 4200000, 'ganesh@equipseva.in', 'procurement@yashoda.example', 'proposed', 1, '3-year extension with 4% annual escalator', 'awaiting board approval on counterparty', null),
  ('Fortis Healthcare', 'sla_change', now() - interval '30 days', null, -650000, 'ganesh@equipseva.in', 'biomed@fortis.example', 'rejected', 4, 'Tighten response SLA to 2h for critical equipment', 'counterparty pushed back on penalty clause', 'will re-propose with insurance wrap');

-- Seed revisions
INSERT INTO public.chain_amendment_revisions_r2423 (amendment_id, revision_number, proposed_by_side, changes_md, proposed_at, status, notes)
SELECT id, 1, 'ours', 'Initial price uplift proposal at 6%', proposed_at, 'superseded', 'rev 1' FROM public.chain_contract_amendments_r2423 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.chain_amendment_revisions_r2423 (amendment_id, revision_number, proposed_by_side, changes_md, proposed_at, status, notes)
SELECT id, 2, 'theirs', 'Counter at 4% with 2-year lock', proposed_at + interval '5 days', 'superseded', 'rev 2' FROM public.chain_contract_amendments_r2423 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.chain_amendment_revisions_r2423 (amendment_id, revision_number, proposed_by_side, changes_md, proposed_at, status, notes)
SELECT id, 3, 'ours', 'Compromise at 5% with 18-month lock', proposed_at + interval '14 days', 'accepted', 'final rev' FROM public.chain_contract_amendments_r2423 WHERE chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.chain_amendment_revisions_r2423 (amendment_id, revision_number, proposed_by_side, changes_md, proposed_at, status, notes)
SELECT id, 1, 'ours', 'Proposed cath-lab inclusion at base AMC rate', proposed_at, 'superseded', 'rev 1' FROM public.chain_contract_amendments_r2423 WHERE chain_name = 'Manipal Hospitals' LIMIT 1;

INSERT INTO public.chain_amendment_revisions_r2423 (amendment_id, revision_number, proposed_by_side, changes_md, proposed_at, status, notes)
SELECT id, 2, 'theirs', 'Asked for liability cap at 2x annual fee', proposed_at + interval '6 days', 'open', 'rev 2 — open' FROM public.chain_contract_amendments_r2423 WHERE chain_name = 'Manipal Hospitals' LIMIT 1;

INSERT INTO public.chain_amendment_revisions_r2423 (amendment_id, revision_number, proposed_by_side, changes_md, proposed_at, status, notes)
SELECT id, 1, 'ours', '3-year term with 4% escalator', proposed_at, 'open', null FROM public.chain_contract_amendments_r2423 WHERE chain_name = 'Yashoda Hospitals' LIMIT 1;

-- Sync revision_count
UPDATE public.chain_contract_amendments_r2423 a
SET revision_count = (SELECT COUNT(*) FROM public.chain_amendment_revisions_r2423 r WHERE r.amendment_id = a.id);

-- RPC 1: list_amendments_r2423
CREATE OR REPLACE FUNCTION public.list_amendments_r2423()
RETURNS TABLE (
  id uuid,
  chain_name text,
  amendment_kind text,
  proposed_at timestamptz,
  signed_at timestamptz,
  arr_delta_rupees bigint,
  negotiation_owner_email text,
  counterparty_owner_email text,
  status text,
  revision_count int,
  blockers text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.amendment_kind, a.proposed_at, a.signed_at,
         a.arr_delta_rupees, a.negotiation_owner_email, a.counterparty_owner_email,
         a.status, a.revision_count, a.blockers
  FROM public.chain_contract_amendments_r2423 a
  ORDER BY a.proposed_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_amendments_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_amendments_r2423() TO authenticated;

-- RPC 2: list_revisions_r2423
CREATE OR REPLACE FUNCTION public.list_revisions_r2423()
RETURNS TABLE (
  id uuid,
  chain_name text,
  amendment_kind text,
  revision_number int,
  proposed_by_side text,
  proposed_at timestamptz,
  status text,
  changes_md text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, a.chain_name, a.amendment_kind, r.revision_number, r.proposed_by_side,
         r.proposed_at, r.status, r.changes_md
  FROM public.chain_amendment_revisions_r2423 r
  JOIN public.chain_contract_amendments_r2423 a ON a.id = r.amendment_id
  ORDER BY r.proposed_at DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.list_revisions_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_revisions_r2423() TO authenticated;

-- RPC 3: top_negotiations_owners_r2423
CREATE OR REPLACE FUNCTION public.top_negotiations_owners_r2423()
RETURNS TABLE (
  negotiation_owner_email text,
  open_count bigint,
  signed_count bigint,
  arr_delta_open_rupees bigint,
  arr_delta_signed_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.negotiation_owner_email,
         COUNT(*) FILTER (WHERE a.status IN ('proposed','in_negotiation'))::bigint AS open_count,
         COUNT(*) FILTER (WHERE a.status = 'signed')::bigint AS signed_count,
         COALESCE(SUM(a.arr_delta_rupees) FILTER (WHERE a.status IN ('proposed','in_negotiation')), 0)::bigint AS arr_delta_open_rupees,
         COALESCE(SUM(a.arr_delta_rupees) FILTER (WHERE a.status = 'signed'), 0)::bigint AS arr_delta_signed_rupees
  FROM public.chain_contract_amendments_r2423 a
  WHERE a.negotiation_owner_email IS NOT NULL
  GROUP BY a.negotiation_owner_email
  ORDER BY (COUNT(*) FILTER (WHERE a.status IN ('proposed','in_negotiation'))) DESC,
           COALESCE(SUM(a.arr_delta_rupees) FILTER (WHERE a.status IN ('proposed','in_negotiation')), 0) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.top_negotiations_owners_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_negotiations_owners_r2423() TO authenticated;

-- RPC 4: arr_delta_by_kind_r2423
CREATE OR REPLACE FUNCTION public.arr_delta_by_kind_r2423()
RETURNS TABLE (
  amendment_kind text,
  count bigint,
  arr_delta_total_rupees bigint,
  arr_delta_signed_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.amendment_kind,
         COUNT(*)::bigint AS count,
         COALESCE(SUM(a.arr_delta_rupees), 0)::bigint AS arr_delta_total_rupees,
         COALESCE(SUM(a.arr_delta_rupees) FILTER (WHERE a.status = 'signed'), 0)::bigint AS arr_delta_signed_rupees
  FROM public.chain_contract_amendments_r2423 a
  GROUP BY a.amendment_kind
  ORDER BY COALESCE(SUM(a.arr_delta_rupees), 0) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.arr_delta_by_kind_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.arr_delta_by_kind_r2423() TO authenticated;

-- RPC 5: time_to_sign_distribution_r2423
CREATE OR REPLACE FUNCTION public.time_to_sign_distribution_r2423()
RETURNS TABLE (
  bucket text,
  count bigint,
  arr_delta_signed_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH signed AS (
    SELECT a.arr_delta_rupees,
           EXTRACT(EPOCH FROM (a.signed_at - a.proposed_at)) / 86400.0 AS days_to_sign
    FROM public.chain_contract_amendments_r2423 a
    WHERE a.status = 'signed' AND a.signed_at IS NOT NULL
  ),
  bucketed AS (
    SELECT CASE
      WHEN days_to_sign <= 7 THEN '0_to_7d'
      WHEN days_to_sign <= 14 THEN '8_to_14d'
      WHEN days_to_sign <= 30 THEN '15_to_30d'
      WHEN days_to_sign <= 60 THEN '31_to_60d'
      ELSE 'over_60d'
    END AS bucket,
    arr_delta_rupees
    FROM signed
  )
  SELECT b.bucket,
         COUNT(*)::bigint,
         COALESCE(SUM(b.arr_delta_rupees), 0)::bigint
  FROM bucketed b
  GROUP BY b.bucket
  ORDER BY CASE b.bucket
    WHEN '0_to_7d' THEN 1
    WHEN '8_to_14d' THEN 2
    WHEN '15_to_30d' THEN 3
    WHEN '31_to_60d' THEN 4
    ELSE 5 END;
END; $$;
REVOKE EXECUTE ON FUNCTION public.time_to_sign_distribution_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.time_to_sign_distribution_r2423() TO authenticated;

-- RPC 6: in_negotiation_focus_r2423
CREATE OR REPLACE FUNCTION public.in_negotiation_focus_r2423()
RETURNS TABLE (
  id uuid,
  chain_name text,
  amendment_kind text,
  proposed_at timestamptz,
  days_open numeric,
  arr_delta_rupees bigint,
  revision_count int,
  blockers text,
  negotiation_owner_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.chain_name, a.amendment_kind, a.proposed_at,
         ROUND(EXTRACT(EPOCH FROM (now() - a.proposed_at))::numeric / 86400.0, 1) AS days_open,
         a.arr_delta_rupees, a.revision_count, a.blockers, a.negotiation_owner_email
  FROM public.chain_contract_amendments_r2423 a
  WHERE a.status IN ('proposed','in_negotiation')
  ORDER BY a.arr_delta_rupees DESC, a.proposed_at ASC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.in_negotiation_focus_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.in_negotiation_focus_r2423() TO authenticated;

-- RPC 7: status_breakdown_r2423
CREATE OR REPLACE FUNCTION public.status_breakdown_r2423()
RETURNS TABLE (
  status text,
  count bigint,
  arr_delta_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.status,
         COUNT(*)::bigint,
         COALESCE(SUM(a.arr_delta_rupees), 0)::bigint
  FROM public.chain_contract_amendments_r2423 a
  GROUP BY a.status
  ORDER BY COUNT(*) DESC;
END; $$;
REVOKE EXECUTE ON FUNCTION public.status_breakdown_r2423() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_breakdown_r2423() TO authenticated;
