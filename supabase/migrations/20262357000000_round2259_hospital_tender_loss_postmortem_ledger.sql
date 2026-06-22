BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_tender_losses_r2259 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hospital_org_id uuid REFERENCES public.organizations(id) ON DELETE SET NULL,
  hospital_name text NOT NULL,
  tender_title text NOT NULL,
  tender_value_rupees bigint NOT NULL DEFAULT 0,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decision_at timestamptz NOT NULL DEFAULT now(),
  root_cause text NOT NULL CHECK (root_cause IN ('price','scope','relationship','incumbent','timing','other')),
  winning_competitor text,
  winning_bid_rupees bigint,
  our_bid_rupees bigint NOT NULL DEFAULT 0,
  price_gap_pct numeric(6,2) DEFAULT 0,
  recorded_by_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  recorded_by_email text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_tender_loss_lessons_r2259 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  loss_id uuid NOT NULL REFERENCES public.hospital_tender_losses_r2259(id) ON DELETE CASCADE,
  lesson_text text NOT NULL,
  next_time_action text NOT NULL,
  owner_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  owner_email text NOT NULL,
  applied boolean NOT NULL DEFAULT false,
  applied_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_tender_losses_r2259 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_tender_loss_lessons_r2259 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.hospital_tender_losses_r2259;
CREATE POLICY founder_all ON public.hospital_tender_losses_r2259
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.hospital_tender_loss_lessons_r2259;
CREATE POLICY founder_all ON public.hospital_tender_loss_lessons_r2259
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- Seed data
INSERT INTO public.hospital_tender_losses_r2259 (hospital_name, tender_title, tender_value_rupees, submitted_at, decision_at, root_cause, winning_competitor, winning_bid_rupees, our_bid_rupees, price_gap_pct, recorded_by_email)
VALUES
  ('Apollo Hyderabad', 'Annual CT Scanner AMC 2026', 4800000, now() - interval '40 days', now() - interval '14 days', 'price', 'MedServe', 4100000, 4750000, 13.50, 'founder@equipseva.com'),
  ('Yashoda Secunderabad', 'OR Equipment Service Contract', 3200000, now() - interval '52 days', now() - interval '20 days', 'incumbent', 'Siemens India', 3300000, 3050000, -8.20, 'founder@equipseva.com'),
  ('KIMS Kondapur', 'Dialysis Maintenance 3-yr', 6750000, now() - interval '30 days', now() - interval '8 days', 'scope', 'Fresenius Care', 6900000, 6200000, -10.10, 'founder@equipseva.com'),
  ('Sunshine Hospitals', 'Endoscopy Suite AMC', 2900000, now() - interval '60 days', now() - interval '25 days', 'relationship', 'Local Vendor X', 3050000, 2800000, -8.20, 'founder@equipseva.com'),
  ('Care Hospital Banjara', 'Ventilator Fleet 2-yr', 5400000, now() - interval '22 days', now() - interval '3 days', 'timing', 'Drager Service', 5550000, 5250000, -5.40, 'founder@equipseva.com');

INSERT INTO public.hospital_tender_loss_lessons_r2259 (loss_id, lesson_text, next_time_action, owner_email, applied, applied_at)
SELECT l.id,
       'Our base rate is 13% above market. We must rework labor cost.',
       'Build engineer-rotation pooling to drop site visit cost 15%.',
       'founder@equipseva.com', false, NULL
  FROM public.hospital_tender_losses_r2259 l WHERE l.hospital_name='Apollo Hyderabad' LIMIT 1;

INSERT INTO public.hospital_tender_loss_lessons_r2259 (loss_id, lesson_text, next_time_action, owner_email, applied, applied_at)
SELECT l.id,
       'Incumbent had 8-year relationship. We were lateral entrant.',
       'Add 6-month relationship-warm-up phase before bid.',
       'founder@equipseva.com', true, now() - interval '2 days'
  FROM public.hospital_tender_losses_r2259 l WHERE l.hospital_name='Yashoda Secunderabad' LIMIT 1;

INSERT INTO public.hospital_tender_loss_lessons_r2259 (loss_id, lesson_text, next_time_action, owner_email)
SELECT l.id,
       'Scope sheet missed dialyzer reuse audit. Hospital flagged it.',
       'Add dialysis-specific RFP checklist to tender template.',
       'founder@equipseva.com'
  FROM public.hospital_tender_losses_r2259 l WHERE l.hospital_name='KIMS Kondapur' LIMIT 1;

