BEGIN;

-- =============================================================
-- r1590 — Founder Engineer Drop-off Recovery Flow
-- Engineers onboarded but never did first paid job.
-- Reach-out campaign + per-engineer recovery state + action queue.
-- =============================================================

CREATE TABLE IF NOT EXISTS public.founder_engineer_dropoff_recovery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_id uuid NOT NULL REFERENCES public.engineers(id) ON DELETE CASCADE,
  engineer_user_id uuid NOT NULL,
  detected_at timestamptz NOT NULL DEFAULT now(),
  days_since_onboarding integer NOT NULL DEFAULT 0,
  stage text NOT NULL DEFAULT 'detected'
    CHECK (stage IN ('detected','queued','contacted','responded','first_bid_made','recovered','lost')),
  next_action text,
  next_action_due_at timestamptz,
  last_touch_at timestamptz,
  touch_count integer NOT NULL DEFAULT 0,
  notes text,
  recovered_at timestamptz,
  lost_at timestamptz,
  lost_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (engineer_id)
);

CREATE INDEX IF NOT EXISTS idx_fedr_stage ON public.founder_engineer_dropoff_recovery (stage);
CREATE INDEX IF NOT EXISTS idx_fedr_next_due ON public.founder_engineer_dropoff_recovery (next_action_due_at);

ALTER TABLE public.founder_engineer_dropoff_recovery ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fedr_founder_all ON public.founder_engineer_dropoff_recovery;
CREATE POLICY fedr_founder_all ON public.founder_engineer_dropoff_recovery
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


CREATE TABLE IF NOT EXISTS public.founder_engineer_dropoff_touches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recovery_id uuid NOT NULL REFERENCES public.founder_engineer_dropoff_recovery(id) ON DELETE CASCADE,
  touched_at timestamptz NOT NULL DEFAULT now(),
  channel text NOT NULL CHECK (channel IN ('call','whatsapp','sms','email','in_person')),
  outcome text NOT NULL CHECK (outcome IN ('no_answer','interested','not_interested','reschedule','will_bid','dropped')),
  notes text,
  actor_user_id uuid,
  actor_email text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fedrt_recovery ON public.founder_engineer_dropoff_touches (recovery_id, touched_at DESC);

ALTER TABLE public.founder_engineer_dropoff_touches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS fedrt_founder_all ON public.founder_engineer_dropoff_touches;
CREATE POLICY fedrt_founder_all ON public.founder_engineer_dropoff_touches
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());


-- =============================================================
-- LOG HELPERS (VOLATILE SECDEF, founder-gated)
-- =============================================================

CREATE OR REPLACE FUNCTION public.log_founder_dropoff_detected(
  p_recovery_id uuid,
  p_engineer_id uuid,
  p_days integer
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'engineer_dropoff_detected',
    jsonb_build_object('recovery_id', p_recovery_id, 'engineer_id', p_engineer_id, 'days', p_days));
