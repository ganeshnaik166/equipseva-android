BEGIN;

-- ============================================================
-- Round 1704 — Engineer Equipment Damage Log
-- ============================================================

CREATE TABLE IF NOT EXISTS public.engineer_equipment_damage_r1704 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  hospital_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  equipment_name text NOT NULL,
  damaged_at timestamptz NOT NULL DEFAULT now(),
  damage_severity text NOT NULL CHECK (damage_severity IN ('minor','moderate','severe','total_loss')),
  cost_estimate_rupees bigint NOT NULL DEFAULT 0 CHECK (cost_estimate_rupees >= 0),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewing','recovered','written_off')),
  recovered_amount_rupees bigint NOT NULL DEFAULT 0 CHECK (recovered_amount_rupees >= 0),
  recovered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eed_r1704_engineer ON public.engineer_equipment_damage_r1704(engineer_user_id);
CREATE INDEX IF NOT EXISTS idx_eed_r1704_status ON public.engineer_equipment_damage_r1704(status);
CREATE INDEX IF NOT EXISTS idx_eed_r1704_damaged_at ON public.engineer_equipment_damage_r1704(damaged_at DESC);

ALTER TABLE public.engineer_equipment_damage_r1704 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_eed_r1704 ON public.engineer_equipment_damage_r1704;
CREATE POLICY founder_all_eed_r1704 ON public.engineer_equipment_damage_r1704
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.engineer_damage_review_notes_r1704 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  damage_id uuid NOT NULL REFERENCES public.engineer_equipment_damage_r1704(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('engineer_fault','hospital_fault','wear_tear','no_fault')),
  decision_note text,
  decided_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_edrn_r1704_damage ON public.engineer_damage_review_notes_r1704(damage_id);
CREATE INDEX IF NOT EXISTS idx_edrn_r1704_decided ON public.engineer_damage_review_notes_r1704(decided_at DESC);

