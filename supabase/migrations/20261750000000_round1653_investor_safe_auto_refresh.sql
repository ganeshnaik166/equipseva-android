BEGIN;

-- ============================================================
-- r1653 — Investor SAFE Auto-Refresh
-- Track investor SAFE notes, expiry windows, re-papering queue
-- ============================================================

CREATE TABLE IF NOT EXISTS public.investor_safe_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_name text NOT NULL,
  investor_email text,
  principal_rupees bigint NOT NULL CHECK (principal_rupees > 0),
  valuation_cap_rupees bigint,
  discount_pct numeric(5,2),
  signed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','expiring','expired','repapered','converted','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_isn_status ON public.investor_safe_notes(status);
CREATE INDEX IF NOT EXISTS idx_isn_expires ON public.investor_safe_notes(expires_at);

ALTER TABLE public.investor_safe_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isn_founder_all ON public.investor_safe_notes;
CREATE POLICY isn_founder_all ON public.investor_safe_notes
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.investor_safe_refresh_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  safe_id uuid NOT NULL REFERENCES public.investor_safe_notes(id) ON DELETE CASCADE,
  action_type text NOT NULL CHECK (action_type IN ('extend','repaper','convert','cancel','contact')),
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('urgent','high','normal','low')),
  due_by timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','in_progress','done','dismissed')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_isrq_status ON public.investor_safe_refresh_queue(status);
CREATE INDEX IF NOT EXISTS idx_isrq_due ON public.investor_safe_refresh_queue(due_by);
CREATE INDEX IF NOT EXISTS idx_isrq_safe ON public.investor_safe_refresh_queue(safe_id);

ALTER TABLE public.investor_safe_refresh_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS isrq_founder_all ON public.investor_safe_refresh_queue;
CREATE POLICY isrq_founder_all ON public.investor_safe_refresh_queue
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- ============================================================
-- RPCs
-- ============================================================

