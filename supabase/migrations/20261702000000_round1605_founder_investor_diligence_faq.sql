BEGIN;

-- =========================================================
-- Round 1605 — Investor Diligence FAQ
-- Central FAQ for investor DD questions; per-question canonical
-- answer + supporting metric + last-updated; founder maintains.
-- =========================================================

-- ---------- Tables ----------
CREATE TABLE IF NOT EXISTS investor_diligence_faq (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category text NOT NULL CHECK (category IN ('market','traction','unit_economics','team','tech','compliance','risks','use_of_funds','exit','other')),
  question text NOT NULL,
  canonical_answer text NOT NULL,
  supporting_metric text,
  supporting_metric_value numeric,
  supporting_metric_unit text,
  source_url text,
  confidence text NOT NULL DEFAULT 'medium' CHECK (confidence IN ('low','medium','high')),
  is_published boolean NOT NULL DEFAULT true,
  display_order int NOT NULL DEFAULT 100,
  view_count int NOT NULL DEFAULT 0,
  last_reviewed_at timestamptz,
  last_updated_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_inv_dd_faq_category ON investor_diligence_faq(category);
CREATE INDEX IF NOT EXISTS idx_inv_dd_faq_published ON investor_diligence_faq(is_published);
CREATE INDEX IF NOT EXISTS idx_inv_dd_faq_updated ON investor_diligence_faq(updated_at DESC);

CREATE TABLE IF NOT EXISTS investor_diligence_faq_revisions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  faq_id uuid NOT NULL REFERENCES investor_diligence_faq(id) ON DELETE CASCADE,
  question text NOT NULL,
  canonical_answer text NOT NULL,
  supporting_metric text,
  supporting_metric_value numeric,
  edited_by uuid REFERENCES auth.users(id),
  edited_at timestamptz NOT NULL DEFAULT now(),
  edit_note text
);

CREATE INDEX IF NOT EXISTS idx_inv_dd_faq_rev_faq ON investor_diligence_faq_revisions(faq_id, edited_at DESC);

-- ---------- RLS ----------
ALTER TABLE investor_diligence_faq ENABLE ROW LEVEL SECURITY;
ALTER TABLE investor_diligence_faq_revisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_only_inv_dd_faq ON investor_diligence_faq;
CREATE POLICY founder_only_inv_dd_faq ON investor_diligence_faq
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

DROP POLICY IF EXISTS founder_only_inv_dd_faq_rev ON investor_diligence_faq_revisions;
CREATE POLICY founder_only_inv_dd_faq_rev ON investor_diligence_faq_revisions
  FOR ALL TO authenticated
  USING (is_founder())
  WITH CHECK (is_founder());

