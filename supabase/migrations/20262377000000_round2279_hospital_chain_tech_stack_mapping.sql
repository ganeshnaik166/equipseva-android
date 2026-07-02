BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_chain_tech_stack_r2279 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  chain_tier text NOT NULL CHECK (chain_tier IN ('tier_1_national','tier_2_regional','tier_3_local','super_specialty','single_hospital')),
  hospital_count int NOT NULL CHECK (hospital_count >= 0),
  bed_count int NOT NULL CHECK (bed_count >= 0),
  ehr_vendor text NOT NULL,
  ehr_product text,
  ehr_version text,
  his_vendor text,
  his_product text,
  pacs_vendor text,
  lis_vendor text,
  asset_mgmt_vendor text,
  cmms_vendor text,
  cloud_or_onprem text NOT NULL CHECK (cloud_or_onprem IN ('cloud','onprem','hybrid','unknown')),
  integration_status text NOT NULL DEFAULT 'not_started' CHECK (integration_status IN ('not_started','scoping','pilot','live','blocked','deprecated')),
  integration_method text CHECK (integration_method IN ('hl7_v2','fhir_r4','api_rest','csv_sftp','manual','none')),
  estimated_arr_rupees bigint NOT NULL DEFAULT 0 CHECK (estimated_arr_rupees >= 0),
  primary_contact_email text,
  notes text,
  last_verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_chain_integration_milestones_r2279 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_id uuid NOT NULL REFERENCES public.hospital_chain_tech_stack_r2279(id) ON DELETE CASCADE,
  milestone_name text NOT NULL,
  milestone_type text NOT NULL CHECK (milestone_type IN ('kickoff','scoping','dev','uat','golive','expansion')),
  target_date date,
  completed_at timestamptz,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','in_progress','done','blocked','skipped')),
  blocker_note text,
  owner_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_chain_tech_stack_r2279 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_chain_integration_milestones_r2279 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_r2279_stack ON public.hospital_chain_tech_stack_r2279;
CREATE POLICY founder_all_r2279_stack ON public.hospital_chain_tech_stack_r2279
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_r2279_ms ON public.hospital_chain_integration_milestones_r2279;
CREATE POLICY founder_all_r2279_ms ON public.hospital_chain_integration_milestones_r2279
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_chains
CREATE OR REPLACE FUNCTION public.list_chain_tech_stacks_r2279()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  hospital_count int,
  bed_count int,
  ehr_vendor text,
  ehr_product text,
  his_vendor text,
  pacs_vendor text,
  cmms_vendor text,
  cloud_or_onprem text,
  integration_status text,
  integration_method text,
  estimated_arr_rupees bigint,
  primary_contact_email text,
  last_verified_at timestamptz,
  milestone_count int,
  done_milestone_count int
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.chain_tier,
    c.hospital_count,
    c.bed_count,
    c.ehr_vendor,
    c.ehr_product,
    c.his_vendor,
    c.pacs_vendor,
    c.cmms_vendor,
    c.cloud_or_onprem,
    c.integration_status,
    c.integration_method,
    c.estimated_arr_rupees,
    c.primary_contact_email,
    c.last_verified_at,
    (SELECT (COUNT(*))::int FROM public.hospital_chain_integration_milestones_r2279 m WHERE m.chain_id = c.id),
    (SELECT (COUNT(*) FILTER (WHERE m.status = 'done'))::int FROM public.hospital_chain_integration_milestones_r2279 m WHERE m.chain_id = c.id)
  FROM public.hospital_chain_tech_stack_r2279 c
  ORDER BY
    CASE c.integration_status WHEN 'live' THEN 0 WHEN 'pilot' THEN 1 WHEN 'scoping' THEN 2 WHEN 'not_started' THEN 3 WHEN 'blocked' THEN 4 ELSE 5 END,
    c.estimated_arr_rupees DESC,
    c.bed_count DESC
  LIMIT 500;
END;
$$;

