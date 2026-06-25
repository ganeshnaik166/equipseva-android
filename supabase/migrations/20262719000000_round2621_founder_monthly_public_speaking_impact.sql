-- Round 2621 — Founder Monthly Public Speaking Impact
-- Tracks founder speaking engagements + downstream lead attribution

CREATE TABLE IF NOT EXISTS public.founder_speaking_engagements_r2621 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  month_label text NOT NULL,
  event_label text NOT NULL,
  audience_size int NOT NULL DEFAULT 0,
  audience_kind text NOT NULL CHECK (audience_kind IN ('industry','investor','hospital_chain','conference','podcast','internal')),
  key_takeaway_md text,
  inbound_leads_count int NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','done','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.speaking_lead_attributions_r2621 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engagement_id uuid NOT NULL REFERENCES public.founder_speaking_engagements_r2621(id) ON DELETE CASCADE,
  lead_at timestamptz NOT NULL DEFAULT now(),
  lead_kind text NOT NULL CHECK (lead_kind IN ('MQL','SQL','opportunity','closed_won','closed_lost')),
  lead_value_rupees bigint NOT NULL DEFAULT 0,
  owner_email text,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.founder_speaking_engagements_r2621 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.speaking_lead_attributions_r2621 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.founder_speaking_engagements_r2621;
CREATE POLICY founder_all ON public.founder_speaking_engagements_r2621
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.speaking_lead_attributions_r2621;
CREATE POLICY founder_all ON public.speaking_lead_attributions_r2621
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seeds
INSERT INTO public.founder_speaking_engagements_r2621
  (month_label, event_label, audience_size, audience_kind, key_takeaway_md, inbound_leads_count, owner_email, status, notes)
VALUES
  ('2026-04', 'India MedTech Summit Keynote', 420, 'industry', 'Repair-first beats CapEx replacement for Tier-2 hospitals.', 18, 'founder@equipseva.in', 'done', 'Strong post-talk huddle of 22 hospital ops heads.'),
  ('2026-05', 'EquipSeva LP Update Call', 35, 'investor', 'Burn down 41 percent QoQ; AMC pool covers 60 days fixed cost.', 6, 'founder@equipseva.in', 'done', 'Two LPs requested data room access.'),
  ('2026-05', 'Apollo Group CTO Roundtable', 12, 'hospital_chain', 'Bonded parts cuts counterfeit risk to near zero.', 4, 'bd@equipseva.in', 'done', 'Apollo pilot scoping kicked off after.'),
  ('2026-06', 'TechSparks Bengaluru Fireside', 680, 'conference', 'Engineer marketplace + supervised training unlocks Tier-3 supply.', 11, 'founder@equipseva.in', 'planned', 'Stage 9; 22 min slot.'),
  ('2026-06', 'The Pragmatic Engineer Podcast', 0, 'podcast', 'Why we picked Hyderabad-first repair density over national MVP.', 0, 'founder@equipseva.in', 'planned', 'Recording slated for late June.');

INSERT INTO public.speaking_lead_attributions_r2621
  (engagement_id, lead_at, lead_kind, lead_value_rupees, owner_email, status, notes)
SELECT id, '2026-04-12 10:00:00'::timestamptz, 'opportunity', 1850000, 'bd@equipseva.in', 'open', 'Sunshine Hospitals 18-machine AMC.'
  FROM public.founder_speaking_engagements_r2621 WHERE event_label = 'India MedTech Summit Keynote' LIMIT 1;

INSERT INTO public.speaking_lead_attributions_r2621
  (engagement_id, lead_at, lead_kind, lead_value_rupees, owner_email, status, notes)
SELECT id, '2026-04-20 14:00:00'::timestamptz, 'closed_won', 940000, 'bd@equipseva.in', 'done', 'Yashoda 9-machine AMC inked.'
  FROM public.founder_speaking_engagements_r2621 WHERE event_label = 'India MedTech Summit Keynote' LIMIT 1;

INSERT INTO public.speaking_lead_attributions_r2621
  (engagement_id, lead_at, lead_kind, lead_value_rupees, owner_email, status, notes)
SELECT id, '2026-05-15 09:00:00'::timestamptz, 'SQL', 0, 'founder@equipseva.in', 'open', 'Lightspeed partner asked for follow-up deck.'
  FROM public.founder_speaking_engagements_r2621 WHERE event_label = 'EquipSeva LP Update Call' LIMIT 1;

INSERT INTO public.speaking_lead_attributions_r2621
  (engagement_id, lead_at, lead_kind, lead_value_rupees, owner_email, status, notes)
SELECT id, '2026-05-22 11:00:00'::timestamptz, 'opportunity', 4200000, 'bd@equipseva.in', 'open', 'Apollo Chennai 32-machine AMC scoping.'
  FROM public.founder_speaking_engagements_r2621 WHERE event_label = 'Apollo Group CTO Roundtable' LIMIT 1;

