-- Round 2525: Founder Personal Network Health Tracker
-- Contact × tier × last touch × help asked × help given × reciprocity score

CREATE TABLE IF NOT EXISTS public.founder_personal_contacts_r2525 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_name text NOT NULL,
  contact_email text NOT NULL,
  tier text NOT NULL CHECK (tier IN ('inner','orbit','extended','cold')),
  relationship_kind text NOT NULL CHECK (relationship_kind IN ('mentor','peer','investor','customer','advisor','family','friend')),
  last_touch_at timestamptz,
  help_asked_count int NOT NULL DEFAULT 0,
  help_given_count int NOT NULL DEFAULT 0,
  reciprocity_score numeric(6,2) NOT NULL DEFAULT 0,
  status text NOT NULL CHECK (status IN ('active','dormant','strained','lost')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.contact_touch_events_r2525 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id uuid NOT NULL REFERENCES public.founder_personal_contacts_r2525(id) ON DELETE CASCADE,
  touch_at timestamptz NOT NULL,
  touch_kind text NOT NULL CHECK (touch_kind IN ('call','email','meeting','event','social','note')),
  outcome text NOT NULL CHECK (outcome IN ('positive','neutral','negative','pending')),
  owner_email text NOT NULL,
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_personal_contacts_r2525 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_touch_events_r2525 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_personal_contacts_r2525;
CREATE POLICY founder_all ON public.founder_personal_contacts_r2525
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.contact_touch_events_r2525;
CREATE POLICY founder_all ON public.contact_touch_events_r2525
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed contacts
INSERT INTO public.founder_personal_contacts_r2525
  (contact_name, contact_email, tier, relationship_kind, last_touch_at, help_asked_count, help_given_count, reciprocity_score, status, notes)
VALUES
  ('Ravi Mehta', 'ravi.mehta@example.com', 'inner', 'mentor', now() - interval '5 days', 12, 18, 1.50, 'active', 'Quarterly board prep call'),
  ('Anita Rao', 'anita.rao@example.com', 'orbit', 'investor', now() - interval '32 days', 6, 4, 0.67, 'dormant', 'Series A lead — needs warm ping'),
  ('Priya Iyer', 'priya.iyer@example.com', 'inner', 'peer', now() - interval '2 days', 20, 22, 1.10, 'active', 'Founder peer group Bangalore'),
  ('Mohan Krishnan', 'mohan.k@example.com', 'extended', 'advisor', now() - interval '95 days', 3, 1, 0.33, 'strained', 'Last call ended badly on equity terms'),
  ('Sneha Pillai', 'sneha.pillai@example.com', 'cold', 'customer', now() - interval '14 days', 1, 5, 5.00, 'active', 'Hospital chain prospect — high give ratio');

-- Seed touch events
WITH c AS (SELECT id, contact_name FROM public.founder_personal_contacts_r2525)
INSERT INTO public.contact_touch_events_r2525
  (contact_id, touch_at, touch_kind, outcome, owner_email, follow_up_at, notes)
SELECT id, now() - interval '5 days', 'call', 'positive', 'ganesh@equipseva.com', now() + interval '90 days', 'Board topics aligned' FROM c WHERE contact_name='Ravi Mehta'
UNION ALL
SELECT id, now() - interval '32 days', 'email', 'pending', 'ganesh@equipseva.com', now() + interval '7 days', 'No reply yet — second nudge planned' FROM c WHERE contact_name='Anita Rao'
UNION ALL
SELECT id, now() - interval '2 days', 'meeting', 'positive', 'ganesh@equipseva.com', now() + interval '30 days', 'Peer group monthly sync' FROM c WHERE contact_name='Priya Iyer'
UNION ALL
SELECT id, now() - interval '95 days', 'call', 'negative', 'ganesh@equipseva.com', NULL, 'Strained — let it cool' FROM c WHERE contact_name='Mohan Krishnan'
UNION ALL
SELECT id, now() - interval '14 days', 'social', 'neutral', 'ganesh@equipseva.com', now() + interval '14 days', 'LinkedIn comment — schedule call' FROM c WHERE contact_name='Sneha Pillai';

-- RPCs
CREATE OR REPLACE FUNCTION public.list_contacts_r2525()
RETURNS TABLE(
  id uuid,
  contact_name text,
  contact_email text,
  tier text,
  relationship_kind text,
  last_touch_at timestamptz,
  help_asked_count int,
  help_given_count int,
  reciprocity_score numeric,
  status text,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.contact_name, c.contact_email, c.tier, c.relationship_kind,
           c.last_touch_at, c.help_asked_count, c.help_given_count, c.reciprocity_score,
           c.status, c.notes
    FROM public.founder_personal_contacts_r2525 c
    ORDER BY c.last_touch_at DESC NULLS LAST;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_contacts_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_contacts_r2525() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_touch_events_r2525()
RETURNS TABLE(
  id uuid,
  contact_name text,
  tier text,
  touch_at timestamptz,
  touch_kind text,
  outcome text,
  owner_email text,
  follow_up_at timestamptz,
  notes text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT e.id, c.contact_name, c.tier, e.touch_at, e.touch_kind, e.outcome,
           e.owner_email, e.follow_up_at, e.notes
    FROM public.contact_touch_events_r2525 e
    JOIN public.founder_personal_contacts_r2525 c ON c.id = e.contact_id
    ORDER BY e.touch_at DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.list_touch_events_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_touch_events_r2525() TO authenticated;

CREATE OR REPLACE FUNCTION public.dormant_focus_r2525()
RETURNS TABLE(
  id uuid,
  contact_name text,
  tier text,
  relationship_kind text,
  last_touch_at timestamptz,
  days_since_touch int,
  status text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.id, c.contact_name, c.tier, c.relationship_kind, c.last_touch_at,
           EXTRACT(DAY FROM (now() - c.last_touch_at))::int AS days_since_touch,
           c.status
    FROM public.founder_personal_contacts_r2525 c
    WHERE c.status IN ('dormant','strained')
       OR (c.last_touch_at IS NOT NULL AND c.last_touch_at < now() - interval '30 days')
    ORDER BY c.last_touch_at ASC NULLS FIRST;
END $$;
REVOKE EXECUTE ON FUNCTION public.dormant_focus_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.dormant_focus_r2525() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_reciprocity_contacts_r2525()
RETURNS TABLE(
  contact_name text,
  tier text,
  help_asked_count int,
  help_given_count int,
  reciprocity_score numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.contact_name, c.tier, c.help_asked_count, c.help_given_count, c.reciprocity_score
    FROM public.founder_personal_contacts_r2525 c
    ORDER BY c.reciprocity_score DESC NULLS LAST
    LIMIT 10;
END $$;
REVOKE EXECUTE ON FUNCTION public.top_reciprocity_contacts_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_reciprocity_contacts_r2525() TO authenticated;

CREATE OR REPLACE FUNCTION public.tier_distribution_r2525()
RETURNS TABLE(
  tier text,
  contact_count bigint,
  avg_reciprocity numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.tier, COUNT(*)::bigint AS contact_count,
           ROUND(AVG(c.reciprocity_score), 2) AS avg_reciprocity
    FROM public.founder_personal_contacts_r2525 c
    GROUP BY c.tier
    ORDER BY contact_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.tier_distribution_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tier_distribution_r2525() TO authenticated;

CREATE OR REPLACE FUNCTION public.monthly_touch_trend_r2525()
RETURNS TABLE(
  month_start timestamptz,
  touch_count bigint,
  positive_count bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT date_trunc('month', e.touch_at) AS month_start,
           COUNT(*)::bigint AS touch_count,
           COUNT(*) FILTER (WHERE e.outcome = 'positive')::bigint AS positive_count
    FROM public.contact_touch_events_r2525 e
    GROUP BY 1
    ORDER BY 1 DESC
    LIMIT 12;
END $$;
REVOKE EXECUTE ON FUNCTION public.monthly_touch_trend_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_touch_trend_r2525() TO authenticated;

CREATE OR REPLACE FUNCTION public.status_breakdown_r2525()
RETURNS TABLE(
  status text,
  contact_count bigint,
  total_help_asked bigint,
  total_help_given bigint
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT c.status, COUNT(*)::bigint AS contact_count,
           SUM(c.help_asked_count)::bigint AS total_help_asked,
           SUM(c.help_given_count)::bigint AS total_help_given
    FROM public.founder_personal_contacts_r2525 c
    GROUP BY c.status
    ORDER BY contact_count DESC;
END $$;
REVOKE EXECUTE ON FUNCTION public.status_breakdown_r2525() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_breakdown_r2525() TO authenticated;
