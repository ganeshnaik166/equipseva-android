-- Round 2522: Engineer Customer Callback Tracker
-- Post-visit engineer-to-hospital callbacks with topic, success outcome, CSAT, upsell signal, and loose-end resolution.

CREATE TABLE IF NOT EXISTS public.engineer_post_visit_callbacks_r2522 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  engineer_user_id uuid REFERENCES public.engineers(id) ON DELETE SET NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  callback_at timestamptz NOT NULL DEFAULT now(),
  visit_external_ref text,
  topic_kind text NOT NULL DEFAULT 'satisfaction'
    CHECK (topic_kind IN ('satisfaction','follow_up','upsell','loose_end','feedback')),
  success_kind text NOT NULL DEFAULT 'connected'
    CHECK (success_kind IN ('connected','voicemail','no_answer','declined')),
  csat_score int NOT NULL DEFAULT 0 CHECK (csat_score BETWEEN 0 AND 10),
  upsell_opportunity_rupees bigint NOT NULL DEFAULT 0 CHECK (upsell_opportunity_rupees >= 0),
  loose_ends_count int NOT NULL DEFAULT 0 CHECK (loose_ends_count >= 0),
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','done','cancelled','no_answer')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.callback_loose_ends_resolution_r2522 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  callback_id uuid NOT NULL REFERENCES public.engineer_post_visit_callbacks_r2522(id) ON DELETE CASCADE,
  loose_end_kind text NOT NULL DEFAULT 'none'
    CHECK (loose_end_kind IN ('spare_pending','training_pending','repair_pending','billing_pending','none')),
  resolved_at timestamptz,
  resolution_summary text,
  owner_email text NOT NULL,
  status text NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.engineer_post_visit_callbacks_r2522 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.callback_loose_ends_resolution_r2522 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.engineer_post_visit_callbacks_r2522;
CREATE POLICY founder_all ON public.engineer_post_visit_callbacks_r2522
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.callback_loose_ends_resolution_r2522;
CREATE POLICY founder_all ON public.callback_loose_ends_resolution_r2522
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed callbacks + loose-end resolutions
DO $seed$
DECLARE
  c1 uuid; c2 uuid; c3 uuid; c4 uuid; c5 uuid;
BEGIN
  INSERT INTO public.engineer_post_visit_callbacks_r2522
    (callback_at, visit_external_ref, topic_kind, success_kind, csat_score, upsell_opportunity_rupees, loose_ends_count, owner_email, status, notes)
  VALUES ('2026-06-09 11:00:00+05:30'::timestamptz, 'VISIT-8821', 'satisfaction', 'connected', 9, 0, 0, 'ops@equipseva.in', 'done', 'Hospital admin praised quick turnaround on ventilator')
  RETURNING id INTO c1;

  INSERT INTO public.engineer_post_visit_callbacks_r2522
    (callback_at, visit_external_ref, topic_kind, success_kind, csat_score, upsell_opportunity_rupees, loose_ends_count, owner_email, status, notes)
  VALUES ('2026-06-11 15:30:00+05:30'::timestamptz, 'VISIT-8842', 'loose_end', 'connected', 6, 0, 2, 'ops@equipseva.in', 'done', 'Spare part still pending; training also requested')
  RETURNING id INTO c2;

  INSERT INTO public.engineer_post_visit_callbacks_r2522
    (callback_at, visit_external_ref, topic_kind, success_kind, csat_score, upsell_opportunity_rupees, loose_ends_count, owner_email, status, notes)
  VALUES ('2026-06-13 10:00:00+05:30'::timestamptz, 'VISIT-8855', 'upsell', 'connected', 8, 180000, 0, 'ops@equipseva.in', 'done', 'Hospital interested in AMC upgrade — Tier-2 to Tier-3')
  RETURNING id INTO c3;

  INSERT INTO public.engineer_post_visit_callbacks_r2522
    (callback_at, visit_external_ref, topic_kind, success_kind, csat_score, upsell_opportunity_rupees, loose_ends_count, owner_email, status, notes)
  VALUES ('2026-06-15 09:30:00+05:30'::timestamptz, 'VISIT-8867', 'follow_up', 'voicemail', 0, 0, 1, 'ops@equipseva.in', 'no_answer', 'Left voicemail — retry tomorrow morning')
  RETURNING id INTO c4;

  INSERT INTO public.engineer_post_visit_callbacks_r2522
    (callback_at, visit_external_ref, topic_kind, success_kind, csat_score, upsell_opportunity_rupees, loose_ends_count, owner_email, status, notes)
  VALUES ('2026-06-17 16:00:00+05:30'::timestamptz, 'VISIT-8880', 'feedback', 'connected', 10, 0, 1, 'ops@equipseva.in', 'done', 'Customer flagged billing query — escalated')
  RETURNING id INTO c5;

  -- Loose-end resolutions
  INSERT INTO public.callback_loose_ends_resolution_r2522
    (callback_id, loose_end_kind, resolved_at, resolution_summary, owner_email, status, notes)
  VALUES (c2, 'spare_pending', '2026-06-13 12:00:00+05:30'::timestamptz, 'Spare dispatched via Blue Dart; tracking sent', 'spares@equipseva.in', 'done', 'Confirmed delivery within 48h');

  INSERT INTO public.callback_loose_ends_resolution_r2522
    (callback_id, loose_end_kind, resolved_at, resolution_summary, owner_email, status, notes)
  VALUES (c2, 'training_pending', NULL, NULL, 'training@equipseva.in', 'in_progress', 'Scheduled remote training for next week');

  INSERT INTO public.callback_loose_ends_resolution_r2522
    (callback_id, loose_end_kind, resolved_at, resolution_summary, owner_email, status, notes)
  VALUES (c4, 'repair_pending', NULL, NULL, 'ops@equipseva.in', 'open', 'Awaiting hospital confirmation on revisit slot');

  INSERT INTO public.callback_loose_ends_resolution_r2522
    (callback_id, loose_end_kind, resolved_at, resolution_summary, owner_email, status, notes)
  VALUES (c5, 'billing_pending', '2026-06-18 11:00:00+05:30'::timestamptz, 'Billing team reissued invoice with corrected GST', 'finance@equipseva.in', 'done', 'Closed cleanly');