ALTER TABLE public.engineer_damage_review_notes_r1704 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_edrn_r1704 ON public.engineer_damage_review_notes_r1704;
CREATE POLICY founder_all_edrn_r1704 ON public.engineer_damage_review_notes_r1704
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================
-- RPC 1: list_damages
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_damages_r1704()
RETURNS TABLE (
  id uuid,
  engineer_user_id uuid,
  engineer_email text,
  hospital_id uuid,
  hospital_name text,
  equipment_name text,
  damaged_at timestamptz,
  damage_severity text,
  cost_estimate_rupees bigint,
  status text,
  recovered_amount_rupees bigint,
  recovered_at timestamptz,
  created_at timestamptz
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
  SELECT d.id,
         d.engineer_user_id,
         p.email::text,
         d.hospital_id,
         o.name::text,
         d.equipment_name,
         d.damaged_at,
         d.damage_severity,
         d.cost_estimate_rupees,
         d.status,
         d.recovered_amount_rupees,
         d.recovered_at,
         d.created_at
  FROM public.engineer_equipment_damage_r1704 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = d.hospital_id
  ORDER BY d.damaged_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_damages_r1704() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_damages_r1704() TO authenticated;


-- ============================================================
-- RPC 2: log_damage
-- ============================================================
CREATE OR REPLACE FUNCTION public.log_damage_r1704(
  p_engineer_user_id uuid,
  p_hospital_id uuid,
  p_equipment_name text,
  p_damaged_at timestamptz,
  p_damage_severity text,
  p_cost_estimate_rupees bigint
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  INSERT INTO public.engineer_equipment_damage_r1704
    (engineer_user_id, hospital_id, equipment_name, damaged_at, damage_severity, cost_estimate_rupees)
  VALUES
    (p_engineer_user_id, p_hospital_id, p_equipment_name, COALESCE(p_damaged_at, now()), p_damage_severity, COALESCE(p_cost_estimate_rupees, 0))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_damage_r1704',
    jsonb_build_object(
      'damage_id', v_id,
      'engineer_user_id', p_engineer_user_id,
      'equipment_name', p_equipment_name,
      'severity', p_damage_severity,
      'cost_estimate_rupees', p_cost_estimate_rupees
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.log_damage_r1704(uuid, uuid, text, timestamptz, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_damage_r1704(uuid, uuid, text, timestamptz, text, bigint) TO authenticated;


-- ============================================================
-- RPC 3: list_reviews
-- ============================================================
CREATE OR REPLACE FUNCTION public.list_reviews_r1704(p_damage_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  damage_id uuid,
  equipment_name text,
  reviewer_email text,
  decision text,
  decision_note text,
  decided_at timestamptz
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
  SELECT r.id,
         r.damage_id,
         d.equipment_name,
         r.reviewer_email,
         r.decision,
         r.decision_note,
         r.decided_at
  FROM public.engineer_damage_review_notes_r1704 r
  LEFT JOIN public.engineer_equipment_damage_r1704 d ON d.id = r.damage_id
  WHERE p_damage_id IS NULL OR r.damage_id = p_damage_id
  ORDER BY r.decided_at DESC
  LIMIT 500;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_reviews_r1704(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1704(uuid) TO authenticated;


-- ============================================================
-- RPC 4: record_review
-- ============================================================
CREATE OR REPLACE FUNCTION public.record_review_r1704(
  p_damage_id uuid,
  p_decision text,
  p_decision_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.engineer_damage_review_notes_r1704
    (damage_id, reviewer_email, decision, decision_note)
  VALUES
    (p_damage_id, COALESCE(v_email, 'unknown'), p_decision, p_decision_note)
  RETURNING id INTO v_id;

  UPDATE public.engineer_equipment_damage_r1704
  SET status = 'reviewing', updated_at = now()
  WHERE id = p_damage_id AND status = 'open';

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'record_review_r1704',
    jsonb_build_object(
      'review_id', v_id,
      'damage_id', p_damage_id,
      'decision', p_decision
    )
  );

  RETURN v_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.record_review_r1704(uuid, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_review_r1704(uuid, text, text) TO authenticated;


-- ============================================================
-- RPC 5: mark_recovered
-- ============================================================
CREATE OR REPLACE FUNCTION public.mark_recovered_r1704(
  p_damage_id uuid,
  p_recovered_amount_rupees bigint,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF p_status NOT IN ('recovered','written_off') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;

  UPDATE public.engineer_equipment_damage_r1704
  SET status = p_status,
      recovered_amount_rupees = COALESCE(p_recovered_amount_rupees, 0),
      recovered_at = now(),
      updated_at = now()
  WHERE id = p_damage_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_recovered_r1704',
    jsonb_build_object(
      'damage_id', p_damage_id,
      'status', p_status,
      'recovered_amount_rupees', p_recovered_amount_rupees
    )
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_recovered_r1704(uuid, bigint, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_recovered_r1704(uuid, bigint, text) TO authenticated;


-- ============================================================
-- RPC 6: damage_summary_per_engineer
-- ============================================================
CREATE OR REPLACE FUNCTION public.damage_summary_per_engineer_r1704()
RETURNS TABLE (
  engineer_user_id uuid,
  engineer_email text,
  incident_count int,
  open_count int,
  total_cost_rupees bigint,
  recovered_rupees bigint,
  outstanding_rupees bigint
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
  SELECT d.engineer_user_id,
         p.email::text,
         (COUNT(*))::int AS incident_count,
         (COUNT(*) FILTER (WHERE d.status IN ('open','reviewing')))::int AS open_count,
         COALESCE(SUM(d.cost_estimate_rupees), 0)::bigint AS total_cost_rupees,
         COALESCE(SUM(d.recovered_amount_rupees), 0)::bigint AS recovered_rupees,
         (COALESCE(SUM(d.cost_estimate_rupees), 0) - COALESCE(SUM(d.recovered_amount_rupees), 0))::bigint AS outstanding_rupees
  FROM public.engineer_equipment_damage_r1704 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  GROUP BY d.engineer_user_id, p.email
  ORDER BY outstanding_rupees DESC NULLS LAST
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.damage_summary_per_engineer_r1704() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.damage_summary_per_engineer_r1704() TO authenticated;


-- ============================================================
-- RPC 7: open_damage_queue
-- ============================================================
CREATE OR REPLACE FUNCTION public.open_damage_queue_r1704()
RETURNS TABLE (
  id uuid,
  engineer_email text,
  equipment_name text,
  hospital_name text,
  damage_severity text,
  cost_estimate_rupees bigint,
  status text,
  damaged_at timestamptz,
  age_hours int
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
  SELECT d.id,
         p.email::text,
         d.equipment_name,
         o.name::text,
         d.damage_severity,
         d.cost_estimate_rupees,
         d.status,
         d.damaged_at,
         (EXTRACT(EPOCH FROM (now() - d.damaged_at)) / 3600)::int AS age_hours
  FROM public.engineer_equipment_damage_r1704 d
  LEFT JOIN public.profiles p ON p.id = d.engineer_user_id
  LEFT JOIN public.organizations o ON o.id = d.hospital_id
  WHERE d.status IN ('open','reviewing')
  ORDER BY d.damaged_at ASC
  LIMIT 200;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.open_damage_queue_r1704() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.open_damage_queue_r1704() TO authenticated;

COMMIT;