CREATE OR REPLACE FUNCTION public.founder_safe_portfolio_summary()
RETURNS TABLE (
  total_safes int,
  active_safes int,
  expiring_safes int,
  expired_safes int,
  repapered_safes int,
  total_principal_rupees bigint,
  expiring_principal_rupees bigint,
  pending_queue_items int,
  urgent_queue_items int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    (SELECT (COUNT(*))::int FROM investor_safe_notes),
    (SELECT (COUNT(*) FILTER (WHERE status='active'))::int FROM investor_safe_notes),
    (SELECT (COUNT(*) FILTER (WHERE status='expiring' OR (status='active' AND expires_at < now() + interval '90 days')))::int FROM investor_safe_notes),
    (SELECT (COUNT(*) FILTER (WHERE status='expired'))::int FROM investor_safe_notes),
    (SELECT (COUNT(*) FILTER (WHERE status='repapered'))::int FROM investor_safe_notes),
    (SELECT COALESCE(SUM(principal_rupees),0)::bigint FROM investor_safe_notes WHERE status IN ('active','expiring')),
    (SELECT COALESCE(SUM(principal_rupees),0)::bigint FROM investor_safe_notes WHERE status='active' AND expires_at < now() + interval '90 days'),
    (SELECT (COUNT(*) FILTER (WHERE status='pending'))::int FROM investor_safe_refresh_queue),
    (SELECT (COUNT(*) FILTER (WHERE status='pending' AND priority='urgent'))::int FROM investor_safe_refresh_queue);
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_portfolio_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_portfolio_summary() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_safe_list_all(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid,
  investor_name text,
  investor_email text,
  principal_rupees bigint,
  valuation_cap_rupees bigint,
  discount_pct numeric,
  signed_at timestamptz,
  expires_at timestamptz,
  days_to_expiry int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.investor_email, s.principal_rupees, s.valuation_cap_rupees,
         s.discount_pct, s.signed_at, s.expires_at,
         EXTRACT(day FROM (s.expires_at - now()))::int AS days_to_expiry,
         s.status, s.notes
  FROM investor_safe_notes s
  ORDER BY s.expires_at ASC
  LIMIT GREATEST(p_limit, 1);
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_list_all(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_list_all(int) TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_safe_list_expiring(p_within_days int DEFAULT 90)
RETURNS TABLE (
  id uuid,
  investor_name text,
  principal_rupees bigint,
  expires_at timestamptz,
  days_to_expiry int,
  status text,
  has_pending_action boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT s.id, s.investor_name, s.principal_rupees, s.expires_at,
         EXTRACT(day FROM (s.expires_at - now()))::int,
         s.status,
         EXISTS(SELECT 1 FROM investor_safe_refresh_queue q WHERE q.safe_id=s.id AND q.status='pending')
  FROM investor_safe_notes s
  WHERE s.status IN ('active','expiring')
    AND s.expires_at < now() + (GREATEST(p_within_days,1) || ' days')::interval
  ORDER BY s.expires_at ASC;
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_list_expiring(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_list_expiring(int) TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_safe_action_queue(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid,
  safe_id uuid,
  investor_name text,
  action_type text,
  priority text,
  due_by timestamptz,
  hours_until_due int,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT q.id, q.safe_id, s.investor_name, q.action_type, q.priority, q.due_by,
         EXTRACT(epoch FROM (q.due_by - now()))::int / 3600,
         q.status, q.notes
  FROM investor_safe_refresh_queue q
  JOIN investor_safe_notes s ON s.id = q.safe_id
  WHERE q.status IN ('pending','in_progress')
  ORDER BY CASE q.priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END, q.due_by ASC
  LIMIT GREATEST(p_limit,1);
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_action_queue(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_action_queue(int) TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_safe_log_note(
  p_investor_name text,
  p_investor_email text,
  p_principal_rupees bigint,
  p_valuation_cap_rupees bigint,
  p_discount_pct numeric,
  p_expires_at timestamptz,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_safe_notes(investor_name, investor_email, principal_rupees, valuation_cap_rupees, discount_pct, expires_at, notes)
  VALUES (p_investor_name, p_investor_email, p_principal_rupees, p_valuation_cap_rupees, p_discount_pct, p_expires_at, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(action, actor_email, payload)
  VALUES ('safe.note.logged', (auth.jwt()->>'email'), jsonb_build_object('safe_id', v_id, 'investor', p_investor_name, 'principal', p_principal_rupees));
  RETURN v_id;
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_log_note(text,text,bigint,bigint,numeric,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_log_note(text,text,bigint,bigint,numeric,timestamptz,text) TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_safe_log_queue_action(
  p_safe_id uuid,
  p_action_type text,
  p_priority text,
  p_due_by timestamptz,
  p_notes text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO investor_safe_refresh_queue(safe_id, action_type, priority, due_by, notes)
  VALUES (p_safe_id, p_action_type, COALESCE(p_priority,'normal'), p_due_by, p_notes)
  RETURNING id INTO v_id;

  INSERT INTO founder_action_log(action, actor_email, payload)
  VALUES ('safe.queue.created', (auth.jwt()->>'email'), jsonb_build_object('queue_id', v_id, 'safe_id', p_safe_id, 'action_type', p_action_type, 'priority', p_priority));
  RETURN v_id;
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_log_queue_action(uuid,text,text,timestamptz,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_log_queue_action(uuid,text,text,timestamptz,text) TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_safe_log_resolve(
  p_queue_id uuid,
  p_outcome text,
  p_notes text
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_safe_refresh_queue
     SET status = CASE WHEN p_outcome='dismissed' THEN 'dismissed' ELSE 'done' END,
         completed_at = now(),
         notes = COALESCE(p_notes, notes)
   WHERE id = p_queue_id;

  INSERT INTO founder_action_log(action, actor_email, payload)
  VALUES ('safe.queue.resolved', (auth.jwt()->>'email'), jsonb_build_object('queue_id', p_queue_id, 'outcome', p_outcome));
  RETURN true;
END;$$;

REVOKE EXECUTE ON FUNCTION public.founder_safe_log_resolve(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_safe_log_resolve(uuid,text,text) TO authenticated;

COMMIT;