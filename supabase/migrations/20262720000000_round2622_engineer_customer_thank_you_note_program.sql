-- r2622 engineer-customer-thank-you-note-program

CREATE TABLE IF NOT EXISTS public.engineer_thank_you_notes_r2622 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id),
  hospital_user_id uuid REFERENCES public.profiles(id),
  sent_at timestamptz NOT NULL,
  note_kind text NOT NULL CHECK (note_kind IN ('handwritten','email','in_app','whatsapp')),
  trigger_event_kind text NOT NULL CHECK (trigger_event_kind IN ('first_visit','repair_done','amc_signed','festival','anniversary')),
  response_received boolean NOT NULL DEFAULT false,
  customer_response_md text,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','sent','responded','no_response')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.thank_you_followup_actions_r2622 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES public.engineer_thank_you_notes_r2622(id) ON DELETE CASCADE,
  action_at timestamptz NOT NULL,
  action_kind text NOT NULL CHECK (action_kind IN ('escalate_relationship','gift','site_lunch','intro_offer')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_thank_you_notes_r2622 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thank_you_followup_actions_r2622 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_thank_you_notes_r2622;
CREATE POLICY founder_all ON public.engineer_thank_you_notes_r2622 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.thank_you_followup_actions_r2622;
CREATE POLICY founder_all ON public.thank_you_followup_actions_r2622 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.engineer_thank_you_notes_r2622 (sent_at, note_kind, trigger_event_kind, response_received, customer_response_md, owner_email, status, notes) VALUES
  ('2026-06-01T10:00:00+05:30'::timestamptz, 'handwritten', 'first_visit', true, 'Very kind gesture, thank you', 'ops@equipseva.com', 'responded', 'Apollo radiology lead replied warmly'),
  ('2026-06-05T09:00:00+05:30'::timestamptz, 'email', 'repair_done', false, NULL, 'ops@equipseva.com', 'sent', 'CT scan repair followup'),
  ('2026-06-10T11:00:00+05:30'::timestamptz, 'whatsapp', 'amc_signed', true, 'Glad to be onboard', 'ce@equipseva.com', 'responded', 'New AMC signed at Yashoda'),
  ('2026-06-15T12:00:00+05:30'::timestamptz, 'in_app', 'festival', false, NULL, 'ce@equipseva.com', 'sent', 'Bonalu greeting'),
  ('2026-06-20T09:30:00+05:30'::timestamptz, 'handwritten', 'anniversary', false, NULL, 'ops@equipseva.com', 'planned', 'One year AMC anniversary card');

INSERT INTO public.thank_you_followup_actions_r2622 (note_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-12T10:00:00+05:30'::timestamptz, 'site_lunch', 'positive', 'ops@equipseva.com', 'done', 'Lunch at Apollo cafeteria'
FROM public.engineer_thank_you_notes_r2622 WHERE trigger_event_kind = 'first_visit' LIMIT 1;

INSERT INTO public.thank_you_followup_actions_r2622 (note_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-18T11:00:00+05:30'::timestamptz, 'gift', 'pending', 'ce@equipseva.com', 'open', 'Diwali sweet hamper planned'
FROM public.engineer_thank_you_notes_r2622 WHERE trigger_event_kind = 'amc_signed' LIMIT 1;

INSERT INTO public.thank_you_followup_actions_r2622 (note_id, action_at, action_kind, outcome, owner_email, status, notes)
SELECT id, '2026-06-22T09:00:00+05:30'::timestamptz, 'intro_offer', 'neutral', 'ops@equipseva.com', 'open', 'Offered referral discount'
FROM public.engineer_thank_you_notes_r2622 WHERE trigger_event_kind = 'repair_done' LIMIT 1;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_notes_r2622()
RETURNS TABLE(id uuid, sent_at timestamptz, note_kind text, trigger_event_kind text, response_received boolean, customer_response_md text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT n.id, n.sent_at, n.note_kind, n.trigger_event_kind, n.response_received, n.customer_response_md, n.owner_email, n.status, n.notes
  FROM public.engineer_thank_you_notes_r2622 n
  ORDER BY n.sent_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_notes_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_notes_r2622() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_followup_actions_r2622()
RETURNS TABLE(id uuid, action_at timestamptz, action_kind text, outcome text, owner_email text, status text, notes text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT a.id, a.action_at, a.action_kind, a.outcome, a.owner_email, a.status, a.notes
  FROM public.thank_you_followup_actions_r2622 a
  ORDER BY a.action_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_followup_actions_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_followup_actions_r2622() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_response_engineers_r2622()
RETURNS TABLE(owner_email text, sent_count bigint, response_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT n.owner_email, COUNT(*)::bigint AS sent_count, COUNT(*) FILTER (WHERE n.response_received)::bigint AS response_count
  FROM public.engineer_thank_you_notes_r2622 n
  GROUP BY n.owner_email
  ORDER BY response_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_response_engineers_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_response_engineers_r2622() TO authenticated;

CREATE OR REPLACE FUNCTION public.note_kind_distribution_r2622()
RETURNS TABLE(note_kind text, cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT n.note_kind, COUNT(*)::bigint
  FROM public.engineer_thank_you_notes_r2622 n
  GROUP BY n.note_kind
  ORDER BY COUNT(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.note_kind_distribution_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.note_kind_distribution_r2622() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_note_trend_r2622()
RETURNS TABLE(month_start timestamptz, cnt bigint, response_cnt bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT date_trunc('month', n.sent_at) AS month_start, COUNT(*)::bigint, COUNT(*) FILTER (WHERE n.response_received)::bigint
  FROM public.engineer_thank_you_notes_r2622 n
  GROUP BY date_trunc('month', n.sent_at)
  ORDER BY month_start DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_note_trend_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_note_trend_r2622() TO authenticated;

CREATE OR REPLACE FUNCTION public.response_rate_summary_r2622()
RETURNS TABLE(total_notes bigint, responded bigint, no_response bigint, planned bigint, sent_status bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY SELECT
    COUNT(*)::bigint,
    COUNT(*) FILTER (WHERE n.status = 'responded')::bigint,
    COUNT(*) FILTER (WHERE n.status = 'no_response')::bigint,
    COUNT(*) FILTER (WHERE n.status = 'planned')::bigint,
    COUNT(*) FILTER (WHERE n.status = 'sent')::bigint
  FROM public.engineer_thank_you_notes_r2622 n;
END $$;
REVOKE EXECUTE ON FUNCTION public.response_rate_summary_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.response_rate_summary_r2622() TO authenticated;

CREATE OR REPLACE FUNCTION public.owner_load_r2622()
RETURNS TABLE(owner_email text, open_notes bigint, open_actions bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  WITH n AS (
    SELECT owner_email, COUNT(*) FILTER (WHERE status IN ('planned','sent'))::bigint AS open_notes
    FROM public.engineer_thank_you_notes_r2622
    GROUP BY owner_email
  ),
  a AS (
    SELECT owner_email, COUNT(*) FILTER (WHERE status = 'open')::bigint AS open_actions
    FROM public.thank_you_followup_actions_r2622
    GROUP BY owner_email
  )
  SELECT COALESCE(n.owner_email, a.owner_email), COALESCE(n.open_notes, 0), COALESCE(a.open_actions, 0)
  FROM n FULL OUTER JOIN a ON n.owner_email = a.owner_email
  ORDER BY COALESCE(n.open_notes, 0) + COALESCE(a.open_actions, 0) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.owner_load_r2622() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_load_r2622() TO authenticated;
