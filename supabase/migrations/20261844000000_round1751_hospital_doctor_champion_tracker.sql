BEGIN;

-- Tables
CREATE TABLE IF NOT EXISTS public.hospital_doctor_champions_r1751 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  doctor_name text NOT NULL,
  doctor_dept text,
  doctor_email text,
  doctor_phone text,
  champion_score int NOT NULL DEFAULT 5 CHECK (champion_score BETWEEN 1 AND 10),
  last_engaged_at timestamptz,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','lapsed','lost')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_doctor_engagements_r1751 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  champion_id uuid NOT NULL REFERENCES public.hospital_doctor_champions_r1751(id) ON DELETE CASCADE,
  engagement_type text NOT NULL CHECK (engagement_type IN ('call','visit','event','article','training')),
  engagement_at timestamptz NOT NULL DEFAULT now(),
  outcome text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hdc_r1751_hospital ON public.hospital_doctor_champions_r1751(hospital_user_id);
CREATE INDEX IF NOT EXISTS idx_hdc_r1751_status ON public.hospital_doctor_champions_r1751(status);
CREATE INDEX IF NOT EXISTS idx_hde_r1751_champion ON public.hospital_doctor_engagements_r1751(champion_id);
CREATE INDEX IF NOT EXISTS idx_hde_r1751_at ON public.hospital_doctor_engagements_r1751(engagement_at DESC);

-- RLS
ALTER TABLE public.hospital_doctor_champions_r1751 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_doctor_engagements_r1751 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hdc_r1751 ON public.hospital_doctor_champions_r1751;
CREATE POLICY founder_all_hdc_r1751 ON public.hospital_doctor_champions_r1751
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hde_r1751 ON public.hospital_doctor_engagements_r1751;
CREATE POLICY founder_all_hde_r1751 ON public.hospital_doctor_engagements_r1751
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_champions
CREATE OR REPLACE FUNCTION public.list_champions_r1751()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  doctor_name text,
  doctor_dept text,
  doctor_email text,
  doctor_phone text,
  champion_score int,
  last_engaged_at timestamptz,
  status text,
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
    SELECT c.id, c.hospital_user_id, p.email::text, c.doctor_name, c.doctor_dept,
           c.doctor_email, c.doctor_phone, c.champion_score, c.last_engaged_at,
           c.status, c.created_at
    FROM public.hospital_doctor_champions_r1751 c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    ORDER BY c.champion_score DESC, c.created_at DESC
    LIMIT 500;
END;
$$;

-- RPC 2: add_champion
CREATE OR REPLACE FUNCTION public.add_champion_r1751(
  p_hospital_user_id uuid,
  p_doctor_name text,
  p_doctor_dept text DEFAULT NULL,
  p_doctor_email text DEFAULT NULL,
  p_doctor_phone text DEFAULT NULL,
  p_champion_score int DEFAULT 5
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
  INSERT INTO public.hospital_doctor_champions_r1751
    (hospital_user_id, doctor_name, doctor_dept, doctor_email, doctor_phone, champion_score)
  VALUES (p_hospital_user_id, p_doctor_name, p_doctor_dept, p_doctor_email, p_doctor_phone, p_champion_score)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_champion_r1751',
          jsonb_build_object('id', v_id, 'hospital_user_id', p_hospital_user_id, 'doctor_name', p_doctor_name));
  RETURN v_id;
END;
$$;

