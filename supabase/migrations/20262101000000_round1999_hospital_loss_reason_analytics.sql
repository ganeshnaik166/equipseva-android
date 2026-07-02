BEGIN;

-- Round 1999 — Hospital Loss Reason Analytics
-- Two tables capturing lost hospital deals, the reason, value lost, and lessons
-- learned. Seven SECDEF RPCs gated by public.is_founder() power the founder
-- console.

CREATE TABLE IF NOT EXISTS public.hospital_loss_reason_analytics_r1999 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  loss_reason text NOT NULL CHECK (loss_reason IN (
    'price',
    'engineer_quality',
    'parts_supply',
    'relationship',
    'competitor_won',
    'customer_changed_priorities',
    'founder_friction'
  )),
  loss_value_lost_rupees bigint NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active' CHECK (status IN (
    'active',
    'superseded',
    'lessons_learned',
    'disputed'
  )),
  captured_at timestamptz NOT NULL DEFAULT now(),
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hospital_loss_reason_analytics_r1999_hospital_idx
  ON public.hospital_loss_reason_analytics_r1999(hospital_id);
CREATE INDEX IF NOT EXISTS hospital_loss_reason_analytics_r1999_reason_idx
  ON public.hospital_loss_reason_analytics_r1999(loss_reason);
CREATE INDEX IF NOT EXISTS hospital_loss_reason_analytics_r1999_status_idx
  ON public.hospital_loss_reason_analytics_r1999(status);

CREATE TABLE IF NOT EXISTS public.hospital_loss_lesson_log_r1999 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loss_id uuid NOT NULL REFERENCES public.hospital_loss_reason_analytics_r1999(id) ON DELETE CASCADE,
  lesson_type text NOT NULL CHECK (lesson_type IN (
    'process_improved',
    'pricing_adjusted',
    'training_added',
    'account_recovered',
    'no_action'
  )),
  taken_at timestamptz NOT NULL DEFAULT now(),
  by_email text,
  notes_md text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS hospital_loss_lesson_log_r1999_loss_idx
  ON public.hospital_loss_lesson_log_r1999(loss_id);
CREATE INDEX IF NOT EXISTS hospital_loss_lesson_log_r1999_type_idx
  ON public.hospital_loss_lesson_log_r1999(lesson_type);

ALTER TABLE public.hospital_loss_reason_analytics_r1999 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_loss_lesson_log_r1999 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_hospital_loss_reason_r1999
  ON public.hospital_loss_reason_analytics_r1999;
CREATE POLICY founder_all_hospital_loss_reason_r1999
  ON public.hospital_loss_reason_analytics_r1999
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_hospital_loss_lesson_r1999
  ON public.hospital_loss_lesson_log_r1999;
CREATE POLICY founder_all_hospital_loss_lesson_r1999
  ON public.hospital_loss_lesson_log_r1999
  FOR ALL
  TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- RPC 1: list_losses
CREATE OR REPLACE FUNCTION public.list_losses_r1999()
RETURNS TABLE (
  id uuid,
  hospital_id uuid,
  hospital_email text,
  loss_reason text,
  loss_value_lost_rupees bigint,
  status text,
  captured_at timestamptz,
  notes_md text
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
    l.id,
    l.hospital_id,
    p.email AS hospital_email,
    l.loss_reason,
    l.loss_value_lost_rupees,
    l.status,
    l.captured_at,
    l.notes_md
  FROM public.hospital_loss_reason_analytics_r1999 l
  LEFT JOIN public.profiles p ON p.id = l.hospital_id
  ORDER BY l.captured_at DESC
  LIMIT 500;
END;
$$;

-- RPC 2: log_loss
CREATE OR REPLACE FUNCTION public.log_loss_r1999(
  p_hospital_id uuid,
  p_loss_reason text,
  p_loss_value_lost_rupees bigint,
  p_notes_md text
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
  INSERT INTO public.hospital_loss_reason_analytics_r1999(
    hospital_id, loss_reason, loss_value_lost_rupees, notes_md
  ) VALUES (
    p_hospital_id, p_loss_reason, COALESCE(p_loss_value_lost_rupees, 0), p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_loss_r1999',
    jsonb_build_object(
      'loss_id', v_id,
      'hospital_id', p_hospital_id,
      'loss_reason', p_loss_reason,
      'loss_value_lost_rupees', p_loss_value_lost_rupees
    )
  );
  RETURN v_id;
END;
$$;

-- RPC 3: list_lessons
CREATE OR REPLACE FUNCTION public.list_lessons_r1999(p_loss_id uuid)
RETURNS TABLE (
  id uuid,
  loss_id uuid,
  lesson_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
    ll.id,
    ll.loss_id,
    ll.lesson_type,
    ll.taken_at,
    ll.by_email,
    ll.notes_md
  FROM public.hospital_loss_lesson_log_r1999 ll
  WHERE p_loss_id IS NULL OR ll.loss_id = p_loss_id
  ORDER BY ll.taken_at DESC
  LIMIT 500;
END;
$$;

-- RPC 4: log_lesson
CREATE OR REPLACE FUNCTION public.log_lesson_r1999(
  p_loss_id uuid,
  p_lesson_type text,
  p_notes_md text
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
  INSERT INTO public.hospital_loss_lesson_log_r1999(
    loss_id, lesson_type, by_email, notes_md
  ) VALUES (
    p_loss_id, p_lesson_type, (auth.jwt()->>'email'), p_notes_md
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'log_lesson_r1999',
    jsonb_build_object(
      'lesson_id', v_id,
      'loss_id', p_loss_id,
      'lesson_type', p_lesson_type
    )
  );
  RETURN v_id;
END;
$$;

-- RPC 5: mark_status
CREATE OR REPLACE FUNCTION public.mark_status_r1999(
  p_loss_id uuid,
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
  UPDATE public.hospital_loss_reason_analytics_r1999
  SET status = p_status,
      updated_at = now()
  WHERE id = p_loss_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'mark_status_r1999',
    jsonb_build_object(
      'loss_id', p_loss_id,
      'status', p_status
    )
  );
END;
$$;

-- RPC 6: top_loss_reasons
CREATE OR REPLACE FUNCTION public.top_loss_reasons_r1999()
RETURNS TABLE (
  loss_reason text,
  loss_count bigint,
  total_value_lost_rupees bigint
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
    l.loss_reason,
    COUNT(*)::bigint AS loss_count,
    COALESCE(SUM(l.loss_value_lost_rupees), 0)::bigint AS total_value_lost_rupees
  FROM public.hospital_loss_reason_analytics_r1999 l
  GROUP BY l.loss_reason
  ORDER BY total_value_lost_rupees DESC;
END;
$$;

-- RPC 7: recent_lessons
CREATE OR REPLACE FUNCTION public.recent_lessons_r1999()
RETURNS TABLE (
  id uuid,
  loss_id uuid,
  lesson_type text,
  taken_at timestamptz,
  by_email text,
  notes_md text
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
    ll.id,
    ll.loss_id,
    ll.lesson_type,
    ll.taken_at,
    ll.by_email,
    ll.notes_md
  FROM public.hospital_loss_lesson_log_r1999 ll
  ORDER BY ll.taken_at DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_losses_r1999() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_loss_r1999(uuid, text, bigint, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_lessons_r1999(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_lesson_r1999(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_status_r1999(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_loss_reasons_r1999() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_lessons_r1999() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_losses_r1999() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_loss_r1999(uuid, text, bigint, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_lessons_r1999(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_lesson_r1999(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_status_r1999(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_loss_reasons_r1999() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_lessons_r1999() TO authenticated;

COMMIT;
