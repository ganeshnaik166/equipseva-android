BEGIN;

-- ============================================================================
-- Round 1873 — Investor Quarterly Update Newsletter
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.investor_quarterly_newsletters_r1873 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_quarter text UNIQUE NOT NULL,
  headline text NOT NULL,
  body_md text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','under_review','finalized','sent','archived')),
  drafted_at timestamptz,
  sent_at timestamptz,
  sent_to_count int NOT NULL DEFAULT 0,
  audience_segments text[] NOT NULL DEFAULT ARRAY[]::text[],
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_newsletter_send_log_r1873 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  newsletter_id uuid NOT NULL REFERENCES public.investor_quarterly_newsletters_r1873(id) ON DELETE CASCADE,
  recipient_email text NOT NULL,
  sent_at timestamptz NOT NULL DEFAULT now(),
  opened_at timestamptz,
  clicked boolean NOT NULL DEFAULT false,
  reply_received boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_newsletter_send_log_r1873_nid
  ON public.investor_newsletter_send_log_r1873(newsletter_id);

ALTER TABLE public.investor_quarterly_newsletters_r1873 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_newsletter_send_log_r1873 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_iqn_r1873 ON public.investor_quarterly_newsletters_r1873;
CREATE POLICY founder_all_iqn_r1873 ON public.investor_quarterly_newsletters_r1873
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_insl_r1873 ON public.investor_newsletter_send_log_r1873;
CREATE POLICY founder_all_insl_r1873 ON public.investor_newsletter_send_log_r1873
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- ============================================================================
-- RPCs
-- ============================================================================

CREATE OR REPLACE FUNCTION public.list_newsletters_r1873()
RETURNS TABLE (
  id uuid,
  fiscal_quarter text,
  headline text,
  status text,
  drafted_at timestamptz,
  sent_at timestamptz,
  sent_to_count int,
  audience_segments text[],
  created_at timestamptz
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
  SELECT n.id, n.fiscal_quarter, n.headline, n.status, n.drafted_at, n.sent_at,
         n.sent_to_count, n.audience_segments, n.created_at
  FROM public.investor_quarterly_newsletters_r1873 n
  ORDER BY n.created_at DESC
  LIMIT 200;
END;
$$;

CREATE OR REPLACE FUNCTION public.draft_newsletter_r1873(
  p_fiscal_quarter text,
  p_headline text,
  p_body_md text,
  p_audience_segments text[]
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
  INSERT INTO public.investor_quarterly_newsletters_r1873
    (fiscal_quarter, headline, body_md, status, drafted_at, audience_segments)
  VALUES
    (p_fiscal_quarter, p_headline, COALESCE(p_body_md,''), 'draft', now(),
     COALESCE(p_audience_segments, ARRAY[]::text[]))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'draft_newsletter_r1873',
          jsonb_build_object('id', v_id, 'fiscal_quarter', p_fiscal_quarter));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_newsletter_r1873(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_quarterly_newsletters_r1873
     SET status = 'finalized', updated_at = now()
   WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'finalize_newsletter_r1873',
          jsonb_build_object('id', p_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.list_send_log_r1873(p_newsletter_id uuid)
RETURNS TABLE (
  id uuid,
  newsletter_id uuid,
  recipient_email text,
  sent_at timestamptz,
  opened_at timestamptz,
  clicked boolean,
  reply_received boolean
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
  SELECT s.id, s.newsletter_id, s.recipient_email, s.sent_at, s.opened_at,
         s.clicked, s.reply_received
  FROM public.investor_newsletter_send_log_r1873 s
  WHERE s.newsletter_id = p_newsletter_id
  ORDER BY s.sent_at DESC
  LIMIT 500;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_send_r1873(
  p_newsletter_id uuid,
  p_recipient_email text
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
  INSERT INTO public.investor_newsletter_send_log_r1873
    (newsletter_id, recipient_email, sent_at)
  VALUES (p_newsletter_id, p_recipient_email, now())
  RETURNING id INTO v_id;

  UPDATE public.investor_quarterly_newsletters_r1873
     SET sent_to_count = sent_to_count + 1,
         updated_at = now()
   WHERE id = p_newsletter_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_send_r1873',
          jsonb_build_object('newsletter_id', p_newsletter_id, 'recipient_email', p_recipient_email));
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_finalized_r1873(p_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.investor_quarterly_newsletters_r1873
     SET status = 'sent',
         sent_at = COALESCE(sent_at, now()),
         updated_at = now()
   WHERE id = p_id;

  INSERT INTO public.founder_action_log (actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'mark_finalized_r1873',
          jsonb_build_object('id', p_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.open_rate_summary_r1873()
RETURNS TABLE (
  newsletter_id uuid,
  fiscal_quarter text,
  headline text,
  total_sent int,
  total_opened int,
  total_clicked int,
  total_replied int,
  open_rate_pct numeric
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
  SELECT n.id AS newsletter_id,
         n.fiscal_quarter,
         n.headline,
         (COUNT(s.id))::int AS total_sent,
         (COUNT(*) FILTER (WHERE s.opened_at IS NOT NULL))::int AS total_opened,
         (COUNT(*) FILTER (WHERE s.clicked))::int AS total_clicked,
         (COUNT(*) FILTER (WHERE s.reply_received))::int AS total_replied,
         CASE WHEN COUNT(s.id) > 0
              THEN ROUND( (COUNT(*) FILTER (WHERE s.opened_at IS NOT NULL))::numeric
                          / NULLIF(COUNT(s.id),0) * 100, 1)
              ELSE 0 END AS open_rate_pct
  FROM public.investor_quarterly_newsletters_r1873 n
  LEFT JOIN public.investor_newsletter_send_log_r1873 s
    ON s.newsletter_id = n.id
  GROUP BY n.id, n.fiscal_quarter, n.headline, n.created_at
  ORDER BY n.created_at DESC
  LIMIT 100;
END;
$$;

-- ============================================================================
-- Grants
-- ============================================================================

REVOKE EXECUTE ON FUNCTION public.list_newsletters_r1873()             FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.draft_newsletter_r1873(text,text,text,text[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.finalize_newsletter_r1873(uuid)      FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_send_log_r1873(uuid)            FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_send_r1873(uuid,text)            FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_finalized_r1873(uuid)           FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.open_rate_summary_r1873()            FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_newsletters_r1873()              TO authenticated;
GRANT EXECUTE ON FUNCTION public.draft_newsletter_r1873(text,text,text,text[])  TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_newsletter_r1873(uuid)       TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_send_log_r1873(uuid)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_send_r1873(uuid,text)             TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_finalized_r1873(uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.open_rate_summary_r1873()             TO authenticated;

COMMIT;