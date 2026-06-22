BEGIN;

CREATE TABLE IF NOT EXISTS public.founder_risk_register_r1926 (
  id uuid primary key default gen_random_uuid(),
  risk_label text not null,
  risk_category text not null check (risk_category in ('market','regulatory','technical','financial','operational','reputational')),
  likelihood int not null check (likelihood between 1 and 5),
  impact int not null check (impact between 1 and 5),
  status text not null default 'open' check (status in ('open','mitigated','accepted','escalated','closed')),
  identified_at timestamptz not null default now(),
  last_reviewed_at timestamptz,
  owner_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

CREATE TABLE IF NOT EXISTS public.founder_risk_mitigation_log_r1926 (
  id uuid primary key default gen_random_uuid(),
  risk_id uuid not null references public.founder_risk_register_r1926(id) on delete cascade,
  mitigation_action_md text not null,
  action_status text not null default 'planned' check (action_status in ('planned','in_progress','completed','blocked')),
  taken_at timestamptz not null default now(),
  by_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

ALTER TABLE public.founder_risk_register_r1926 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_risk_mitigation_log_r1926 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_register_r1926 ON public.founder_risk_register_r1926;
CREATE POLICY founder_all_register_r1926 ON public.founder_risk_register_r1926
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_mitlog_r1926 ON public.founder_risk_mitigation_log_r1926;
CREATE POLICY founder_all_mitlog_r1926 ON public.founder_risk_mitigation_log_r1926
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- list_risks
CREATE OR REPLACE FUNCTION public.list_risks_r1926()
RETURNS TABLE(id uuid, risk_label text, risk_category text, likelihood int, impact int, score int, status text, owner_email text, identified_at timestamptz, last_reviewed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.risk_label, r.risk_category, r.likelihood, r.impact,
           (r.likelihood * r.impact)::int as score,
           r.status, r.owner_email, r.identified_at, r.last_reviewed_at
      FROM public.founder_risk_register_r1926 r
     ORDER BY (r.likelihood * r.impact) DESC, r.identified_at DESC
     LIMIT 500;
END;
$$;

-- log_risk
CREATE OR REPLACE FUNCTION public.log_risk_r1926(
  p_risk_label text,
  p_risk_category text,
  p_likelihood int,
  p_impact int,
  p_owner_email text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_risk_register_r1926(risk_label, risk_category, likelihood, impact, owner_email)
    VALUES (p_risk_label, p_risk_category, p_likelihood, p_impact, p_owner_email)
    RETURNING id INTO v_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_risk_r1926',
            jsonb_build_object('id', v_id, 'risk_label', p_risk_label, 'risk_category', p_risk_category, 'likelihood', p_likelihood, 'impact', p_impact, 'owner_email', p_owner_email));
  RETURN v_id;
END;
$$;

-- list_mitigations
CREATE OR REPLACE FUNCTION public.list_mitigations_r1926(p_risk_id uuid)
RETURNS TABLE(id uuid, risk_id uuid, mitigation_action_md text, action_status text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.risk_id, m.mitigation_action_md, m.action_status, m.taken_at, m.by_email
      FROM public.founder_risk_mitigation_log_r1926 m
     WHERE m.risk_id = p_risk_id
     ORDER BY m.taken_at DESC
     LIMIT 200;
END;
$$;

-- log_mitigation
CREATE OR REPLACE FUNCTION public.log_mitigation_r1926(
  p_risk_id uuid,
  p_mitigation_action_md text,
  p_action_status text DEFAULT 'planned',
  p_by_email text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_risk_mitigation_log_r1926(risk_id, mitigation_action_md, action_status, by_email)
    VALUES (p_risk_id, p_mitigation_action_md, p_action_status, p_by_email)
    RETURNING id INTO v_id;
  UPDATE public.founder_risk_register_r1926 SET last_reviewed_at = now(), updated_at = now() WHERE id = p_risk_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_mitigation_r1926',
            jsonb_build_object('id', v_id, 'risk_id', p_risk_id, 'action_status', p_action_status, 'by_email', p_by_email));
  RETURN v_id;
END;
$$;

-- mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1926(p_risk_id uuid, p_status text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.founder_risk_register_r1926
     SET status = p_status, last_reviewed_at = now(), updated_at = now()
   WHERE id = p_risk_id;
  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
    VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_status_r1926',
            jsonb_build_object('risk_id', p_risk_id, 'status', p_status));
END;
$$;

-- top_risks
CREATE OR REPLACE FUNCTION public.top_risks_r1926(p_limit int DEFAULT 10)
RETURNS TABLE(id uuid, risk_label text, risk_category text, likelihood int, impact int, score int, status text, owner_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.risk_label, r.risk_category, r.likelihood, r.impact,
           (r.likelihood * r.impact)::int as score, r.status, r.owner_email
      FROM public.founder_risk_register_r1926 r
     WHERE r.status IN ('open','escalated')
     ORDER BY (r.likelihood * r.impact) DESC, r.identified_at DESC
     LIMIT GREATEST(p_limit, 1);
END;
$$;

-- recent_mitigations
CREATE OR REPLACE FUNCTION public.recent_mitigations_r1926(p_limit int DEFAULT 50)
RETURNS TABLE(id uuid, risk_id uuid, risk_label text, mitigation_action_md text, action_status text, taken_at timestamptz, by_email text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT m.id, m.risk_id, r.risk_label, m.mitigation_action_md, m.action_status, m.taken_at, m.by_email
      FROM public.founder_risk_mitigation_log_r1926 m
      JOIN public.founder_risk_register_r1926 r ON r.id = m.risk_id
     ORDER BY m.taken_at DESC
     LIMIT GREATEST(p_limit, 1);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_risks_r1926() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_risk_r1926(text, text, int, int, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_mitigations_r1926(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_mitigation_r1926(uuid, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1926(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_risks_r1926(int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_mitigations_r1926(int) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_risks_r1926() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_risk_r1926(text, text, int, int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_mitigations_r1926(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_mitigation_r1926(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1926(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_risks_r1926(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_mitigations_r1926(int) TO authenticated;

COMMIT;