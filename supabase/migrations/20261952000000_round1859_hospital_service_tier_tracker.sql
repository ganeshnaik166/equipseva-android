BEGIN;

-- Tables --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hospital_service_tiers_r1859 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('platinum','gold','silver','bronze','standard')),
  since_date date NOT NULL DEFAULT CURRENT_DATE,
  last_assessed_at timestamptz,
  sla_minutes int NOT NULL DEFAULT 240,
  discount_pct numeric(5,2) NOT NULL DEFAULT 0,
  founder_dedicated boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','upgrading','downgrading')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS hospital_service_tiers_r1859_hospital_uniq
  ON public.hospital_service_tiers_r1859(hospital_user_id);

CREATE TABLE IF NOT EXISTS public.hospital_service_tier_history_r1859 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  old_tier text,
  new_tier text NOT NULL,
  change_reason text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hospital_service_tier_history_r1859_hospital_idx
  ON public.hospital_service_tier_history_r1859(hospital_user_id, changed_at DESC);

-- RLS -----------------------------------------------------------------------
ALTER TABLE public.hospital_service_tiers_r1859 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_tier_history_r1859 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS hospital_service_tiers_r1859_founder ON public.hospital_service_tiers_r1859;
CREATE POLICY hospital_service_tiers_r1859_founder
  ON public.hospital_service_tiers_r1859
  FOR ALL
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS hospital_service_tier_history_r1859_founder ON public.hospital_service_tier_history_r1859;
CREATE POLICY hospital_service_tier_history_r1859_founder
  ON public.hospital_service_tier_history_r1859
  FOR ALL
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_tiers ---------------------------------------------------------
DROP FUNCTION IF EXISTS public.list_tiers_r1859();
CREATE OR REPLACE FUNCTION public.list_tiers_r1859()
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  tier text,
  since_date date,
  last_assessed_at timestamptz,
  sla_minutes int,
  discount_pct numeric,
  founder_dedicated boolean,
  status text,
  updated_at timestamptz
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
  SELECT t.id, t.hospital_user_id, p.email,
         t.tier, t.since_date, t.last_assessed_at,
         t.sla_minutes, t.discount_pct, t.founder_dedicated,
         t.status, t.updated_at
  FROM public.hospital_service_tiers_r1859 t
  LEFT JOIN public.profiles p ON p.id = t.hospital_user_id
  ORDER BY
    CASE t.tier
      WHEN 'platinum' THEN 1
      WHEN 'gold' THEN 2
      WHEN 'silver' THEN 3
      WHEN 'bronze' THEN 4
      ELSE 5
    END,
    t.updated_at DESC;
END;
$$;

-- RPC 2: set_tier -----------------------------------------------------------
DROP FUNCTION IF EXISTS public.set_tier_r1859(uuid, text, int, numeric, boolean, text, text);
CREATE OR REPLACE FUNCTION public.set_tier_r1859(
  p_hospital_user_id uuid,
  p_tier text,
  p_sla_minutes int DEFAULT 240,
  p_discount_pct numeric DEFAULT 0,
  p_founder_dedicated boolean DEFAULT false,
  p_status text DEFAULT 'current',
  p_reason text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_old_tier text;
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT tier INTO v_old_tier
  FROM public.hospital_service_tiers_r1859
  WHERE hospital_user_id = p_hospital_user_id;

  INSERT INTO public.hospital_service_tiers_r1859
    (hospital_user_id, tier, sla_minutes, discount_pct, founder_dedicated, status, last_assessed_at, updated_at)
  VALUES
    (p_hospital_user_id, p_tier, p_sla_minutes, p_discount_pct, p_founder_dedicated, p_status, now(), now())
  ON CONFLICT (hospital_user_id) DO UPDATE
    SET tier = EXCLUDED.tier,
        sla_minutes = EXCLUDED.sla_minutes,
        discount_pct = EXCLUDED.discount_pct,
        founder_dedicated = EXCLUDED.founder_dedicated,
        status = EXCLUDED.status,
        last_assessed_at = now(),
        updated_at = now()
  RETURNING id INTO v_id;

  IF v_old_tier IS DISTINCT FROM p_tier THEN
    INSERT INTO public.hospital_service_tier_history_r1859
      (hospital_user_id, old_tier, new_tier, change_reason)
    VALUES (p_hospital_user_id, v_old_tier, p_tier, p_reason);
  END IF;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'set_tier_r1859',
    jsonb_build_object(
      'hospital_user_id', p_hospital_user_id,
      'old_tier', v_old_tier,
      'new_tier', p_tier,
      'sla_minutes', p_sla_minutes,
      'discount_pct', p_discount_pct,
      'founder_dedicated', p_founder_dedicated,
      'status', p_status,
      'reason', p_reason
    )
  );

  RETURN v_id;
END;
$$;

