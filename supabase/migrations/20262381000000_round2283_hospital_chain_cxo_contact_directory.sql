BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_cxo_contacts_r2283 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier1','tier2','tier3','strategic','growth')),
  contact_name text NOT NULL,
  contact_role text NOT NULL CHECK (contact_role IN ('cxo','ceo','coo','cfo','cmo','cto','vp_ops','head_biomed','head_procurement')),
  contact_email text NOT NULL,
  contact_phone text,
  hq_city text NOT NULL,
  total_facilities int NOT NULL DEFAULT 0,
  active_amc_count int NOT NULL DEFAULT 0,
  annual_contract_value_rupees bigint NOT NULL DEFAULT 0,
  decision_maker boolean NOT NULL DEFAULT false,
  founder_priority boolean NOT NULL DEFAULT false,
  relationship_status text NOT NULL DEFAULT 'warm' CHECK (relationship_status IN ('cold','warm','engaged','champion','at_risk')),
  notes text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hcxo_r2283_chain_idx ON public.hospital_chain_cxo_contacts_r2283 (chain_name);
CREATE INDEX IF NOT EXISTS hcxo_r2283_tier_idx ON public.hospital_chain_cxo_contacts_r2283 (chain_tier);
CREATE INDEX IF NOT EXISTS hcxo_r2283_priority_idx ON public.hospital_chain_cxo_contacts_r2283 (founder_priority) WHERE founder_priority;
CREATE INDEX IF NOT EXISTS hcxo_r2283_status_idx ON public.hospital_chain_cxo_contacts_r2283 (relationship_status);

ALTER TABLE public.hospital_chain_cxo_contacts_r2283 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all_hcxo_r2283 ON public.hospital_chain_cxo_contacts_r2283;
CREATE POLICY founder_all_hcxo_r2283 ON public.hospital_chain_cxo_contacts_r2283
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

CREATE TABLE IF NOT EXISTS public.hospital_chain_cxo_touchpoints_r2283 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.hospital_chain_cxo_contacts_r2283(id) ON DELETE CASCADE,
  touchpoint_type text NOT NULL CHECK (touchpoint_type IN ('call','email','meeting','site_visit','event','demo','escalation','qbr')),
  occurred_at timestamptz NOT NULL,
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','followup_needed','closed_won','closed_lost')),
  summary text NOT NULL,
  next_action text,
  next_action_due timestamptz,
  recorded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hcxo_tp_r2283_contact_idx ON public.hospital_chain_cxo_touchpoints_r2283 (contact_id);
CREATE INDEX IF NOT EXISTS hcxo_tp_r2283_occurred_idx ON public.hospital_chain_cxo_touchpoints_r2283 (occurred_at DESC);
CREATE INDEX IF NOT EXISTS hcxo_tp_r2283_due_idx ON public.hospital_chain_cxo_touchpoints_r2283 (next_action_due) WHERE next_action_due IS NOT NULL;

