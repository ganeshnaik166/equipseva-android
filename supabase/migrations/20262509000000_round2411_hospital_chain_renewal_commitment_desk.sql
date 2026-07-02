-- r2411 — hospital-chain-renewal-commitment-desk
-- Multi-year renewal conversations × commitment level × blockers × ARR exposure

BEGIN;

-- =====================================================================
-- TABLE 1: chain_renewal_conversations_r2411
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.chain_renewal_conversations_r2411 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  conversation_at timestamptz NOT NULL DEFAULT now(),
  commitment_level text NOT NULL CHECK (commitment_level IN ('none','verbal','loi','signed','dropped')),
  term_years integer NOT NULL CHECK (term_years BETWEEN 1 AND 10),
  value_per_year_rupees bigint NOT NULL CHECK (value_per_year_rupees >= 0),
  blocker_kind text NOT NULL CHECK (blocker_kind IN ('price','feature','legal','competitor','personnel','none')),
  blocker_notes text,
  owner_email text NOT NULL,
  next_step_due_at timestamptz,
  notes text
);

ALTER TABLE public.chain_renewal_conversations_r2411 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.chain_renewal_conversations_r2411
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS chain_renewal_conv_r2411_chain_idx
  ON public.chain_renewal_conversations_r2411(chain_name);
CREATE INDEX IF NOT EXISTS chain_renewal_conv_r2411_commit_idx
  ON public.chain_renewal_conversations_r2411(commitment_level);
CREATE INDEX IF NOT EXISTS chain_renewal_conv_r2411_due_idx
  ON public.chain_renewal_conversations_r2411(next_step_due_at);

-- =====================================================================
-- TABLE 2: chain_renewal_arr_snapshots_r2411
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.chain_renewal_arr_snapshots_r2411 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz NOT NULL DEFAULT now(),
  chain_name text NOT NULL,
  snapshot_date date NOT NULL DEFAULT current_date,
  hospital_count integer NOT NULL CHECK (hospital_count >= 0),
  total_arr_rupees bigint NOT NULL CHECK (total_arr_rupees >= 0),
  expiring_in_90d_rupees bigint NOT NULL DEFAULT 0 CHECK (expiring_in_90d_rupees >= 0),
  expiring_in_180d_rupees bigint NOT NULL DEFAULT 0 CHECK (expiring_in_180d_rupees >= 0),
  at_risk_rupees bigint NOT NULL DEFAULT 0 CHECK (at_risk_rupees >= 0),
  committed_renewal_rupees bigint NOT NULL DEFAULT 0 CHECK (committed_renewal_rupees >= 0)
);

ALTER TABLE public.chain_renewal_arr_snapshots_r2411 ENABLE ROW LEVEL SECURITY;

CREATE POLICY founder_all ON public.chain_renewal_arr_snapshots_r2411
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE INDEX IF NOT EXISTS chain_renewal_arr_r2411_chain_idx
  ON public.chain_renewal_arr_snapshots_r2411(chain_name);
CREATE INDEX IF NOT EXISTS chain_renewal_arr_r2411_date_idx
  ON public.chain_renewal_arr_snapshots_r2411(snapshot_date DESC);