-- ---------- log helpers (VOLATILE SECDEF) ----------
CREATE OR REPLACE FUNCTION log_founder_inv_dd_faq_upsert(p_after jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv_dd_faq_upsert', p_after);
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_inv_dd_faq_upsert(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_inv_dd_faq_upsert(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_inv_dd_faq_delete(p_after jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv_dd_faq_delete', p_after);
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_inv_dd_faq_delete(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_inv_dd_faq_delete(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_inv_dd_faq_review(p_after jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv_dd_faq_review', p_after);
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_inv_dd_faq_review(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_inv_dd_faq_review(jsonb) TO authenticated;

CREATE OR REPLACE FUNCTION log_founder_inv_dd_faq_publish(p_after jsonb)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'inv_dd_faq_publish', p_after);
END $$;
REVOKE EXECUTE ON FUNCTION log_founder_inv_dd_faq_publish(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION log_founder_inv_dd_faq_publish(jsonb) TO authenticated;

-- ---------- Read RPCs (STABLE) ----------
CREATE OR REPLACE FUNCTION founder_inv_dd_faq_kpis()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total int;
  v_published int;
  v_unpublished int;
  v_high_conf int;
  v_medium_conf int;
  v_low_conf int;
  v_with_metric int;
  v_without_metric int;
  v_categories int;
  v_reviewed_30d int;
  v_stale_90d int;
  v_stale_180d int;
  v_never_reviewed int;
  v_total_views int;
  v_recent_edits_7d int;
  v_total_revisions int;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT count(*) INTO v_total FROM investor_diligence_faq;
  SELECT count(*) INTO v_published FROM investor_diligence_faq WHERE is_published;
  SELECT count(*) INTO v_unpublished FROM investor_diligence_faq WHERE NOT is_published;
  SELECT count(*) INTO v_high_conf FROM investor_diligence_faq WHERE confidence='high';
  SELECT count(*) INTO v_medium_conf FROM investor_diligence_faq WHERE confidence='medium';
  SELECT count(*) INTO v_low_conf FROM investor_diligence_faq WHERE confidence='low';
  SELECT count(*) INTO v_with_metric FROM investor_diligence_faq WHERE supporting_metric IS NOT NULL;
  SELECT count(*) INTO v_without_metric FROM investor_diligence_faq WHERE supporting_metric IS NULL;
  SELECT count(DISTINCT category) INTO v_categories FROM investor_diligence_faq;
  SELECT count(*) INTO v_reviewed_30d FROM investor_diligence_faq WHERE last_reviewed_at >= now() - interval '30 days';
  SELECT count(*) INTO v_stale_90d FROM investor_diligence_faq WHERE last_reviewed_at < now() - interval '90 days';
  SELECT count(*) INTO v_stale_180d FROM investor_diligence_faq WHERE last_reviewed_at < now() - interval '180 days';
  SELECT count(*) INTO v_never_reviewed FROM investor_diligence_faq WHERE last_reviewed_at IS NULL;
  SELECT COALESCE(sum(view_count),0) INTO v_total_views FROM investor_diligence_faq;
  SELECT count(*) INTO v_recent_edits_7d FROM investor_diligence_faq_revisions WHERE edited_at >= now() - interval '7 days';
  SELECT count(*) INTO v_total_revisions FROM investor_diligence_faq_revisions;

  RETURN jsonb_build_object(
    'total', v_total,
    'published', v_published,
    'unpublished', v_unpublished,
    'high_conf', v_high_conf,
    'medium_conf', v_medium_conf,
    'low_conf', v_low_conf,
    'with_metric', v_with_metric,
    'without_metric', v_without_metric,
    'categories', v_categories,
    'reviewed_30d', v_reviewed_30d,
    'stale_90d', v_stale_90d,
    'stale_180d', v_stale_180d,
    'never_reviewed', v_never_reviewed,
    'total_views', v_total_views,
    'recent_edits_7d', v_recent_edits_7d,
    'total_revisions', v_total_revisions
  );
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_kpis() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_kpis() TO authenticated;

CREATE OR REPLACE FUNCTION founder_inv_dd_faq_list()
RETURNS TABLE(
  id uuid,
  category text,
  question text,
  canonical_answer text,
  supporting_metric text,
  supporting_metric_value numeric,
  confidence text,
  is_published boolean,
  last_reviewed_at timestamptz,
  updated_at timestamptz,
  days_since_review numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.category, f.question, f.canonical_answer,
         f.supporting_metric, f.supporting_metric_value,
         f.confidence, f.is_published, f.last_reviewed_at, f.updated_at,
         CASE WHEN f.last_reviewed_at IS NULL THEN NULL
              ELSE EXTRACT(EPOCH FROM (now() - f.last_reviewed_at))/86400.0
         END
  FROM investor_diligence_faq f
  ORDER BY f.display_order, f.category, f.created_at DESC
  LIMIT 500;
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_list() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_list() TO authenticated;

CREATE OR REPLACE FUNCTION founder_inv_dd_faq_by_category()
RETURNS TABLE(
  category text,
  total_questions bigint,
  published_count bigint,
  high_conf_count bigint,
  with_metric_count bigint,
  avg_days_since_review numeric
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.category,
         count(*)::bigint,
         count(*) FILTER (WHERE f.is_published)::bigint,
         count(*) FILTER (WHERE f.confidence='high')::bigint,
         count(*) FILTER (WHERE f.supporting_metric IS NOT NULL)::bigint,
         AVG(EXTRACT(EPOCH FROM (now() - f.last_reviewed_at))/86400.0)
  FROM investor_diligence_faq f
  GROUP BY f.category
  ORDER BY count(*) DESC;
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_by_category() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_by_category() TO authenticated;

CREATE OR REPLACE FUNCTION founder_inv_dd_faq_stale()
RETURNS TABLE(
  id uuid,
  category text,
  question text,
  last_reviewed_at timestamptz,
  days_since_review numeric,
  confidence text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT f.id, f.category, f.question, f.last_reviewed_at,
         CASE WHEN f.last_reviewed_at IS NULL THEN 9999::numeric
              ELSE EXTRACT(EPOCH FROM (now() - f.last_reviewed_at))/86400.0
         END,
         f.confidence
  FROM investor_diligence_faq f
  WHERE f.last_reviewed_at IS NULL OR f.last_reviewed_at < now() - interval '90 days'
  ORDER BY f.last_reviewed_at NULLS FIRST
  LIMIT 200;
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_stale() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_stale() TO authenticated;

CREATE OR REPLACE FUNCTION founder_inv_dd_faq_recent_revisions()
RETURNS TABLE(
  rev_id uuid,
  faq_id uuid,
  question text,
  edited_at timestamptz,
  edit_note text
) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT r.id, r.faq_id, r.question, r.edited_at, r.edit_note
  FROM investor_diligence_faq_revisions r
  ORDER BY r.edited_at DESC
  LIMIT 100;
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_recent_revisions() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_recent_revisions() TO authenticated;

-- ---------- Write RPCs (VOLATILE) ----------
CREATE OR REPLACE FUNCTION founder_inv_dd_faq_upsert(
  p_id uuid,
  p_category text,
  p_question text,
  p_canonical_answer text,
  p_supporting_metric text,
  p_supporting_metric_value numeric,
  p_confidence text
) RETURNS uuid LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;

  IF p_id IS NULL THEN
    INSERT INTO investor_diligence_faq(category, question, canonical_answer,
      supporting_metric, supporting_metric_value, confidence,
      last_updated_by, last_reviewed_at)
    VALUES (p_category, p_question, p_canonical_answer,
      p_supporting_metric, p_supporting_metric_value, COALESCE(p_confidence,'medium'),
      auth.uid(), now())
    RETURNING id INTO v_id;
  ELSE
    INSERT INTO investor_diligence_faq_revisions(faq_id, question, canonical_answer, supporting_metric, supporting_metric_value, edited_by, edit_note)
    SELECT id, question, canonical_answer, supporting_metric, supporting_metric_value, auth.uid(), 'upsert'
    FROM investor_diligence_faq WHERE id = p_id;

    UPDATE investor_diligence_faq
      SET category = p_category,
          question = p_question,
          canonical_answer = p_canonical_answer,
          supporting_metric = p_supporting_metric,
          supporting_metric_value = p_supporting_metric_value,
          confidence = COALESCE(p_confidence, confidence),
          last_updated_by = auth.uid(),
          updated_at = now()
    WHERE id = p_id;
    v_id := p_id;
  END IF;

  PERFORM log_founder_inv_dd_faq_upsert(jsonb_build_object('id', v_id, 'category', p_category));
  RETURN v_id;
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_upsert(uuid,text,text,text,text,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_upsert(uuid,text,text,text,text,numeric,text) TO authenticated;

CREATE OR REPLACE FUNCTION founder_inv_dd_faq_mark_reviewed(p_id uuid)
RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE investor_diligence_faq
    SET last_reviewed_at = now(), last_updated_by = auth.uid()
  WHERE id = p_id;
  PERFORM log_founder_inv_dd_faq_review(jsonb_build_object('id', p_id));
END $$;
REVOKE EXECUTE ON FUNCTION founder_inv_dd_faq_mark_reviewed(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION founder_inv_dd_faq_mark_reviewed(uuid) TO authenticated;

COMMIT;