ALTER TABLE public.hospital_chain_cxo_touchpoints_r2283 ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_all_hcxo_tp_r2283 ON public.hospital_chain_cxo_touchpoints_r2283;
CREATE POLICY founder_all_hcxo_tp_r2283 ON public.hospital_chain_cxo_touchpoints_r2283
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed contacts
WITH founder AS (
  SELECT id FROM public.profiles WHERE email = (auth.jwt()->>'email') LIMIT 1
), inserted AS (
  INSERT INTO public.hospital_chain_cxo_contacts_r2283
    (chain_name, chain_tier, contact_name, contact_role, contact_email, contact_phone, hq_city, total_facilities, active_amc_count, annual_contract_value_rupees, decision_maker, founder_priority, relationship_status, notes, created_by)
  VALUES
    ('Apollo Hospitals','tier1','Suneeta Reddy','cfo','suneeta@apollo-chain.example','+91-9000000001','Hyderabad',71,38,48000000,true,true,'champion','Champion of bonded-parts story; greenlit Tier-1 pilot',(SELECT id FROM founder)),
    ('Manipal Health','tier1','Dilip Jose','ceo','dilip@manipal-chain.example','+91-9000000002','Bangalore',29,17,22000000,true,true,'engaged','Quarterly QBR scheduled; pushing for SLA tightening',(SELECT id FROM founder)),
    ('Fortis Healthcare','tier1','Ashutosh Raghuvanshi','ceo','ashutosh@fortis-chain.example','+91-9000000003','Gurgaon',36,9,9500000,true,true,'warm','Pilot at 2 facilities; needs faster onboarding',(SELECT id FROM founder)),
    ('Max Healthcare','tier1','Abhay Soi','ceo','abhay@max-chain.example','+91-9000000004','Delhi',17,5,4800000,true,false,'engaged','Strong COO relationship; CEO hands-off',(SELECT id FROM founder)),
    ('Narayana Health','tier1','Viren Shetty','coo','viren@narayana-chain.example','+91-9000000005','Bangalore',24,14,18000000,true,true,'champion','Operational champion; vouches in industry forums',(SELECT id FROM founder)),
    ('Aster DM','tier2','Alisha Moopen','coo','alisha@aster-chain.example','+91-9000000006','Kochi',13,4,3400000,true,false,'engaged','Wants pricing tiers for Kerala vs metro',(SELECT id FROM founder)),
    ('KIMS Hospitals','tier2','Bhaskara Rao Bollineni','ceo','bhaskar@kims-chain.example','+91-9000000007','Hyderabad',12,8,8900000,true,true,'champion','Founder personally engaged; key reference',(SELECT id FROM founder)),
    ('Yashoda Hospitals','tier2','Pavan Gorukanti','coo','pavan@yashoda-chain.example','+91-9000000008','Hyderabad',5,3,3200000,true,false,'engaged','Pushing for biomed dashboard',(SELECT id FROM founder)),
    ('Continental Hospitals','tier2','Guru N Reddy','ceo','guru@continental-chain.example','+91-9000000009','Hyderabad',2,2,2100000,true,false,'warm','Smaller scale but premium budget',(SELECT id FROM founder)),
    ('Rainbow Children','tier2','Ramesh Kancharla','ceo','ramesh@rainbow-chain.example','+91-9000000010','Hyderabad',14,6,5200000,true,true,'engaged','Pediatric niche; high-touch needed',(SELECT id FROM founder)),
    ('Medanta','tier1','Naresh Trehan','ceo','naresh@medanta-chain.example','+91-9000000011','Gurgaon',5,1,1200000,true,false,'cold','Founder-CEO; needs personal intro',(SELECT id FROM founder)),
    ('AIG Hospitals','tier2','Nageshwar Reddy','ceo','nageshwar@aig-chain.example','+91-9000000012','Hyderabad',2,2,3800000,true,true,'champion','Endoscopy gold standard; equipment heavy',(SELECT id FROM founder)),
    ('Care Hospitals','tier2','Jasdeep Singh','ceo','jasdeep@care-chain.example','+91-9000000013','Hyderabad',16,4,4100000,true,false,'warm','Recent ownership change; rebuilding relationship',(SELECT id FROM founder)),
    ('Columbia Asia','tier3','Anurag Yadav','coo','anurag@columbia-chain.example','+91-9000000014','Bangalore',11,2,1600000,true,false,'warm','Exit talks in market; risk',(SELECT id FROM founder)),
    ('Global Hospitals','tier3','Bhagavan Das','ceo','bhagavan@global-chain.example','+91-9000000015','Chennai',5,1,900000,false,false,'cold','Early conversations only',(SELECT id FROM founder)),
    ('Sakra World','tier3','Anantharaman Krishnamurthy','ceo','anantha@sakra-chain.example','+91-9000000016','Bangalore',1,1,1100000,true,false,'engaged','Single facility but premium',(SELECT id FROM founder)),
    ('Sterling Hospitals','tier3','Vijay Kachoria','ceo','vijay@sterling-chain.example','+91-9000000017','Ahmedabad',6,2,1800000,true,false,'warm','Gujarat regional play',(SELECT id FROM founder)),
    ('Wockhardt','tier3','Habil Khorakiwala','ceo','habil@wockhardt-chain.example','+91-9000000018','Mumbai',8,1,800000,true,false,'cold','Pharma legacy; slow decision cycle',(SELECT id FROM founder)),
    ('Ramaiah Memorial','growth','Naresh Shetty','coo','naresh.s@ramaiah-chain.example','+91-9000000019','Bangalore',1,1,1400000,true,false,'engaged','Academic; trial-friendly',(SELECT id FROM founder)),
    ('Asian Heart','growth','Ramakanta Panda','ceo','rama@asianheart-chain.example','+91-9000000020','Mumbai',1,1,2300000,true,true,'champion','Cardiac focused; pristine reputation',(SELECT id FROM founder))
  RETURNING id, chain_name, contact_role
)
INSERT INTO public.hospital_chain_cxo_touchpoints_r2283
  (contact_id, touchpoint_type, occurred_at, outcome, summary, next_action, next_action_due)