-- =====================================================================
-- RPC 1: list_renewal_conversations_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.list_renewal_conversations_r2411()
RETURNS TABLE(
  id uuid,
  chain_name text,
  conversation_at timestamptz,
  commitment_level text,
  term_years integer,
  value_per_year_rupees bigint,
  total_deal_value_rupees bigint,
  blocker_kind text,
  blocker_notes text,
  owner_email text,
  next_step_due_at timestamptz,
  days_until_next_step integer,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.conversation_at,
    c.commitment_level,
    c.term_years,
    c.value_per_year_rupees,
    (c.value_per_year_rupees * c.term_years)::bigint AS total_deal_value_rupees,
    c.blocker_kind,
    c.blocker_notes,
    c.owner_email,
    c.next_step_due_at,
    CASE WHEN c.next_step_due_at IS NULL THEN NULL
         ELSE EXTRACT(DAY FROM (c.next_step_due_at - now()))::integer
    END AS days_until_next_step,
    c.notes
  FROM public.chain_renewal_conversations_r2411 c
  ORDER BY c.conversation_at DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_renewal_conversations_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_renewal_conversations_r2411() TO authenticated;

-- =====================================================================
-- RPC 2: commitment_funnel_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.commitment_funnel_r2411()
RETURNS TABLE(
  commitment_level text,
  conversation_count bigint,
  total_arr_rupees bigint,
  avg_term_years numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.commitment_level,
    COUNT(*)::bigint AS conversation_count,
    COALESCE(SUM(c.value_per_year_rupees * c.term_years),0)::bigint AS total_arr_rupees,
    ROUND(AVG(c.term_years)::numeric, 2) AS avg_term_years
  FROM public.chain_renewal_conversations_r2411 c
  GROUP BY c.commitment_level
  ORDER BY
    CASE c.commitment_level
      WHEN 'signed' THEN 1
      WHEN 'loi' THEN 2
      WHEN 'verbal' THEN 3
      WHEN 'none' THEN 4
      WHEN 'dropped' THEN 5
      ELSE 6
    END;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.commitment_funnel_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.commitment_funnel_r2411() TO authenticated;

-- =====================================================================
-- RPC 3: top_blockers_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_blockers_r2411()
RETURNS TABLE(
  blocker_kind text,
  blocker_count bigint,
  arr_blocked_rupees bigint,
  chains_impacted bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.blocker_kind,
    COUNT(*)::bigint AS blocker_count,
    COALESCE(SUM(c.value_per_year_rupees * c.term_years),0)::bigint AS arr_blocked_rupees,
    COUNT(DISTINCT c.chain_name)::bigint AS chains_impacted
  FROM public.chain_renewal_conversations_r2411 c
  WHERE c.blocker_kind <> 'none'
  GROUP BY c.blocker_kind
  ORDER BY arr_blocked_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_blockers_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_blockers_r2411() TO authenticated;

-- =====================================================================
-- RPC 4: expiring_soon_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.expiring_soon_r2411()
RETURNS TABLE(
  chain_name text,
  snapshot_date date,
  expiring_in_90d_rupees bigint,
  expiring_in_180d_rupees bigint,
  committed_renewal_rupees bigint,
  uncommitted_gap_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.chain_name)
    s.chain_name,
    s.snapshot_date,
    s.expiring_in_90d_rupees,
    s.expiring_in_180d_rupees,
    s.committed_renewal_rupees,
    GREATEST(s.expiring_in_180d_rupees - s.committed_renewal_rupees, 0)::bigint AS uncommitted_gap_rupees
  FROM public.chain_renewal_arr_snapshots_r2411 s
  ORDER BY s.chain_name, s.snapshot_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.expiring_soon_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.expiring_soon_r2411() TO authenticated;

-- =====================================================================
-- RPC 5: top_arr_at_risk_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.top_arr_at_risk_r2411()
RETURNS TABLE(
  chain_name text,
  snapshot_date date,
  hospital_count integer,
  total_arr_rupees bigint,
  at_risk_rupees bigint,
  at_risk_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (s.chain_name)
    s.chain_name,
    s.snapshot_date,
    s.hospital_count,
    s.total_arr_rupees,
    s.at_risk_rupees,
    CASE WHEN s.total_arr_rupees = 0 THEN 0
         ELSE ROUND((s.at_risk_rupees::numeric / s.total_arr_rupees::numeric) * 100, 2)
    END AS at_risk_pct
  FROM public.chain_renewal_arr_snapshots_r2411 s
  ORDER BY s.chain_name, s.snapshot_date DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.top_arr_at_risk_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_arr_at_risk_r2411() TO authenticated;

-- =====================================================================
-- RPC 6: chain_renewal_health_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.chain_renewal_health_r2411()
RETURNS TABLE(
  chain_name text,
  latest_commitment text,
  conversation_count bigint,
  total_deal_value_rupees bigint,
  last_conversation_at timestamptz,
  has_open_blocker boolean,
  next_due_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH latest AS (
    SELECT DISTINCT ON (c.chain_name)
      c.chain_name,
      c.commitment_level,
      c.conversation_at,
      c.blocker_kind,
      c.next_step_due_at
    FROM public.chain_renewal_conversations_r2411 c
    ORDER BY c.chain_name, c.conversation_at DESC
  ),
  agg AS (
    SELECT
      c.chain_name,
      COUNT(*)::bigint AS conversation_count,
      COALESCE(SUM(c.value_per_year_rupees * c.term_years),0)::bigint AS total_deal_value_rupees
    FROM public.chain_renewal_conversations_r2411 c
    GROUP BY c.chain_name
  )
  SELECT
    l.chain_name,
    l.commitment_level AS latest_commitment,
    a.conversation_count,
    a.total_deal_value_rupees,
    l.conversation_at AS last_conversation_at,
    (l.blocker_kind <> 'none') AS has_open_blocker,
    l.next_step_due_at AS next_due_at
  FROM latest l
  JOIN agg a ON a.chain_name = l.chain_name
  ORDER BY a.total_deal_value_rupees DESC;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.chain_renewal_health_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chain_renewal_health_r2411() TO authenticated;

-- =====================================================================
-- RPC 7: weekly_progress_r2411
-- =====================================================================
CREATE OR REPLACE FUNCTION public.weekly_progress_r2411()
RETURNS TABLE(
  week_start date,
  conversation_count bigint,
  signed_count bigint,
  loi_count bigint,
  verbal_count bigint,
  arr_progressed_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    date_trunc('week', c.conversation_at)::date AS week_start,
    COUNT(*)::bigint AS conversation_count,
    COUNT(*) FILTER (WHERE c.commitment_level = 'signed')::bigint AS signed_count,
    COUNT(*) FILTER (WHERE c.commitment_level = 'loi')::bigint AS loi_count,
    COUNT(*) FILTER (WHERE c.commitment_level = 'verbal')::bigint AS verbal_count,
    COALESCE(SUM(c.value_per_year_rupees * c.term_years) FILTER (WHERE c.commitment_level IN ('signed','loi','verbal')),0)::bigint AS arr_progressed_rupees
  FROM public.chain_renewal_conversations_r2411 c
  GROUP BY 1
  ORDER BY week_start DESC
  LIMIT 12;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.weekly_progress_r2411() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.weekly_progress_r2411() TO authenticated;

-- =====================================================================
-- SEED DATA — chain_renewal_conversations_r2411
-- =====================================================================
INSERT INTO public.chain_renewal_conversations_r2411
  (chain_name, hospital_user_id, conversation_at, commitment_level, term_years, value_per_year_rupees, blocker_kind, blocker_notes, owner_email, next_step_due_at, notes)
VALUES
  ('Apollo Hospitals',
   (SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   now() - interval '3 days', 'loi', 3, 4800000, 'legal',
   'MSA legal redlines pending — clause 14.2 (data residency) under review by Apollo counsel',
   'founder@equipseva.in', now() + interval '7 days',
   'CFO + Group Procurement Head met. LOI signed, awaiting MSA execution.'),
  ('Manipal Health',
   (SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   now() - interval '8 days', 'verbal', 2, 2400000, 'price',
   'Asking for 12% discount on 2-year commit; comp at 8%',
   'founder@equipseva.in', now() + interval '4 days',
   'Verbal yes from Bangalore region. Need price desk approval before counter.'),
  ('Fortis Healthcare',
   (SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   now() - interval '15 days', 'signed', 3, 3600000, 'none',
   NULL, 'founder@equipseva.in', NULL,
   'Signed 3-year renewal. Auto-renew clause negotiated out, replaced with 90-day review.'),
  ('Max Healthcare',
   (SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   now() - interval '21 days', 'none', 2, 1800000, 'competitor',
   'Evaluating MediFix as alternative. Comparison shootout scheduled.',
   'founder@equipseva.in', now() + interval '14 days',
   'At risk. Need engineer reference call + AMC SLA proof pack.'),
  ('Care Hospitals',
   (SELECT id FROM public.profiles WHERE role='hospital_admin' LIMIT 1),
   now() - interval '30 days', 'dropped', 1, 900000, 'personnel',
   'Champion (Head of Bio-Med) left org. New owner unknown.',
   'founder@equipseva.in', NULL,
   'Lost for now. Re-engage after Q2 once new BME head hired.');

-- =====================================================================
-- SEED DATA — chain_renewal_arr_snapshots_r2411
-- =====================================================================
INSERT INTO public.chain_renewal_arr_snapshots_r2411
  (chain_name, snapshot_date, hospital_count, total_arr_rupees, expiring_in_90d_rupees, expiring_in_180d_rupees, at_risk_rupees, committed_renewal_rupees)
VALUES
  ('Apollo Hospitals', current_date, 12, 48000000, 14400000, 24000000, 4800000, 14400000),
  ('Manipal Health', current_date, 8, 24000000, 4800000, 12000000, 7200000, 2400000),
  ('Fortis Healthcare', current_date, 10, 36000000, 0, 10800000, 0, 10800000),
  ('Max Healthcare', current_date, 6, 18000000, 7200000, 14400000, 14400000, 0),
  ('Care Hospitals', current_date, 5, 9000000, 1800000, 5400000, 9000000, 0);

-- =====================================================================
-- COMMENTS
-- =====================================================================
COMMENT ON TABLE public.chain_renewal_conversations_r2411 IS
  'r2411 — per-conversation log of multi-year chain renewal discussions with commitment level and blocker classification.';
COMMENT ON TABLE public.chain_renewal_arr_snapshots_r2411 IS
  'r2411 — periodic snapshot of ARR exposure per hospital chain: expiring, at-risk, and committed.';
COMMENT ON FUNCTION public.list_renewal_conversations_r2411() IS
  'r2411 — list all renewal conversations with derived total deal value and days-to-next-step.';
COMMENT ON FUNCTION public.commitment_funnel_r2411() IS
  'r2411 — funnel by commitment level (signed → loi → verbal → none → dropped).';
COMMENT ON FUNCTION public.top_blockers_r2411() IS
  'r2411 — blocker kinds ranked by ARR blocked.';
COMMENT ON FUNCTION public.expiring_soon_r2411() IS
  'r2411 — latest snapshot per chain showing 90d/180d expiring vs committed and the uncommitted gap.';
COMMENT ON FUNCTION public.top_arr_at_risk_r2411() IS
  'r2411 — chains ranked by ARR at risk with at-risk percentage of total ARR.';
COMMENT ON FUNCTION public.chain_renewal_health_r2411() IS
  'r2411 — per-chain rollup: latest commitment, conversation count, total deal value, open blocker, next due.';
COMMENT ON FUNCTION public.weekly_progress_r2411() IS
  'r2411 — last 12 weeks of conversation activity bucketed by commitment level and ARR progressed.';