-- RPC 1: list_engagements_r2621
CREATE OR REPLACE FUNCTION public.list_engagements_r2621()
RETURNS TABLE (
  id uuid,
  month_label text,
  event_label text,
  audience_size int,
  audience_kind text,
  key_takeaway_md text,
  inbound_leads_count int,
  owner_email text,
  status text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.month_label, e.event_label, e.audience_size, e.audience_kind,
         e.key_takeaway_md, e.inbound_leads_count, e.owner_email, e.status, e.notes, e.created_at
  FROM public.founder_speaking_engagements_r2621 e
  ORDER BY e.month_label DESC, e.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_engagements_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_engagements_r2621() TO authenticated;

-- RPC 2: list_lead_attributions_r2621
CREATE OR REPLACE FUNCTION public.list_lead_attributions_r2621()
RETURNS TABLE (
  id uuid,
  engagement_id uuid,
  event_label text,
  lead_at timestamptz,
  lead_kind text,
  lead_value_rupees bigint,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.id, l.engagement_id, e.event_label, l.lead_at, l.lead_kind,
         l.lead_value_rupees, l.owner_email, l.status, l.notes
  FROM public.speaking_lead_attributions_r2621 l
  JOIN public.founder_speaking_engagements_r2621 e ON e.id = l.engagement_id
  ORDER BY l.lead_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_lead_attributions_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_lead_attributions_r2621() TO authenticated;

-- RPC 3: top_lead_engagements_r2621
CREATE OR REPLACE FUNCTION public.top_lead_engagements_r2621()
RETURNS TABLE (
  engagement_id uuid,
  event_label text,
  month_label text,
  total_leads bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.id, e.event_label, e.month_label,
         COUNT(l.id)::bigint AS total_leads,
         COALESCE(SUM(l.lead_value_rupees), 0)::bigint AS total_value_rupees
  FROM public.founder_speaking_engagements_r2621 e
  LEFT JOIN public.speaking_lead_attributions_r2621 l ON l.engagement_id = e.id
  GROUP BY e.id, e.event_label, e.month_label
  ORDER BY total_value_rupees DESC, total_leads DESC
  LIMIT 10;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_lead_engagements_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_lead_engagements_r2621() TO authenticated;

-- RPC 4: audience_kind_distribution_r2621
CREATE OR REPLACE FUNCTION public.audience_kind_distribution_r2621()
RETURNS TABLE (
  audience_kind text,
  engagement_count bigint,
  total_audience bigint,
  total_inbound_leads bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.audience_kind,
         COUNT(*)::bigint,
         COALESCE(SUM(e.audience_size), 0)::bigint,
         COALESCE(SUM(e.inbound_leads_count), 0)::bigint
  FROM public.founder_speaking_engagements_r2621 e
  GROUP BY e.audience_kind
  ORDER BY engagement_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.audience_kind_distribution_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.audience_kind_distribution_r2621() TO authenticated;

-- RPC 5: monthly_speaking_trend_r2621
CREATE OR REPLACE FUNCTION public.monthly_speaking_trend_r2621()
RETURNS TABLE (
  month_label text,
  engagement_count bigint,
  total_audience bigint,
  total_inbound_leads bigint,
  total_lead_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT e.month_label,
         COUNT(DISTINCT e.id)::bigint,
         COALESCE(SUM(e.audience_size), 0)::bigint,
         COALESCE(SUM(e.inbound_leads_count), 0)::bigint,
         COALESCE(SUM(l.lead_value_rupees), 0)::bigint
  FROM public.founder_speaking_engagements_r2621 e
  LEFT JOIN public.speaking_lead_attributions_r2621 l ON l.engagement_id = e.id
  GROUP BY e.month_label
  ORDER BY e.month_label DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_speaking_trend_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_speaking_trend_r2621() TO authenticated;

-- RPC 6: total_lead_value_summary_r2621
CREATE OR REPLACE FUNCTION public.total_lead_value_summary_r2621()
RETURNS TABLE (
  total_engagements bigint,
  total_leads bigint,
  total_value_rupees bigint,
  closed_won_value_rupees bigint,
  open_pipeline_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT
    (SELECT COUNT(*)::bigint FROM public.founder_speaking_engagements_r2621),
    (SELECT COUNT(*)::bigint FROM public.speaking_lead_attributions_r2621),
    COALESCE((SELECT SUM(lead_value_rupees)::bigint FROM public.speaking_lead_attributions_r2621), 0),
    COALESCE((SELECT SUM(lead_value_rupees)::bigint FROM public.speaking_lead_attributions_r2621 WHERE lead_kind = 'closed_won'), 0),
    COALESCE((SELECT SUM(lead_value_rupees)::bigint FROM public.speaking_lead_attributions_r2621 WHERE status = 'open' AND lead_kind IN ('MQL','SQL','opportunity')), 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.total_lead_value_summary_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.total_lead_value_summary_r2621() TO authenticated;

-- RPC 7: status_funnel_r2621
CREATE OR REPLACE FUNCTION public.status_funnel_r2621()
RETURNS TABLE (
  lead_kind text,
  open_count bigint,
  done_count bigint,
  dropped_count bigint,
  total_value_rupees bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT l.lead_kind,
         COUNT(*) FILTER (WHERE l.status = 'open')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'done')::bigint,
         COUNT(*) FILTER (WHERE l.status = 'dropped')::bigint,
         COALESCE(SUM(l.lead_value_rupees), 0)::bigint
  FROM public.speaking_lead_attributions_r2621 l
  GROUP BY l.lead_kind
  ORDER BY total_value_rupees DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.status_funnel_r2621() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.status_funnel_r2621() TO authenticated;