-- Helpers
CREATE OR REPLACE FUNCTION public.r2259_losses_overview()
RETURNS TABLE (
  loss_id uuid,
  hospital_name text,
  tender_title text,
  tender_value_rupees bigint,
  root_cause text,
  winning_competitor text,
  our_bid_rupees bigint,
  winning_bid_rupees bigint,
  price_gap_pct numeric,
  decision_at timestamptz,
  lessons_count int,
  applied_count int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.id, l.hospital_name, l.tender_title, l.tender_value_rupees, l.root_cause,
           l.winning_competitor, l.our_bid_rupees, l.winning_bid_rupees, l.price_gap_pct, l.decision_at,
           (SELECT COUNT(*) FROM public.hospital_tender_loss_lessons_r2259 le WHERE le.loss_id = l.id)::int,
           (SELECT COUNT(*) FROM public.hospital_tender_loss_lessons_r2259 le WHERE le.loss_id = l.id AND le.applied)::int
      FROM public.hospital_tender_losses_r2259 l
     ORDER BY l.decision_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2259_root_cause_breakdown()
RETURNS TABLE (
  root_cause text,
  losses_count int,
  total_value_rupees bigint,
  avg_price_gap_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT l.root_cause,
           (COUNT(*))::int,
           COALESCE(SUM(l.tender_value_rupees),0)::bigint,
           ROUND(AVG(l.price_gap_pct)::numeric, 2)
      FROM public.hospital_tender_losses_r2259 l
     GROUP BY l.root_cause
     ORDER BY losses_count DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2259_lessons_log()
RETURNS TABLE (
  lesson_id uuid,
  hospital_name text,
  tender_title text,
  lesson_text text,
  next_time_action text,
  owner_email text,
  applied boolean,
  applied_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT le.id, l.hospital_name, l.tender_title, le.lesson_text, le.next_time_action,
           le.owner_email, le.applied, le.applied_at, le.created_at
      FROM public.hospital_tender_loss_lessons_r2259 le
      JOIN public.hospital_tender_losses_r2259 l ON l.id = le.loss_id
     ORDER BY le.created_at DESC;
END $$;

CREATE OR REPLACE FUNCTION public.r2259_kpis()
RETURNS TABLE (
  total_losses int,
  total_value_rupees bigint,
  applied_lessons int,
  open_lessons int,
  avg_price_gap_pct numeric,
  losses_30d int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
    SELECT (SELECT COUNT(*) FROM public.hospital_tender_losses_r2259)::int,
           COALESCE((SELECT SUM(tender_value_rupees) FROM public.hospital_tender_losses_r2259),0)::bigint,
           (SELECT COUNT(*) FROM public.hospital_tender_loss_lessons_r2259 WHERE applied)::int,
           (SELECT COUNT(*) FROM public.hospital_tender_loss_lessons_r2259 WHERE NOT applied)::int,
           COALESCE((SELECT ROUND(AVG(price_gap_pct)::numeric,2) FROM public.hospital_tender_losses_r2259),0),
           (SELECT COUNT(*) FROM public.hospital_tender_losses_r2259 WHERE decision_at > now() - interval '30 days')::int;
END $$;

CREATE OR REPLACE FUNCTION public.r2259_log_loss(
  p_hospital_name text,
  p_tender_title text,
  p_tender_value_rupees bigint,
  p_root_cause text,
  p_winning_competitor text,
  p_winning_bid_rupees bigint,
  p_our_bid_rupees bigint
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text; v_gap numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  IF p_winning_bid_rupees IS NULL OR p_winning_bid_rupees = 0 THEN v_gap := 0;
  ELSE v_gap := ROUND(((p_our_bid_rupees - p_winning_bid_rupees)::numeric / p_winning_bid_rupees) * 100, 2);
  END IF;
  INSERT INTO public.hospital_tender_losses_r2259(
    hospital_name, tender_title, tender_value_rupees, root_cause,
    winning_competitor, winning_bid_rupees, our_bid_rupees, price_gap_pct, recorded_by_email
  ) VALUES (
    p_hospital_name, p_tender_title, p_tender_value_rupees, p_root_cause,
    p_winning_competitor, p_winning_bid_rupees, p_our_bid_rupees, v_gap, v_email
  ) RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.r2259_add_lesson(
  p_loss_id uuid,
  p_lesson_text text,
  p_next_time_action text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid; v_email text;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  v_email := auth.jwt()->>'email';
  INSERT INTO public.hospital_tender_loss_lessons_r2259(loss_id, lesson_text, next_time_action, owner_email)
  VALUES (p_loss_id, p_lesson_text, p_next_time_action, v_email)
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE FUNCTION public.r2259_mark_applied(p_lesson_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_tender_loss_lessons_r2259
     SET applied = true, applied_at = now()
   WHERE id = p_lesson_id;
END $$;

REVOKE ALL ON FUNCTION public.r2259_losses_overview() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2259_root_cause_breakdown() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2259_lessons_log() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2259_kpis() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2259_log_loss(text,text,bigint,text,text,bigint,bigint) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2259_add_lesson(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.r2259_mark_applied(uuid) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.r2259_losses_overview() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2259_root_cause_breakdown() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2259_lessons_log() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2259_kpis() TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2259_log_loss(text,text,bigint,text,text,bigint,bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2259_add_lesson(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.r2259_mark_applied(uuid) TO authenticated;

COMMIT;