-- RPC 3: list_engagements
CREATE OR REPLACE FUNCTION public.list_engagements_r1751(p_champion_id uuid DEFAULT NULL)
RETURNS TABLE (
  id uuid,
  champion_id uuid,
  doctor_name text,
  engagement_type text,
  engagement_at timestamptz,
  outcome text
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
    SELECT e.id, e.champion_id, c.doctor_name, e.engagement_type, e.engagement_at, e.outcome
    FROM public.hospital_doctor_engagements_r1751 e
    JOIN public.hospital_doctor_champions_r1751 c ON c.id = e.champion_id
    WHERE p_champion_id IS NULL OR e.champion_id = p_champion_id
    ORDER BY e.engagement_at DESC
    LIMIT 500;
END;
$$;

-- RPC 4: log_engagement
CREATE OR REPLACE FUNCTION public.log_engagement_r1751(
  p_champion_id uuid,
  p_engagement_type text,
  p_outcome text DEFAULT NULL
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
  INSERT INTO public.hospital_doctor_engagements_r1751 (champion_id, engagement_type, outcome)
  VALUES (p_champion_id, p_engagement_type, p_outcome)
  RETURNING id INTO v_id;

  UPDATE public.hospital_doctor_champions_r1751
    SET last_engaged_at = now(), updated_at = now()
    WHERE id = p_champion_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_engagement_r1751',
          jsonb_build_object('id', v_id, 'champion_id', p_champion_id, 'engagement_type', p_engagement_type));
  RETURN v_id;
END;
$$;

-- RPC 5: update_champion_status
CREATE OR REPLACE FUNCTION public.update_champion_status_r1751(
  p_champion_id uuid,
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
  IF p_status NOT IN ('active','lapsed','lost') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.hospital_doctor_champions_r1751
    SET status = p_status, updated_at = now()
    WHERE id = p_champion_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'update_champion_status_r1751',
          jsonb_build_object('id', p_champion_id, 'status', p_status));
END;
$$;

-- RPC 6: top_champions_per_hospital
CREATE OR REPLACE FUNCTION public.top_champions_per_hospital_r1751()
RETURNS TABLE (
  hospital_user_id uuid,
  hospital_email text,
  top_doctor text,
  top_score int,
  active_count int,
  total_count int
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
    WITH ranked AS (
      SELECT c.hospital_user_id, c.doctor_name, c.champion_score, c.status,
             ROW_NUMBER() OVER (PARTITION BY c.hospital_user_id ORDER BY c.champion_score DESC, c.created_at DESC) AS rn
      FROM public.hospital_doctor_champions_r1751 c
    )
    SELECT r.hospital_user_id,
           p.email::text,
           MAX(CASE WHEN r.rn = 1 THEN r.doctor_name END) AS top_doctor,
           MAX(CASE WHEN r.rn = 1 THEN r.champion_score END) AS top_score,
           (COUNT(*) FILTER (WHERE r.status = 'active'))::int AS active_count,
           (COUNT(*))::int AS total_count
    FROM ranked r
    LEFT JOIN public.profiles p ON p.id = r.hospital_user_id
    GROUP BY r.hospital_user_id, p.email
    ORDER BY top_score DESC NULLS LAST
    LIMIT 200;
END;
$$;

-- RPC 7: lapsed_champions
CREATE OR REPLACE FUNCTION public.lapsed_champions_r1751()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  doctor_name text,
  doctor_dept text,
  champion_score int,
  last_engaged_at timestamptz,
  days_since_engagement int,
  status text
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
    SELECT c.id, c.hospital_user_id, p.email::text, c.doctor_name, c.doctor_dept,
           c.champion_score, c.last_engaged_at,
           CASE WHEN c.last_engaged_at IS NULL THEN NULL
                ELSE EXTRACT(DAY FROM (now() - c.last_engaged_at))::int END AS days_since_engagement,
           c.status
    FROM public.hospital_doctor_champions_r1751 c
    LEFT JOIN public.profiles p ON p.id = c.hospital_user_id
    WHERE c.status = 'lapsed'
       OR (c.last_engaged_at IS NOT NULL AND c.last_engaged_at < now() - interval '60 days')
       OR c.last_engaged_at IS NULL
    ORDER BY c.last_engaged_at ASC NULLS FIRST
    LIMIT 200;
END;
$$;

-- GRANTS
REVOKE EXECUTE ON FUNCTION public.list_champions_r1751() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_champion_r1751(uuid, text, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_engagements_r1751(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_engagement_r1751(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_champion_status_r1751(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_champions_per_hospital_r1751() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.lapsed_champions_r1751() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_champions_r1751() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_champion_r1751(uuid, text, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_engagements_r1751(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_engagement_r1751(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_champion_status_r1751(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_champions_per_hospital_r1751() TO authenticated;
GRANT EXECUTE ON FUNCTION public.lapsed_champions_r1751() TO authenticated;

COMMIT;