-- RPC 3: list_history -------------------------------------------------------
DROP FUNCTION IF EXISTS public.list_history_r1859(int);
CREATE OR REPLACE FUNCTION public.list_history_r1859(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  old_tier text,
  new_tier text,
  change_reason text,
  changed_at timestamptz
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
  SELECT h.id, h.hospital_user_id, p.email,
         h.old_tier, h.new_tier, h.change_reason, h.changed_at
  FROM public.hospital_service_tier_history_r1859 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  ORDER BY h.changed_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 4: log_history --------------------------------------------------------
DROP FUNCTION IF EXISTS public.log_history_r1859(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.log_history_r1859(
  p_hospital_user_id uuid,
  p_old_tier text,
  p_new_tier text,
  p_reason text DEFAULT NULL
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

  INSERT INTO public.hospital_service_tier_history_r1859
    (hospital_user_id, old_tier, new_tier, change_reason)
  VALUES (p_hospital_user_id, p_old_tier, p_new_tier, p_reason)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_history_r1859',
    jsonb_build_object(
      'hospital_user_id', p_hospital_user_id,
      'old_tier', p_old_tier,
      'new_tier', p_new_tier,
      'reason', p_reason
    )
  );

  RETURN v_id;
END;
$$;

-- RPC 5: tier_distribution --------------------------------------------------
DROP FUNCTION IF EXISTS public.tier_distribution_r1859();
CREATE OR REPLACE FUNCTION public.tier_distribution_r1859()
RETURNS TABLE (
  tier text,
  hospital_count int,
  avg_sla_minutes numeric,
  avg_discount_pct numeric,
  founder_dedicated_count int
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
  SELECT t.tier,
         (COUNT(*))::int AS hospital_count,
         ROUND(AVG(t.sla_minutes)::numeric, 1) AS avg_sla_minutes,
         ROUND(AVG(t.discount_pct)::numeric, 2) AS avg_discount_pct,
         (COUNT(*) FILTER (WHERE t.founder_dedicated))::int AS founder_dedicated_count
  FROM public.hospital_service_tiers_r1859 t
  GROUP BY t.tier
  ORDER BY
    CASE t.tier
      WHEN 'platinum' THEN 1
      WHEN 'gold' THEN 2
      WHEN 'silver' THEN 3
      WHEN 'bronze' THEN 4
      ELSE 5
    END;
END;
$$;

-- RPC 6: recent_upgrades ----------------------------------------------------
DROP FUNCTION IF EXISTS public.recent_upgrades_r1859(int);
CREATE OR REPLACE FUNCTION public.recent_upgrades_r1859(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  old_tier text,
  new_tier text,
  change_reason text,
  changed_at timestamptz
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
  SELECT h.id, h.hospital_user_id, p.email,
         h.old_tier, h.new_tier, h.change_reason, h.changed_at
  FROM public.hospital_service_tier_history_r1859 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  WHERE
    CASE h.new_tier WHEN 'platinum' THEN 1 WHEN 'gold' THEN 2 WHEN 'silver' THEN 3 WHEN 'bronze' THEN 4 ELSE 5 END
    <
    CASE COALESCE(h.old_tier,'standard') WHEN 'platinum' THEN 1 WHEN 'gold' THEN 2 WHEN 'silver' THEN 3 WHEN 'bronze' THEN 4 ELSE 5 END
  ORDER BY h.changed_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- RPC 7: recent_downgrades --------------------------------------------------
DROP FUNCTION IF EXISTS public.recent_downgrades_r1859(int);
CREATE OR REPLACE FUNCTION public.recent_downgrades_r1859(p_limit int DEFAULT 20)
RETURNS TABLE (
  id uuid,
  hospital_user_id uuid,
  hospital_email text,
  old_tier text,
  new_tier text,
  change_reason text,
  changed_at timestamptz
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
  SELECT h.id, h.hospital_user_id, p.email,
         h.old_tier, h.new_tier, h.change_reason, h.changed_at
  FROM public.hospital_service_tier_history_r1859 h
  LEFT JOIN public.profiles p ON p.id = h.hospital_user_id
  WHERE
    CASE h.new_tier WHEN 'platinum' THEN 1 WHEN 'gold' THEN 2 WHEN 'silver' THEN 3 WHEN 'bronze' THEN 4 ELSE 5 END
    >
    CASE COALESCE(h.old_tier,'standard') WHEN 'platinum' THEN 1 WHEN 'gold' THEN 2 WHEN 'silver' THEN 3 WHEN 'bronze' THEN 4 ELSE 5 END
  ORDER BY h.changed_at DESC
  LIMIT GREATEST(p_limit, 1);
END;
$$;

-- Grants --------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.list_tiers_r1859() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_tier_r1859(uuid, text, int, numeric, boolean, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_history_r1859(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_history_r1859(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.tier_distribution_r1859() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_upgrades_r1859(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_downgrades_r1859(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_tiers_r1859() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_tier_r1859(uuid, text, int, numeric, boolean, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_history_r1859(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_history_r1859(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tier_distribution_r1859() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_upgrades_r1859(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_downgrades_r1859(int) TO authenticated;

COMMIT;