END$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dropoff_detected(uuid,uuid,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_dropoff_detected(uuid,uuid,integer) TO authenticated;


CREATE OR REPLACE FUNCTION public.log_founder_dropoff_touch_added(
  p_recovery_id uuid,
  p_channel text,
  p_outcome text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'engineer_dropoff_touch_added',
    jsonb_build_object('recovery_id', p_recovery_id, 'channel', p_channel, 'outcome', p_outcome));
END$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dropoff_touch_added(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_dropoff_touch_added(uuid,text,text) TO authenticated;


CREATE OR REPLACE FUNCTION public.log_founder_dropoff_stage_changed(
  p_recovery_id uuid,
  p_old_stage text,
  p_new_stage text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'engineer_dropoff_stage_changed',
    jsonb_build_object('recovery_id', p_recovery_id, 'old', p_old_stage, 'new', p_new_stage));
END$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dropoff_stage_changed(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_dropoff_stage_changed(uuid,text,text) TO authenticated;


CREATE OR REPLACE FUNCTION public.log_founder_dropoff_outcome(
  p_recovery_id uuid,
  p_outcome text,
  p_reason text
) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'engineer_dropoff_outcome',
    jsonb_build_object('recovery_id', p_recovery_id, 'outcome', p_outcome, 'reason', p_reason));
END$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dropoff_outcome(uuid,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.log_founder_dropoff_outcome(uuid,text,text) TO authenticated;


-- =============================================================
-- READ RPCs (STABLE SECDEF)
-- =============================================================

CREATE OR REPLACE FUNCTION public.founder_dropoff_kpis()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE v jsonb; v_total int; v_onboarded int; v_dropped int; v_queued int; v_contacted int;
  v_responded int; v_bid int; v_recovered int; v_lost int; v_avg_days numeric; v_due_today int;
  v_due_7 int; v_touches int; v_recover_rate numeric; v_p7 int; v_p30 int; v_p90 int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total FROM engineers;
  SELECT count(*) INTO v_onboarded FROM engineers WHERE created_at < now() - interval '7 days';
  SELECT count(*) INTO v_dropped FROM founder_engineer_dropoff_recovery;
  SELECT count(*) INTO v_queued FROM founder_engineer_dropoff_recovery WHERE stage='queued';
  SELECT count(*) INTO v_contacted FROM founder_engineer_dropoff_recovery WHERE stage='contacted';
  SELECT count(*) INTO v_responded FROM founder_engineer_dropoff_recovery WHERE stage='responded';
  SELECT count(*) INTO v_bid FROM founder_engineer_dropoff_recovery WHERE stage='first_bid_made';
  SELECT count(*) INTO v_recovered FROM founder_engineer_dropoff_recovery WHERE stage='recovered';
  SELECT count(*) INTO v_lost FROM founder_engineer_dropoff_recovery WHERE stage='lost';
  SELECT COALESCE(avg(days_since_onboarding),0) INTO v_avg_days FROM founder_engineer_dropoff_recovery;
  SELECT count(*) INTO v_due_today FROM founder_engineer_dropoff_recovery
    WHERE next_action_due_at <= now() + interval '1 day' AND stage NOT IN ('recovered','lost');
  SELECT count(*) INTO v_due_7 FROM founder_engineer_dropoff_recovery
    WHERE next_action_due_at <= now() + interval '7 days' AND stage NOT IN ('recovered','lost');
  SELECT count(*) INTO v_touches FROM founder_engineer_dropoff_touches;
  IF v_dropped > 0 THEN v_recover_rate := round((v_recovered::numeric / v_dropped) * 100, 1); ELSE v_recover_rate := 0; END IF;
  SELECT count(*) INTO v_p7 FROM founder_engineer_dropoff_recovery WHERE days_since_onboarding BETWEEN 7 AND 14;
  SELECT count(*) INTO v_p30 FROM founder_engineer_dropoff_recovery WHERE days_since_onboarding BETWEEN 15 AND 30;
  SELECT count(*) INTO v_p90 FROM founder_engineer_dropoff_recovery WHERE days_since_onboarding > 30;

  v := jsonb_build_object(
    'total_engineers', v_total,
    'onboarded_7d_plus', v_onboarded,
    'dropoff_count', v_dropped,
    'queued', v_queued,
    'contacted', v_contacted,
    'responded', v_responded,
    'first_bid_made', v_bid,
    'recovered', v_recovered,
    'lost', v_lost,
    'avg_days_dropoff', v_avg_days,
    'due_today', v_due_today,
    'due_7d', v_due_7,
    'total_touches', v_touches,
    'recovery_rate_pct', v_recover_rate,
    'bucket_7_14d', v_p7,
    'bucket_15_30d', v_p30,
    'bucket_30d_plus', v_p90
  );
  RETURN v;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_kpis() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_dropoff_queue()
RETURNS TABLE(
  id uuid, engineer_id uuid, engineer_name text, engineer_phone text,
  stage text, days_since_onboarding integer, next_action text,
  next_action_due_at timestamptz, last_touch_at timestamptz, touch_count integer,
  tier text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id, r.engineer_id,
           COALESCE(p.full_name,'(no name)') AS engineer_name,
           COALESCE(p.phone,'') AS engineer_phone,
           r.stage, r.days_since_onboarding, r.next_action,
           r.next_action_due_at, r.last_touch_at, r.touch_count,
           COALESCE(e.cached_highest_tier,'none') AS tier
    FROM founder_engineer_dropoff_recovery r
    JOIN engineers e ON e.id = r.engineer_id
    LEFT JOIN profiles p ON p.id = e.user_id
    WHERE r.stage NOT IN ('recovered','lost')
    ORDER BY r.next_action_due_at NULLS LAST, r.days_since_onboarding DESC
    LIMIT 200;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_queue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_queue() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_dropoff_recent_touches()
RETURNS TABLE(
  id uuid, recovery_id uuid, engineer_name text, touched_at timestamptz,
  channel text, outcome text, notes text, actor_email text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT t.id, t.recovery_id,
           COALESCE(p.full_name,'(no name)') AS engineer_name,
           t.touched_at, t.channel, t.outcome, t.notes, t.actor_email
    FROM founder_engineer_dropoff_touches t
    JOIN founder_engineer_dropoff_recovery r ON r.id = t.recovery_id
    JOIN engineers e ON e.id = r.engineer_id
    LEFT JOIN profiles p ON p.id = e.user_id
    ORDER BY t.touched_at DESC
    LIMIT 100;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_recent_touches() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_recent_touches() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_dropoff_stage_breakdown()
RETURNS TABLE(stage text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.stage, count(*)::bigint
    FROM founder_engineer_dropoff_recovery r
    GROUP BY r.stage
    ORDER BY count(*) DESC;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_stage_breakdown() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_stage_breakdown() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_dropoff_overdue()
RETURNS TABLE(
  id uuid, engineer_name text, stage text, next_action text,
  next_action_due_at timestamptz, overdue_days numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id,
           COALESCE(p.full_name,'(no name)') AS engineer_name,
           r.stage, r.next_action, r.next_action_due_at,
           ROUND(EXTRACT(EPOCH FROM (now() - r.next_action_due_at)) / 86400.0, 1) AS overdue_days
    FROM founder_engineer_dropoff_recovery r
    JOIN engineers e ON e.id = r.engineer_id
    LEFT JOIN profiles p ON p.id = e.user_id
    WHERE r.next_action_due_at < now()
      AND r.stage NOT IN ('recovered','lost')
    ORDER BY r.next_action_due_at ASC
    LIMIT 100;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_overdue() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_overdue() TO authenticated;


CREATE OR REPLACE FUNCTION public.founder_dropoff_recovered()
RETURNS TABLE(
  id uuid, engineer_name text, recovered_at timestamptz,
  days_to_recover numeric, touch_count integer
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT r.id,
           COALESCE(p.full_name,'(no name)') AS engineer_name,
           r.recovered_at,
           ROUND(EXTRACT(EPOCH FROM (r.recovered_at - r.detected_at)) / 86400.0, 1) AS days_to_recover,
           r.touch_count
    FROM founder_engineer_dropoff_recovery r
    JOIN engineers e ON e.id = r.engineer_id
    LEFT JOIN profiles p ON p.id = e.user_id
    WHERE r.stage = 'recovered'
    ORDER BY r.recovered_at DESC NULLS LAST
    LIMIT 50;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_recovered() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_recovered() TO authenticated;


-- =============================================================
-- WRITE RPC (VOLATILE SECDEF)
-- =============================================================

CREATE OR REPLACE FUNCTION public.founder_dropoff_record_touch(
  p_recovery_id uuid,
  p_channel text,
  p_outcome text,
  p_notes text
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_engineer_dropoff_touches
    (recovery_id, channel, outcome, notes, actor_user_id, actor_email)
  VALUES (p_recovery_id, p_channel, p_outcome, p_notes, auth.uid(), (auth.jwt()->>'email'))
  RETURNING id INTO v_id;

  UPDATE founder_engineer_dropoff_recovery
    SET touch_count = touch_count + 1,
        last_touch_at = now(),
        stage = CASE
          WHEN stage = 'queued' THEN 'contacted'
          WHEN stage = 'detected' THEN 'contacted'
          WHEN p_outcome = 'will_bid' THEN 'responded'
          WHEN p_outcome = 'dropped' THEN 'lost'
          ELSE stage
        END,
        updated_at = now()
  WHERE id = p_recovery_id;

  PERFORM log_founder_dropoff_touch_added(p_recovery_id, p_channel, p_outcome);
  RETURN v_id;
END$$;
REVOKE EXECUTE ON FUNCTION public.founder_dropoff_record_touch(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.founder_dropoff_record_touch(uuid,text,text,text) TO authenticated;

COMMIT;