-- RPC 2: upsert_chain
CREATE OR REPLACE FUNCTION public.upsert_chain_tech_stack_r2279(
  p_chain_name text,
  p_chain_tier text,
  p_hospital_count int,
  p_bed_count int,
  p_ehr_vendor text,
  p_ehr_product text,
  p_his_vendor text,
  p_cloud_or_onprem text,
  p_integration_status text,
  p_integration_method text,
  p_estimated_arr_rupees bigint,
  p_primary_contact_email text,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_chain_tech_stack_r2279(
    chain_name, chain_tier, hospital_count, bed_count,
    ehr_vendor, ehr_product, his_vendor, cloud_or_onprem,
    integration_status, integration_method, estimated_arr_rupees,
    primary_contact_email, notes, last_verified_at
  ) VALUES (
    p_chain_name, p_chain_tier, p_hospital_count, p_bed_count,
    p_ehr_vendor, p_ehr_product, p_his_vendor, p_cloud_or_onprem,
    p_integration_status, p_integration_method, p_estimated_arr_rupees,
    p_primary_contact_email, p_notes, now()
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2279_upsert_chain_tech_stack',
    jsonb_build_object('id', v_id, 'chain_name', p_chain_name, 'ehr_vendor', p_ehr_vendor));
  RETURN v_id;
END;
$$;

-- RPC 3: update_status
CREATE OR REPLACE FUNCTION public.update_chain_integration_status_r2279(
  p_chain_id uuid,
  p_integration_status text,
  p_integration_method text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_integration_status NOT IN ('not_started','scoping','pilot','live','blocked','deprecated') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.hospital_chain_tech_stack_r2279
    SET integration_status = p_integration_status,
        integration_method = COALESCE(p_integration_method, integration_method),
        last_verified_at = now(),
        updated_at = now()
    WHERE id = p_chain_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2279_update_chain_status',
    jsonb_build_object('chain_id', p_chain_id, 'status', p_integration_status));
END;
$$;

-- RPC 4: list_milestones
CREATE OR REPLACE FUNCTION public.list_chain_milestones_r2279(p_chain_id uuid)
RETURNS TABLE (
  id uuid,
  chain_id uuid,
  chain_name text,
  milestone_name text,
  milestone_type text,
  target_date date,
  completed_at timestamptz,
  status text,
  blocker_note text,
  owner_email text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT m.id, m.chain_id, c.chain_name, m.milestone_name, m.milestone_type,
         m.target_date, m.completed_at, m.status, m.blocker_note, m.owner_email
  FROM public.hospital_chain_integration_milestones_r2279 m
  JOIN public.hospital_chain_tech_stack_r2279 c ON c.id = m.chain_id
  WHERE (p_chain_id IS NULL OR m.chain_id = p_chain_id)
  ORDER BY
    CASE m.status WHEN 'blocked' THEN 0 WHEN 'in_progress' THEN 1 WHEN 'planned' THEN 2 WHEN 'done' THEN 3 ELSE 4 END,
    m.target_date NULLS LAST
  LIMIT 500;
END;
$$;

-- RPC 5: add_milestone
CREATE OR REPLACE FUNCTION public.add_chain_milestone_r2279(
  p_chain_id uuid,
  p_milestone_name text,
  p_milestone_type text,
  p_target_date date,
  p_owner_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_chain_integration_milestones_r2279(
    chain_id, milestone_name, milestone_type, target_date, owner_email
  ) VALUES (
    p_chain_id, p_milestone_name, p_milestone_type, p_target_date, p_owner_email
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'r2279_add_chain_milestone',
    jsonb_build_object('id', v_id, 'chain_id', p_chain_id, 'milestone_type', p_milestone_type));
  RETURN v_id;
END;
$$;

-- RPC 6: ehr_vendor_summary
CREATE OR REPLACE FUNCTION public.ehr_vendor_summary_r2279()
RETURNS TABLE (
  ehr_vendor text,
  chain_count int,
  total_hospitals int,
  total_beds int,
  live_count int,
  pilot_count int,
  blocked_count int,
  estimated_arr_rupees bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.ehr_vendor,
    (COUNT(*))::int,
    (SUM(c.hospital_count))::int,
    (SUM(c.bed_count))::int,
    (COUNT(*) FILTER (WHERE c.integration_status = 'live'))::int,
    (COUNT(*) FILTER (WHERE c.integration_status = 'pilot'))::int,
    (COUNT(*) FILTER (WHERE c.integration_status = 'blocked'))::int,
    (SUM(c.estimated_arr_rupees))::bigint
  FROM public.hospital_chain_tech_stack_r2279 c
  GROUP BY c.ehr_vendor
  ORDER BY SUM(c.estimated_arr_rupees) DESC, COUNT(*) DESC
  LIMIT 100;
END;
$$;

-- RPC 7: blocked_chains
CREATE OR REPLACE FUNCTION public.blocked_chain_integrations_r2279()
RETURNS TABLE (
  id uuid,
  chain_name text,
  chain_tier text,
  ehr_vendor text,
  integration_status text,
  integration_method text,
  estimated_arr_rupees bigint,
  open_blocker_count int,
  latest_blocker_note text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    c.id,
    c.chain_name,
    c.chain_tier,
    c.ehr_vendor,
    c.integration_status,
    c.integration_method,
    c.estimated_arr_rupees,
    (SELECT (COUNT(*) FILTER (WHERE m.status = 'blocked'))::int FROM public.hospital_chain_integration_milestones_r2279 m WHERE m.chain_id = c.id),
    (SELECT m.blocker_note FROM public.hospital_chain_integration_milestones_r2279 m WHERE m.chain_id = c.id AND m.status = 'blocked' ORDER BY m.updated_at DESC LIMIT 1)
  FROM public.hospital_chain_tech_stack_r2279 c
  WHERE c.integration_status = 'blocked'
     OR EXISTS (SELECT 1 FROM public.hospital_chain_integration_milestones_r2279 m WHERE m.chain_id = c.id AND m.status = 'blocked')
  ORDER BY c.estimated_arr_rupees DESC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_chain_tech_stacks_r2279() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.upsert_chain_tech_stack_r2279(text, text, int, int, text, text, text, text, text, text, bigint, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_chain_integration_status_r2279(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_chain_milestones_r2279(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_chain_milestone_r2279(uuid, text, text, date, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.ehr_vendor_summary_r2279() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.blocked_chain_integrations_r2279() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_chain_tech_stacks_r2279() TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_chain_tech_stack_r2279(text, text, int, int, text, text, text, text, text, text, bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_chain_integration_status_r2279(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_chain_milestones_r2279(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_chain_milestone_r2279(uuid, text, text, date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ehr_vendor_summary_r2279() TO authenticated;
GRANT EXECUTE ON FUNCTION public.blocked_chain_integrations_r2279() TO authenticated;

-- Seed sample chains (only if empty)
DO $seed$
DECLARE
  v_apollo uuid;
  v_fortis uuid;
  v_max uuid;
  v_manipal uuid;
  v_narayana uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.hospital_chain_tech_stack_r2279) THEN
    INSERT INTO public.hospital_chain_tech_stack_r2279(chain_name, chain_tier, hospital_count, bed_count, ehr_vendor, ehr_product, his_vendor, pacs_vendor, lis_vendor, cmms_vendor, cloud_or_onprem, integration_status, integration_method, estimated_arr_rupees, primary_contact_email, notes, last_verified_at)
    VALUES ('Apollo Hospitals', 'tier_1_national', 71, 10000, 'Cerner', 'Millennium', 'Akhil Systems', 'GE Centricity', 'SunQuest', 'Maximo', 'hybrid', 'pilot', 'hl7_v2', 8400000000, 'cio@apolloh.example', 'Pilot at Hyderabad campus; HL7 v2 ADT feed live', now())
    RETURNING id INTO v_apollo;

    INSERT INTO public.hospital_chain_tech_stack_r2279(chain_name, chain_tier, hospital_count, bed_count, ehr_vendor, ehr_product, his_vendor, pacs_vendor, lis_vendor, cmms_vendor, cloud_or_onprem, integration_status, integration_method, estimated_arr_rupees, primary_contact_email, notes, last_verified_at)
    VALUES ('Fortis Healthcare', 'tier_1_national', 36, 9000, 'Epic', 'Hyperspace', 'inhouse', 'Carestream', 'LabWare', 'eMaint', 'cloud', 'scoping', 'fhir_r4', 6200000000, 'it.head@fortis.example', 'FHIR R4 scoping; CMMS integration is the wedge', now())
    RETURNING id INTO v_fortis;

    INSERT INTO public.hospital_chain_tech_stack_r2279(chain_name, chain_tier, hospital_count, bed_count, ehr_vendor, ehr_product, his_vendor, pacs_vendor, lis_vendor, cmms_vendor, cloud_or_onprem, integration_status, integration_method, estimated_arr_rupees, primary_contact_email, notes, last_verified_at)
    VALUES ('Max Healthcare', 'tier_1_national', 17, 4000, 'Epic', 'Hyperspace', 'inhouse', 'Philips', 'SunQuest', 'none', 'cloud', 'live', 'fhir_r4', 4800000000, 'cio@maxhealthcare.example', 'Live since 2026-Q1; FHIR R4 production traffic', now())
    RETURNING id INTO v_max;

    INSERT INTO public.hospital_chain_tech_stack_r2279(chain_name, chain_tier, hospital_count, bed_count, ehr_vendor, ehr_product, his_vendor, pacs_vendor, lis_vendor, cmms_vendor, cloud_or_onprem, integration_status, integration_method, estimated_arr_rupees, primary_contact_email, notes, last_verified_at)
    VALUES ('Manipal Hospitals', 'tier_1_national', 29, 8300, 'Cerner', 'Millennium', 'Sanela', 'GE Centricity', 'SunQuest', 'Maximo', 'onprem', 'not_started', 'none', 5100000000, 'tech@manipal.example', 'No active wedge; Cerner stack matches Apollo template', now())
    RETURNING id INTO v_manipal;

    INSERT INTO public.hospital_chain_tech_stack_r2279(chain_name, chain_tier, hospital_count, bed_count, ehr_vendor, ehr_product, his_vendor, pacs_vendor, lis_vendor, cmms_vendor, cloud_or_onprem, integration_status, integration_method, estimated_arr_rupees, primary_contact_email, notes, last_verified_at)
    VALUES ('Narayana Health', 'super_specialty', 23, 5900, 'Meditech', 'Expanse', 'inhouse', 'Carestream', 'inhouse', 'none', 'hybrid', 'blocked', 'csv_sftp', 3700000000, 'cto@narayana.example', 'Blocked on IT-security review; CSV/SFTP fallback only', now())
    RETURNING id INTO v_narayana;

    INSERT INTO public.hospital_chain_integration_milestones_r2279(chain_id, milestone_name, milestone_type, target_date, status, owner_email)
    VALUES
      (v_apollo, 'ADT feed kickoff', 'kickoff', '2026-02-15', 'done', 'integrations@equipseva.com'),
      (v_apollo, 'Pilot at Hyderabad campus', 'golive', '2026-05-30', 'in_progress', 'integrations@equipseva.com'),
      (v_apollo, 'Roll out to 10 campuses', 'expansion', '2026-09-30', 'planned', 'integrations@equipseva.com'),
      (v_fortis, 'FHIR R4 scoping', 'scoping', '2026-07-15', 'in_progress', 'integrations@equipseva.com'),
      (v_max, 'Production go-live', 'golive', '2026-03-01', 'done', 'integrations@equipseva.com'),
      (v_narayana, 'IT-security review', 'scoping', '2026-04-15', 'blocked', 'integrations@equipseva.com');

    UPDATE public.hospital_chain_integration_milestones_r2279
      SET blocker_note = 'CISO wants on-prem agent + SOC2-Type-2 evidence; legal escalation in flight'
      WHERE chain_id = v_narayana AND status = 'blocked';
  END IF;
END
$seed$;

COMMIT;
