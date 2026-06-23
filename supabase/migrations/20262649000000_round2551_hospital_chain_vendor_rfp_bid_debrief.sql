-- Round r2551: hospital-chain-vendor-rfp-bid-debrief
-- Tables: chain_rfp_debriefs_r2551, debrief_playbook_updates_r2551
-- RPCs: 7

BEGIN;

CREATE TABLE IF NOT EXISTS public.chain_rfp_debriefs_r2551 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chain_name text NOT NULL,
  hospital_user_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  rfp_external_ref text,
  debriefed_at timestamptz NOT NULL DEFAULT now(),
  debrief_kind text NOT NULL CHECK (debrief_kind IN ('win_review','loss_review','postponed_review')),
  our_position text NOT NULL CHECK (our_position IN ('won','lost','no_decision','withdrawn')),
  competitor_winner text,
  competitor_strengths_md text,
  competitor_weaknesses_md text,
  playbook_update_md text,
  owner_email text,
  status text NOT NULL CHECK (status IN ('open','in_progress','closed','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.debrief_playbook_updates_r2551 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  debrief_id uuid NOT NULL REFERENCES public.chain_rfp_debriefs_r2551(id) ON DELETE CASCADE,
  update_kind text NOT NULL CHECK (update_kind IN ('pricing','positioning','proposal_template','team_assignments','objection_handling')),
  update_summary_md text,
  owner_email text,
  target_at timestamptz,
  status text NOT NULL CHECK (status IN ('open','in_progress','done','dropped')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.chain_rfp_debriefs_r2551 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debrief_playbook_updates_r2551 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all ON public.chain_rfp_debriefs_r2551;
CREATE POLICY founder_all ON public.chain_rfp_debriefs_r2551 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all ON public.debrief_playbook_updates_r2551;
CREATE POLICY founder_all ON public.debrief_playbook_updates_r2551 FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- Seed debriefs
INSERT INTO public.chain_rfp_debriefs_r2551
  (chain_name, rfp_external_ref, debriefed_at, debrief_kind, our_position, competitor_winner, competitor_strengths_md, competitor_weaknesses_md, playbook_update_md, owner_email, status, notes)
VALUES
  ('Apollo Hospitals', 'RFP-APL-2026-014', '2026-06-05 11:00:00'::timestamptz, 'loss_review', 'lost', 'Trivitron Healthcare', 'Bundled OEM service contracts; lower headline price 12% under us', 'Slow SLA (T+3 days); no engineer tier ladder; weak parts provenance', 'Lead with tier ladder SLAs + parts provenance proof; price match if multi-site', 'marketingtools@getphyllo.com', 'in_progress', 'Lost on price alone — value story was buried on slide 14'),
  ('Manipal Hospitals', 'RFP-MNP-2026-009', '2026-06-09 14:30:00'::timestamptz, 'win_review', 'won', NULL, NULL, NULL, 'Replicate Tier-2 engineer onboarding playbook for next chain pitch', 'marketingtools@getphyllo.com', 'closed', 'Won on 24h SLA guarantee — keep this front-and-centre'),
  ('Fortis Healthcare', 'RFP-FRT-2026-021', '2026-06-12 10:00:00'::timestamptz, 'loss_review', 'lost', 'Wipro GE Healthcare', 'Existing OEM relationship; integrated CMMS; preferred-vendor status', 'No multi-vendor support; locked-in spare parts; opaque pricing', 'Build CMMS export adaptor; pitch multi-vendor independence story', 'marketingtools@getphyllo.com', 'open', 'Procurement said decision was political — exec sponsor needed'),
  ('Max Healthcare', 'RFP-MAX-2026-017', '2026-06-15 16:00:00'::timestamptz, 'postponed_review', 'no_decision', NULL, NULL, NULL, 'Re-engage in Q3 with chain pilot case study', 'marketingtools@getphyllo.com', 'open', 'Capex frozen till Q3 budget cycle'),
  ('Narayana Health', 'RFP-NAR-2026-005', '2026-06-18 09:30:00'::timestamptz, 'loss_review', 'withdrawn', NULL, 'Their scope expanded mid-RFP to include radiology — out of our wheelhouse', 'Demanded uptime guarantees we could not honour', 'Decline RFPs with radiology scope until we partner with radiology vendor', 'marketingtools@getphyllo.com', 'closed', 'Right call to withdraw — protected reputation');

-- Seed playbook updates (link by chain_name lookup, single-row INSERT each)
INSERT INTO public.debrief_playbook_updates_r2551
  (debrief_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
SELECT d.id, 'pricing', 'Introduce multi-site bundle discount tiers (3+ sites = 8%, 5+ = 12%)', 'marketingtools@getphyllo.com', '2026-07-15 00:00:00'::timestamptz, 'in_progress', 'Pricing model draft v2'
FROM public.chain_rfp_debriefs_r2551 d WHERE d.chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.debrief_playbook_updates_r2551
  (debrief_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
SELECT d.id, 'positioning', 'Move parts provenance + tier ladder to slide 3 of deck', 'marketingtools@getphyllo.com', '2026-07-01 00:00:00'::timestamptz, 'done', 'Deck v2.3 shipped'
FROM public.chain_rfp_debriefs_r2551 d WHERE d.chain_name = 'Apollo Hospitals' LIMIT 1;

INSERT INTO public.debrief_playbook_updates_r2551
  (debrief_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
SELECT d.id, 'proposal_template', 'New Wins template w/ Manipal case study + 24h SLA hero-stat', 'marketingtools@getphyllo.com', '2026-07-05 00:00:00'::timestamptz, 'done', 'Template in Notion'
FROM public.chain_rfp_debriefs_r2551 d WHERE d.chain_name = 'Manipal Hospitals' LIMIT 1;

INSERT INTO public.debrief_playbook_updates_r2551
  (debrief_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
SELECT d.id, 'objection_handling', 'Build CMMS export adaptor demo for next 3 chain pitches', 'marketingtools@getphyllo.com', '2026-08-01 00:00:00'::timestamptz, 'open', 'Eng spike needed'
FROM public.chain_rfp_debriefs_r2551 d WHERE d.chain_name = 'Fortis Healthcare' LIMIT 1;

INSERT INTO public.debrief_playbook_updates_r2551
  (debrief_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
SELECT d.id, 'team_assignments', 'Assign senior AE to Fortis exec sponsor outreach', 'marketingtools@getphyllo.com', '2026-07-10 00:00:00'::timestamptz, 'in_progress', 'Need warm intro via investor'
FROM public.chain_rfp_debriefs_r2551 d WHERE d.chain_name = 'Fortis Healthcare' LIMIT 1;

INSERT INTO public.debrief_playbook_updates_r2551
  (debrief_id, update_kind, update_summary_md, owner_email, target_at, status, notes)
SELECT d.id, 'positioning', 'Q3 re-engage cadence: 1 LinkedIn + 1 email + 1 case study drop', 'marketingtools@getphyllo.com', '2026-09-01 00:00:00'::timestamptz, 'open', 'Cal reminder set'
FROM public.chain_rfp_debriefs_r2551 d WHERE d.chain_name = 'Max Healthcare' LIMIT 1;

-- RPC 1: list_debriefs_r2551
CREATE OR REPLACE FUNCTION public.list_debriefs_r2551()
RETURNS TABLE (
  id uuid,
  chain_name text,
  rfp_external_ref text,
  debriefed_at timestamptz,
  debrief_kind text,
  our_position text,
  competitor_winner text,
  competitor_strengths_md text,
  competitor_weaknesses_md text,
  playbook_update_md text,
  owner_email text,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.rfp_external_ref, d.debriefed_at, d.debrief_kind,
         d.our_position, d.competitor_winner, d.competitor_strengths_md,
         d.competitor_weaknesses_md, d.playbook_update_md, d.owner_email, d.status, d.notes
  FROM public.chain_rfp_debriefs_r2551 d
  ORDER BY d.debriefed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_debriefs_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_debriefs_r2551() TO authenticated;

-- RPC 2: list_playbook_updates_r2551
CREATE OR REPLACE FUNCTION public.list_playbook_updates_r2551()
RETURNS TABLE (
  id uuid,
  debrief_id uuid,
  chain_name text,
  update_kind text,
  update_summary_md text,
  owner_email text,
  target_at timestamptz,
  status text,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.id, u.debrief_id, d.chain_name, u.update_kind, u.update_summary_md,
         u.owner_email, u.target_at, u.status, u.notes
  FROM public.debrief_playbook_updates_r2551 u
  JOIN public.chain_rfp_debriefs_r2551 d ON d.id = u.debrief_id
  ORDER BY u.target_at ASC NULLS LAST, u.created_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_playbook_updates_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_playbook_updates_r2551() TO authenticated;

-- RPC 3: top_loss_debriefs_r2551
CREATE OR REPLACE FUNCTION public.top_loss_debriefs_r2551()
RETURNS TABLE (
  id uuid,
  chain_name text,
  debriefed_at timestamptz,
  competitor_winner text,
  competitor_strengths_md text,
  playbook_update_md text,
  status text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.id, d.chain_name, d.debriefed_at, d.competitor_winner,
         d.competitor_strengths_md, d.playbook_update_md, d.status
  FROM public.chain_rfp_debriefs_r2551 d
  WHERE d.our_position = 'lost'
  ORDER BY d.debriefed_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.top_loss_debriefs_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.top_loss_debriefs_r2551() TO authenticated;

-- RPC 4: kind_breakdown_r2551
CREATE OR REPLACE FUNCTION public.kind_breakdown_r2551()
RETURNS TABLE (
  debrief_kind text,
  debrief_count bigint,
  closed_count bigint,
  open_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.debrief_kind,
         COUNT(*)::bigint AS debrief_count,
         COUNT(*) FILTER (WHERE d.status = 'closed')::bigint AS closed_count,
         COUNT(*) FILTER (WHERE d.status = 'open')::bigint AS open_count
  FROM public.chain_rfp_debriefs_r2551 d
  GROUP BY d.debrief_kind
  ORDER BY debrief_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.kind_breakdown_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kind_breakdown_r2551() TO authenticated;

-- RPC 5: competitor_winner_summary_r2551
CREATE OR REPLACE FUNCTION public.competitor_winner_summary_r2551()
RETURNS TABLE (
  competitor_winner text,
  loss_count bigint,
  last_loss_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT d.competitor_winner,
         COUNT(*)::bigint AS loss_count,
         MAX(d.debriefed_at) AS last_loss_at
  FROM public.chain_rfp_debriefs_r2551 d
  WHERE d.our_position = 'lost' AND d.competitor_winner IS NOT NULL
  GROUP BY d.competitor_winner
  ORDER BY loss_count DESC, last_loss_at DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.competitor_winner_summary_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.competitor_winner_summary_r2551() TO authenticated;

-- RPC 6: monthly_debrief_trend_r2551
CREATE OR REPLACE FUNCTION public.monthly_debrief_trend_r2551()
RETURNS TABLE (
  month_start date,
  debriefs_logged bigint,
  wins bigint,
  losses bigint,
  no_decisions bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT date_trunc('month', d.debriefed_at)::date AS month_start,
         COUNT(*)::bigint AS debriefs_logged,
         COUNT(*) FILTER (WHERE d.our_position = 'won')::bigint AS wins,
         COUNT(*) FILTER (WHERE d.our_position = 'lost')::bigint AS losses,
         COUNT(*) FILTER (WHERE d.our_position = 'no_decision')::bigint AS no_decisions
  FROM public.chain_rfp_debriefs_r2551 d
  GROUP BY date_trunc('month', d.debriefed_at)
  ORDER BY month_start DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.monthly_debrief_trend_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.monthly_debrief_trend_r2551() TO authenticated;

-- RPC 7: update_status_funnel_r2551
CREATE OR REPLACE FUNCTION public.update_status_funnel_r2551()
RETURNS TABLE (
  status text,
  update_count bigint,
  done_count bigint,
  open_count bigint
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT u.status,
         COUNT(*)::bigint AS update_count,
         COUNT(*) FILTER (WHERE u.status = 'done')::bigint AS done_count,
         COUNT(*) FILTER (WHERE u.status = 'open')::bigint AS open_count
  FROM public.debrief_playbook_updates_r2551 u
  GROUP BY u.status
  ORDER BY update_count DESC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.update_status_funnel_r2551() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_status_funnel_r2551() TO authenticated;

