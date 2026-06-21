BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_round_negotiation_notes_r1773 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_id uuid NOT NULL,
  round_label text NOT NULL,
  negotiation_topic text NOT NULL CHECK (negotiation_topic IN ('valuation','board_seat','preferred_terms','pro_rata','protective_provisions','anti_dilution')),
  our_position text NOT NULL DEFAULT '',
  their_position text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','aligned','concerns','blocked')),
  resolution_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_round_negotiation_changes_r1773 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.investor_round_negotiation_notes_r1773(id) ON DELETE CASCADE,
  version int NOT NULL,
  change_at timestamptz NOT NULL DEFAULT now(),
  change_by_email text,
  change_summary text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.investor_round_negotiation_notes_r1773 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_round_negotiation_changes_r1773 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_notes_r1773 ON public.investor_round_negotiation_notes_r1773;
CREATE POLICY founder_all_notes_r1773 ON public.investor_round_negotiation_notes_r1773
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_changes_r1773 ON public.investor_round_negotiation_changes_r1773;
CREATE POLICY founder_all_changes_r1773 ON public.investor_round_negotiation_changes_r1773
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_notes
CREATE OR REPLACE FUNCTION public.list_notes_r1773()
RETURNS TABLE (
  id uuid,
  investor_id uuid,
  round_label text,
  negotiation_topic text,
  our_position text,
  their_position text,
  status text,
  resolution_at timestamptz,
  change_count int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.investor_id, n.round_label, n.negotiation_topic, n.our_position, n.their_position,
    n.status, n.resolution_at,
    (SELECT (COUNT(*))::int FROM public.investor_round_negotiation_changes_r1773 c WHERE c.note_id = n.id) AS change_count,
    n.created_at
  FROM public.investor_round_negotiation_notes_r1773 n
  ORDER BY n.created_at DESC;
END;
$$;

-- RPC 2: log_note
CREATE OR REPLACE FUNCTION public.log_note_r1773(
  p_investor_id uuid,
  p_round_label text,
  p_negotiation_topic text,
  p_our_position text,
  p_their_position text,
  p_status text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_round_negotiation_notes_r1773 (investor_id, round_label, negotiation_topic, our_position, their_position, status)
  VALUES (p_investor_id, p_round_label, p_negotiation_topic, p_our_position, p_their_position, COALESCE(p_status,'pending'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_note_r1773',
    jsonb_build_object('id', v_id, 'investor_id', p_investor_id, 'round_label', p_round_label, 'negotiation_topic', p_negotiation_topic, 'status', p_status));

  RETURN v_id;
END;
$$;

-- RPC 3: list_changes
CREATE OR REPLACE FUNCTION public.list_changes_r1773(p_note_id uuid)
RETURNS TABLE (
  id uuid,
  note_id uuid,
  version int,
  change_at timestamptz,
  change_by_email text,
  change_summary text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.note_id, c.version, c.change_at, c.change_by_email, c.change_summary
  FROM public.investor_round_negotiation_changes_r1773 c
  WHERE c.note_id = p_note_id
  ORDER BY c.version DESC;
END;
$$;

-- RPC 4: log_change
CREATE OR REPLACE FUNCTION public.log_change_r1773(
  p_note_id uuid,
  p_change_summary text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid; v_next_version int; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COALESCE(MAX(version), 0) + 1 INTO v_next_version
    FROM public.investor_round_negotiation_changes_r1773 WHERE note_id = p_note_id;
  v_email := (auth.jwt()->>'email');

  INSERT INTO public.investor_round_negotiation_changes_r1773 (note_id, version, change_by_email, change_summary)
  VALUES (p_note_id, v_next_version, v_email, COALESCE(p_change_summary,''))
  RETURNING id INTO v_id;

  UPDATE public.investor_round_negotiation_notes_r1773 SET updated_at = now() WHERE id = p_note_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_change_r1773',
    jsonb_build_object('id', v_id, 'note_id', p_note_id, 'version', v_next_version));

  RETURN v_id;
END;
$$;

-- RPC 5: mark_aligned
CREATE OR REPLACE FUNCTION public.mark_aligned_r1773(p_note_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_round_negotiation_notes_r1773
    SET status = 'aligned', resolution_at = now(), updated_at = now()
    WHERE id = p_note_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_aligned_r1773',
    jsonb_build_object('note_id', p_note_id));
END;
$$;

-- RPC 6: open_negotiations_summary
CREATE OR REPLACE FUNCTION public.open_negotiations_summary_r1773()
RETURNS TABLE (
  investor_id uuid,
  round_label text,
  total_topics int,
  pending_count int,
  aligned_count int,
  concerns_count int,
  blocked_count int
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.investor_id, n.round_label,
    (COUNT(*))::int AS total_topics,
    (COUNT(*) FILTER (WHERE n.status = 'pending'))::int AS pending_count,
    (COUNT(*) FILTER (WHERE n.status = 'aligned'))::int AS aligned_count,
    (COUNT(*) FILTER (WHERE n.status = 'concerns'))::int AS concerns_count,
    (COUNT(*) FILTER (WHERE n.status = 'blocked'))::int AS blocked_count
  FROM public.investor_round_negotiation_notes_r1773 n
  GROUP BY n.investor_id, n.round_label
  ORDER BY n.investor_id, n.round_label;
END;
$$;

-- RPC 7: recent_changes
CREATE OR REPLACE FUNCTION public.recent_changes_r1773()
RETURNS TABLE (
  id uuid,
  note_id uuid,
  investor_id uuid,
  round_label text,
  negotiation_topic text,
  version int,
  change_at timestamptz,
  change_by_email text,
  change_summary text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.note_id, n.investor_id, n.round_label, n.negotiation_topic,
    c.version, c.change_at, c.change_by_email, c.change_summary
  FROM public.investor_round_negotiation_changes_r1773 c
  JOIN public.investor_round_negotiation_notes_r1773 n ON n.id = c.note_id
  ORDER BY c.change_at DESC
  LIMIT 50;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_notes_r1773() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_note_r1773(uuid, text, text, text, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_changes_r1773(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_change_r1773(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_aligned_r1773(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_negotiations_summary_r1773() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.recent_changes_r1773() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_notes_r1773() TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_note_r1773(uuid, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_changes_r1773(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_change_r1773(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_aligned_r1773(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_negotiations_summary_r1773() TO authenticated;
GRANT EXECUTE ON FUNCTION public.recent_changes_r1773() TO authenticated;

COMMIT;