SELECT id, 'qbr', now() - interval '7 days', 'positive', 'QBR with ' || chain_name || ' ' || contact_role || ' — green across SLA + invoice cycle', 'Schedule next QBR + share Tier-1 expansion deck', now() + interval '60 days'
FROM inserted
WHERE contact_role IN ('ceo','cfo','coo');

-- RPC 1: priority directory
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_priority_directory()
RETURNS TABLE (
  contact_id uuid,
  chain_name text,
  chain_tier text,
  contact_name text,
  contact_role text,
  contact_email text,
  hq_city text,
  active_amc_count int,
  annual_contract_value_rupees bigint,
  relationship_status text,
  founder_priority boolean,
  last_touchpoint_at timestamptz,
  days_since_last_touch int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.chain_tier,
    c.contact_name,
    c.contact_role,
    c.contact_email,
    c.hq_city,
    c.active_amc_count,
    c.annual_contract_value_rupees,
    c.relationship_status,
    c.founder_priority,
    (SELECT MAX(t.occurred_at) FROM public.hospital_chain_cxo_touchpoints_r2283 t WHERE t.contact_id = c.id) AS last_touchpoint_at,
    (SELECT (EXTRACT(DAY FROM (now() - MAX(t.occurred_at))))::int FROM public.hospital_chain_cxo_touchpoints_r2283 t WHERE t.contact_id = c.id) AS days_since_last_touch
  FROM public.hospital_chain_cxo_contacts_r2283 c
  ORDER BY c.founder_priority DESC, c.annual_contract_value_rupees DESC;
END;
$$;

-- RPC 2: tier rollup
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_tier_rollup()
RETURNS TABLE (
  chain_tier text,
  contact_count int,
  decision_makers int,
  champions int,
  at_risk int,
  total_facilities int,
  total_acv_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.chain_tier,
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE c.decision_maker))::int,
    (COUNT(*) FILTER (WHERE c.relationship_status = 'champion'))::int,
    (COUNT(*) FILTER (WHERE c.relationship_status = 'at_risk'))::int,
    (SUM(c.total_facilities))::int,
    (SUM(c.annual_contract_value_rupees))::bigint
  FROM public.hospital_chain_cxo_contacts_r2283 c
  GROUP BY c.chain_tier
  ORDER BY c.chain_tier;
END;
$$;