END $seed$;

-- RPCs

CREATE OR REPLACE FUNCTION public.list_callbacks_r2522()
RETURNS TABLE (
  id uuid,
  callback_at timestamptz,
  visit_external_ref text,
  topic_kind text,
  success_kind text,
  csat_score int,
  upsell_opportunity_rupees bigint,
  loose_ends_count int,
  owner_email text,
  status text,
  notes text,
  resolution_count bigint,
  resolved_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.callback_at, c.visit_external_ref, c.topic_kind, c.success_kind,
         c.csat_score, c.upsell_opportunity_rupees, c.loose_ends_count, c.owner_email, c.status, c.notes,
         COUNT(r.id) AS resolution_count,
         COUNT(r.id) FILTER (WHERE r.status = 'done') AS resolved_count
  FROM public.engineer_post_visit_callbacks_r2522 c
  LEFT JOIN public.callback_loose_ends_resolution_r2522 r ON r.callback_id = c.id
  GROUP BY c.id
  ORDER BY c.callback_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_callbacks_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_callbacks_r2522() TO authenticated;

CREATE OR REPLACE FUNCTION public.list_loose_ends_r2522()
RETURNS TABLE (
  id uuid,
  callback_id uuid,
  callback_at timestamptz,
  visit_external_ref text,
  loose_end_kind text,
  resolved_at timestamptz,
  resolution_summary text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.callback_id, c.callback_at, c.visit_external_ref,
         r.loose_end_kind, r.resolved_at, r.resolution_summary, r.owner_email, r.status, r.notes
  FROM public.callback_loose_ends_resolution_r2522 r
  JOIN public.engineer_post_visit_callbacks_r2522 c ON c.id = r.callback_id
  ORDER BY c.callback_at DESC, r.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_loose_ends_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_loose_ends_r2522() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_callback_engineers_r2522()
RETURNS TABLE (
  engineer_user_id uuid,
  owner_email text,
  callback_count bigint,
  connected_count bigint,
  avg_csat numeric,
  total_upsell_rupees bigint,
  total_loose_ends bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.engineer_user_id,
         c.owner_email,
         COUNT(*) AS callback_count,
         COUNT(*) FILTER (WHERE c.success_kind = 'connected') AS connected_count,
         ROUND(AVG(c.csat_score) FILTER (WHERE c.success_kind = 'connected'), 2) AS avg_csat,
         COALESCE(SUM(c.upsell_opportunity_rupees), 0) AS total_upsell_rupees,
         COALESCE(SUM(c.loose_ends_count), 0) AS total_loose_ends
  FROM public.engineer_post_visit_callbacks_r2522 c
  GROUP BY c.engineer_user_id, c.owner_email
  ORDER BY callback_count DESC, avg_csat DESC NULLS LAST;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_callback_engineers_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_callback_engineers_r2522() TO authenticated;

CREATE OR REPLACE FUNCTION public.success_kind_summary_r2522()
RETURNS TABLE (
  success_kind text,
  callback_count bigint,
  avg_csat numeric,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.engineer_post_visit_callbacks_r2522;
  RETURN QUERY
  SELECT c.success_kind,
         COUNT(*) AS callback_count,
         ROUND(AVG(c.csat_score) FILTER (WHERE c.success_kind = 'connected'), 2) AS avg_csat,
         ROUND(COUNT(*)::numeric * 100.0 / NULLIF(total, 0), 2) AS share_pct
  FROM public.engineer_post_visit_callbacks_r2522 c
  GROUP BY c.success_kind
  ORDER BY callback_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.success_kind_summary_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.success_kind_summary_r2522() TO authenticated;

CREATE OR REPLACE FUNCTION public.topic_kind_breakdown_r2522()
RETURNS TABLE (
  topic_kind text,
  callback_count bigint,
  avg_csat numeric,
  total_upsell_rupees bigint,
  total_loose_ends bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.topic_kind,
         COUNT(*) AS callback_count,
         ROUND(AVG(c.csat_score) FILTER (WHERE c.success_kind = 'connected'), 2) AS avg_csat,
         COALESCE(SUM(c.upsell_opportunity_rupees), 0) AS total_upsell_rupees,
         COALESCE(SUM(c.loose_ends_count), 0) AS total_loose_ends
  FROM public.engineer_post_visit_callbacks_r2522 c
  GROUP BY c.topic_kind
  ORDER BY callback_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.topic_kind_breakdown_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.topic_kind_breakdown_r2522() TO authenticated;

CREATE OR REPLACE FUNCTION public.csat_distribution_r2522()
RETURNS TABLE (
  csat_bucket text,
  callback_count bigint,
  share_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  total bigint;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT COUNT(*) INTO total FROM public.engineer_post_visit_callbacks_r2522 WHERE success_kind = 'connected';
  RETURN QUERY
  SELECT bucket AS csat_bucket,
         COUNT(*) AS callback_count,
         ROUND(COUNT(*)::numeric * 100.0 / NULLIF(total, 0), 2) AS share_pct
  FROM (
    SELECT CASE
             WHEN csat_score >= 9 THEN 'promoter (9-10)'
             WHEN csat_score >= 7 THEN 'passive (7-8)'
             WHEN csat_score >= 4 THEN 'detractor (4-6)'
             ELSE 'critical (0-3)'
           END AS bucket
    FROM public.engineer_post_visit_callbacks_r2522
    WHERE success_kind = 'connected'
  ) b
  GROUP BY bucket
  ORDER BY callback_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.csat_distribution_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.csat_distribution_r2522() TO authenticated;

CREATE OR REPLACE FUNCTION public.top_loose_end_focus_r2522()
RETURNS TABLE (
  loose_end_kind text,
  total_count bigint,
  open_count bigint,
  in_progress_count bigint,
  done_count bigint,
  dropped_count bigint,
  resolution_pct numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.loose_end_kind,
         COUNT(*) AS total_count,
         COUNT(*) FILTER (WHERE r.status = 'open') AS open_count,
         COUNT(*) FILTER (WHERE r.status = 'in_progress') AS in_progress_count,
         COUNT(*) FILTER (WHERE r.status = 'done') AS done_count,
         COUNT(*) FILTER (WHERE r.status = 'dropped') AS dropped_count,
         ROUND(
           COUNT(*) FILTER (WHERE r.status = 'done')::numeric * 100.0 / NULLIF(COUNT(*), 0),
           2
         ) AS resolution_pct
  FROM public.callback_loose_ends_resolution_r2522 r
  GROUP BY r.loose_end_kind
  ORDER BY total_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_loose_end_focus_r2522() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loose_end_focus_r2522() TO authenticated;
