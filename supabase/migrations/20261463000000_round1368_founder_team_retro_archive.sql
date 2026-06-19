BEGIN;
-- r1368 — Founder team retro archive.
--
-- Retros are the only forcing function that turns lived friction into
-- written, accountable change. Without an archive, the company keeps
-- re-learning the same lessons every quarter — engineers re-discover the
-- same incident classes, product re-debates the same launch tradeoffs,
-- ops re-builds the same playbooks. The archive ends that loop.
--
-- One row per retro:
--   * weekly engineering · biweekly product · monthly ops · quarterly founder
--   * incident retros + launch retros + ad-hoc
--   * structured slots: well / poorly / actions / themes / blockers / decisions
--   * cadence telemetry: days_since_last_retro, top format, attendance avg
--
-- The KPIs answer: are we actually doing retros? at what cadence? which
-- format do we keep reaching for? are attendees showing up? when did we
-- last close the loop?

-- ============================================================================
-- Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.founder_team_retros (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retro_label           text NOT NULL UNIQUE,
  retro_kind            text NOT NULL
                          CHECK (retro_kind IN ('weekly_engineering','biweekly_product','monthly_ops',
                                                'quarterly_founder','incident_retro','launch_retro','ad_hoc')),
  held_at               timestamptz NOT NULL,
  attendees_count       int NOT NULL DEFAULT 0,
  format                text
                          CHECK (format IN ('start_stop_continue','plus_delta','5_whys',
                                            'what_went_well_what_didnt','postmortem','open_format')),
  what_went_well        text,
  what_went_poorly      text,
  action_items_text     text,
  surfacing_themes      text,
  blockers_raised       text,
  decisions_committed   text,
  facilitator_user_id   uuid REFERENCES auth.users(id),
  notes_url             text,
  created_at            timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.founder_team_retros IS
  'Team retro archive — one row per retro across all cadences. Ends the loop of re-learning the same lessons every quarter.';

CREATE INDEX IF NOT EXISTS idx_founder_team_retros_held_at ON public.founder_team_retros (held_at DESC);
CREATE INDEX IF NOT EXISTS idx_founder_team_retros_kind    ON public.founder_team_retros (retro_kind);
CREATE INDEX IF NOT EXISTS idx_founder_team_retros_format  ON public.founder_team_retros (format);

ALTER TABLE public.founder_team_retros ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS founder_team_retros_no_direct ON public.founder_team_retros;
CREATE POLICY founder_team_retros_no_direct ON public.founder_team_retros FOR ALL USING (false);
REVOKE ALL ON TABLE public.founder_team_retros FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- Write-layer RPC
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_team_retro_record(text, text, timestamptz, int, text, text, text, text, text, text, text, uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_team_retro_record(
  p_retro_label         text,
  p_retro_kind          text,
  p_held_at             timestamptz,
  p_attendees_count     int     DEFAULT 0,
  p_format              text    DEFAULT NULL,
  p_what_went_well      text    DEFAULT NULL,
  p_what_went_poorly    text    DEFAULT NULL,
  p_action_items_text   text    DEFAULT NULL,
  p_surfacing_themes    text    DEFAULT NULL,
  p_blockers_raised     text    DEFAULT NULL,
  p_decisions_committed text    DEFAULT NULL,
  p_facilitator_user_id uuid    DEFAULT NULL,
  p_notes_url           text    DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  IF p_retro_label IS NULL OR length(trim(p_retro_label)) = 0 THEN
    RAISE EXCEPTION 'retro_label required' USING ERRCODE = '22023';
  END IF;
  IF p_retro_kind NOT IN ('weekly_engineering','biweekly_product','monthly_ops','quarterly_founder','incident_retro','launch_retro','ad_hoc') THEN
    RAISE EXCEPTION 'invalid retro_kind %', p_retro_kind USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.founder_team_retros
    (retro_label, retro_kind, held_at, attendees_count, format,
     what_went_well, what_went_poorly, action_items_text,
     surfacing_themes, blockers_raised, decisions_committed,
     facilitator_user_id, notes_url)
  VALUES
    (p_retro_label, p_retro_kind, p_held_at, coalesce(p_attendees_count, 0), p_format,
     p_what_went_well, p_what_went_poorly, p_action_items_text,
     p_surfacing_themes, p_blockers_raised, p_decisions_committed,
     p_facilitator_user_id, p_notes_url)
  ON CONFLICT (retro_label) DO UPDATE
    SET retro_kind          = EXCLUDED.retro_kind,
        held_at             = EXCLUDED.held_at,
        attendees_count     = EXCLUDED.attendees_count,
        format              = coalesce(EXCLUDED.format,              public.founder_team_retros.format),
        what_went_well      = coalesce(EXCLUDED.what_went_well,      public.founder_team_retros.what_went_well),
        what_went_poorly    = coalesce(EXCLUDED.what_went_poorly,    public.founder_team_retros.what_went_poorly),
        action_items_text   = coalesce(EXCLUDED.action_items_text,   public.founder_team_retros.action_items_text),
        surfacing_themes    = coalesce(EXCLUDED.surfacing_themes,    public.founder_team_retros.surfacing_themes),
        blockers_raised     = coalesce(EXCLUDED.blockers_raised,     public.founder_team_retros.blockers_raised),
        decisions_committed = coalesce(EXCLUDED.decisions_committed, public.founder_team_retros.decisions_committed),
        facilitator_user_id = coalesce(EXCLUDED.facilitator_user_id, public.founder_team_retros.facilitator_user_id),
        notes_url           = coalesce(EXCLUDED.notes_url,           public.founder_team_retros.notes_url)
    RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_team_retro_record(text, text, timestamptz, int, text, text, text, text, text, text, text, uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_team_retro_record(text, text, timestamptz, int, text, text, text, text, text, text, text, uuid, text) TO authenticated;

-- ============================================================================
-- Read-layer RPCs
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_team_retro_archive_summary();
CREATE OR REPLACE FUNCTION public.founder_team_retro_archive_summary()
RETURNS TABLE (
  total_retros               bigint,
  retros_30d                 bigint,
  retros_90d                 bigint,
  retros_ytd                 bigint,
  weekly_engineering_count   bigint,
  biweekly_product_count     bigint,
  monthly_ops_count          bigint,
  quarterly_founder_count    bigint,
  incident_retro_count       bigint,
  latest_retro_at            timestamptz,
  days_since_last_retro      int,
  top_format                 text,
  top_format_count           bigint,
  avg_attendees              numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE held_at >= now() - interval '30 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE held_at >= now() - interval '90 days'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE held_at >= date_trunc('year', now())), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE retro_kind = 'weekly_engineering'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE retro_kind = 'biweekly_product'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE retro_kind = 'monthly_ops'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE retro_kind = 'quarterly_founder'), 0),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros WHERE retro_kind = 'incident_retro'), 0),
    (SELECT max(held_at) FROM public.founder_team_retros),
    coalesce((SELECT extract(day from (now() - max(held_at)))::int FROM public.founder_team_retros), 0),
    (SELECT format FROM public.founder_team_retros
       WHERE format IS NOT NULL
       GROUP BY format
       ORDER BY count(*) DESC, format ASC
       LIMIT 1),
    coalesce((SELECT count(*)::bigint FROM public.founder_team_retros
       WHERE format = (SELECT format FROM public.founder_team_retros
                         WHERE format IS NOT NULL
                         GROUP BY format
                         ORDER BY count(*) DESC, format ASC
                         LIMIT 1)), 0),
    coalesce((SELECT round(avg(attendees_count)::numeric, 1) FROM public.founder_team_retros WHERE attendees_count > 0), 0)::numeric;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_team_retro_archive_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_team_retro_archive_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_team_retros_recent(text, int);
CREATE OR REPLACE FUNCTION public.founder_team_retros_recent(p_kind text DEFAULT NULL, p_limit int DEFAULT 50)
RETURNS TABLE (
  id                    uuid,
  retro_label           text,
  retro_kind            text,
  held_at               timestamptz,
  attendees_count       int,
  format                text,
  what_went_well        text,
  what_went_poorly      text,
  action_items_text     text,
  surfacing_themes      text,
  blockers_raised       text,
  decisions_committed   text,
  facilitator_user_id   uuid,
  notes_url             text,
  created_at            timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;
  RETURN QUERY
  SELECT r.id, r.retro_label, r.retro_kind, r.held_at, r.attendees_count, r.format,
         r.what_went_well, r.what_went_poorly, r.action_items_text,
         r.surfacing_themes, r.blockers_raised, r.decisions_committed,
         r.facilitator_user_id, r.notes_url, r.created_at
    FROM public.founder_team_retros r
    WHERE p_kind IS NULL OR r.retro_kind = p_kind
    ORDER BY r.held_at DESC
    LIMIT greatest(p_limit, 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_team_retros_recent(text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_team_retros_recent(text, int) TO authenticated;

COMMIT;