-- RPC 3: relationship status mix
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_relationship_mix()
RETURNS TABLE (
  relationship_status text,
  cxo_count int,
  acv_rupees bigint,
  pct_of_acv numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_total bigint;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT COALESCE(SUM(annual_contract_value_rupees),0) INTO v_total FROM public.hospital_chain_cxo_contacts_r2283;
  RETURN QUERY
  SELECT
    c.relationship_status,
    (COUNT(*))::int,
    (SUM(c.annual_contract_value_rupees))::bigint,
    CASE WHEN v_total > 0 THEN ROUND((SUM(c.annual_contract_value_rupees)::numeric / v_total::numeric) * 100, 1) ELSE 0 END
  FROM public.hospital_chain_cxo_contacts_r2283 c
  GROUP BY c.relationship_status
  ORDER BY (SUM(c.annual_contract_value_rupees))::bigint DESC;
END;
$$;

-- RPC 4: recent touchpoints
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_recent_touchpoints()
RETURNS TABLE (
  touchpoint_id uuid,
  chain_name text,
  contact_name text,
  contact_role text,
  touchpoint_type text,
  occurred_at timestamptz,
  outcome text,
  summary text,
  next_action text,
  next_action_due timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    t.id,
    c.chain_name,
    c.contact_name,
    c.contact_role,
    t.touchpoint_type,
    t.occurred_at,
    t.outcome,
    t.summary,
    t.next_action,
    t.next_action_due
  FROM public.hospital_chain_cxo_touchpoints_r2283 t
  JOIN public.hospital_chain_cxo_contacts_r2283 c ON c.id = t.contact_id
  ORDER BY t.occurred_at DESC
  LIMIT 50;
END;
$$;

-- RPC 5: stale contacts (no touch > 30 days, weighted by ACV)
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_stale_contacts()
RETURNS TABLE (
  contact_id uuid,
  chain_name text,
  contact_name text,
  contact_role text,
  acv_rupees bigint,
  founder_priority boolean,
  last_touch_at timestamptz,
  days_silent int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.contact_name,
    c.contact_role,
    c.annual_contract_value_rupees,
    c.founder_priority,
    (SELECT MAX(t.occurred_at) FROM public.hospital_chain_cxo_touchpoints_r2283 t WHERE t.contact_id = c.id),
    (SELECT (EXTRACT(DAY FROM (now() - MAX(t.occurred_at))))::int FROM public.hospital_chain_cxo_touchpoints_r2283 t WHERE t.contact_id = c.id)
  FROM public.hospital_chain_cxo_contacts_r2283 c
  WHERE c.founder_priority
  ORDER BY c.annual_contract_value_rupees DESC;
END;
$$;

-- RPC 6: upcoming followups
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_upcoming_followups()
RETURNS TABLE (
  touchpoint_id uuid,
  chain_name text,
  contact_name text,
  next_action text,
  next_action_due timestamptz,
  days_until_due int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    t.id,
    c.chain_name,
    c.contact_name,
    t.next_action,
    t.next_action_due,
    (EXTRACT(DAY FROM (t.next_action_due - now())))::int
  FROM public.hospital_chain_cxo_touchpoints_r2283 t
  JOIN public.hospital_chain_cxo_contacts_r2283 c ON c.id = t.contact_id
  WHERE t.next_action IS NOT NULL AND t.next_action_due IS NOT NULL
  ORDER BY t.next_action_due ASC
  LIMIT 25;
END;
$$;

-- RPC 7: directory summary
CREATE OR REPLACE FUNCTION public.f_r2283_cxo_directory_summary()
RETURNS TABLE (
  total_contacts int,
  decision_makers int,
  founder_priority int,
  champions int,
  at_risk int,
  total_facilities int,
  total_acv_rupees bigint,
  champion_pct numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN QUERY
  SELECT
    (COUNT(*))::int,
    (COUNT(*) FILTER (WHERE c.decision_maker))::int,
    (COUNT(*) FILTER (WHERE c.founder_priority))::int,
    (COUNT(*) FILTER (WHERE c.relationship_status = 'champion'))::int,
    (COUNT(*) FILTER (WHERE c.relationship_status = 'at_risk'))::int,
    (SUM(c.total_facilities))::int,
    (SUM(c.annual_contract_value_rupees))::bigint,
    CASE WHEN COUNT(*) > 0 THEN ROUND((COUNT(*) FILTER (WHERE c.relationship_status = 'champion'))::numeric / COUNT(*)::numeric * 100, 1) ELSE 0 END
  FROM public.hospital_chain_cxo_contacts_r2283 c;
END;
$$;

REVOKE ALL ON FUNCTION public.f_r2283_cxo_priority_directory() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.f_r2283_cxo_tier_rollup() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.f_r2283_cxo_relationship_mix() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.f_r2283_cxo_recent_touchpoints() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.f_r2283_cxo_stale_contacts() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.f_r2283_cxo_upcoming_followups() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.f_r2283_cxo_directory_summary() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_priority_directory() TO authenticated;
GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_tier_rollup() TO authenticated;
GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_relationship_mix() TO authenticated;
GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_recent_touchpoints() TO authenticated;
GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_stale_contacts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_upcoming_followups() TO authenticated;
GRANT EXECUTE ON FUNCTION public.f_r2283_cxo_directory_summary() TO authenticated;

COMMIT;
