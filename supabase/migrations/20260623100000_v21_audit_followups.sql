-- v2.1 PR-D49 — CodeRabbit follow-ups on PRs #322 + #323:
--
-- (a) chat_messages_mask_pii — fix misleading comment that claimed the
--     audit row would persist if the parent INSERT later failed. The
--     BEFORE INSERT trigger runs in the same transaction; if RLS or any
--     constraint rejects the parent, the audit row rolls back too.
--     Function body unchanged otherwise.
--
-- (b) recompute_engineer_rating_aggregates — when a hospital crosses
--     the ">=2 distinct engineers" trusted-hospital threshold via a
--     rating for engineer B, ripple the recompute to every OTHER
--     engineer this hospital has previously rated. Without the ripple,
--     prior excluded ratings for engineer A stay excluded until some
--     unrelated write touches A's row.

-- ---------- (a) chat_messages_mask_pii — comment fix only ------------

CREATE OR REPLACE FUNCTION public.chat_messages_mask_pii()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
  v_phone_re constant text := '(?:\+?\s?91[\s-]?|0)?[6-9]\d{9}';
  v_email_re constant text := '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}';
  v_replacement constant text := '[contact removed — keep on EquipSeva]';

  v_orig text;
  v_masked text;
  v_kinds text[] := ARRAY[]::text[];
  v_count int := 0;
  v_phone_hits int := 0;
  v_email_hits int := 0;
BEGIN
  v_orig := COALESCE(NEW.message, '');
  IF v_orig = '' THEN RETURN NEW; END IF;
  v_masked := v_orig;

  SELECT count(*) INTO v_phone_hits
    FROM regexp_matches(v_masked, v_phone_re, 'g');
  IF v_phone_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_phone_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'phone');
    v_count := v_count + v_phone_hits;
  END IF;

  SELECT count(*) INTO v_email_hits
    FROM regexp_matches(v_masked, v_email_re, 'g');
  IF v_email_hits > 0 THEN
    v_masked := regexp_replace(v_masked, v_email_re, v_replacement, 'g');
    v_kinds := array_append(v_kinds, 'email');
    v_count := v_count + v_email_hits;
  END IF;

  IF v_count > 0 THEN
    NEW.message := v_masked;
    -- Audit. Persists only when the parent INSERT commits — BEFORE
    -- INSERT triggers run in the same transaction, so a downstream RLS
    -- reject or constraint failure rolls this row back too. That's
    -- fine: when chat_messages INSERT is rejected, the leak attempt
    -- never materialised either, so we don't need a "tried to leak"
    -- audit. (CodeRabbit follow-up.)
    INSERT INTO public.chat_message_moderation_events (
      conversation_id, sender_user_id, original_excerpt, matched_kinds, masked_count
    ) VALUES (
      NEW.conversation_id,
      NEW.sender_user_id,
      LEFT(v_orig, 200),
      v_kinds,
      v_count
    );
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_messages_mask_pii() FROM PUBLIC;

-- ---------- (b) recompute_engineer_rating_aggregates — ripple --------

CREATE OR REPLACE FUNCTION public.recompute_engineer_rating_aggregates()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_min_amount constant numeric := 500;
  v_min_distinct_engineers constant int := 2;
  v_hospital uuid := NEW.hospital_user_id;
  v_distinct_all int;
  v_distinct_others int;
  v_should_ripple boolean := false;
  v_eng record;
  v_avg numeric;
  v_cnt int;
BEGIN
  IF NEW.engineer_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Detect threshold crossing: did this rating push the hospital from
  -- < 2 distinct rated engineers to >= 2? Only then do we need to
  -- ripple-recompute the OTHER engineers this hospital has rated.
  -- Counting "others" as everyone-but-this-row keeps the math right
  -- regardless of whether NEW.engineer_id is new or repeat.
  SELECT count(DISTINCT engineer_id) INTO v_distinct_all
    FROM public.repair_jobs
   WHERE hospital_user_id = v_hospital
     AND hospital_rating IS NOT NULL
     AND status::text = 'completed'
     AND engineer_id IS NOT NULL;

  SELECT count(DISTINCT engineer_id) INTO v_distinct_others
    FROM public.repair_jobs
   WHERE hospital_user_id = v_hospital
     AND hospital_rating IS NOT NULL
     AND status::text = 'completed'
     AND engineer_id IS NOT NULL
     AND id <> NEW.id;

  v_should_ripple :=
    v_distinct_all >= v_min_distinct_engineers
    AND v_distinct_others < v_min_distinct_engineers;

  -- Recompute set:
  --   * always NEW.engineer_id (the row that just got rated)
  --   * + every other engineer this hospital has previously rated, IFF
  --     this rating is the threshold-crosser. Idempotent overlap is
  --     fine — engineer_id appears once per hospital × engineer pair.
  FOR v_eng IN
    SELECT DISTINCT engineer_id
      FROM public.repair_jobs
     WHERE hospital_rating IS NOT NULL
       AND status::text = 'completed'
       AND engineer_id IS NOT NULL
       AND (
            engineer_id = NEW.engineer_id
            OR (v_should_ripple AND hospital_user_id = v_hospital)
       )
  LOOP
    WITH trusted_hospitals AS (
      SELECT hospital_user_id
        FROM public.repair_jobs
       WHERE hospital_rating IS NOT NULL
         AND status::text = 'completed'
         AND engineer_id IS NOT NULL
       GROUP BY hospital_user_id
      HAVING count(DISTINCT engineer_id) >= v_min_distinct_engineers
    )
    SELECT COALESCE(AVG(rj.hospital_rating)::numeric(10,2), 0), COUNT(*)
      INTO v_avg, v_cnt
      FROM public.repair_jobs rj
      JOIN trusted_hospitals th ON th.hospital_user_id = rj.hospital_user_id
     WHERE rj.engineer_id = v_eng.engineer_id
       AND rj.hospital_rating IS NOT NULL
       AND rj.status::text = 'completed'
       AND COALESCE(rj.contracted_amount_rupees, 0) >= v_min_amount;

    UPDATE public.engineers
       SET rating_avg = v_avg,
           total_jobs = v_cnt
     WHERE id = v_eng.engineer_id;
  END LOOP;

  RETURN NEW;
END;
$$;

ALTER FUNCTION public.recompute_engineer_rating_aggregates() OWNER TO postgres;
REVOKE ALL ON FUNCTION public.recompute_engineer_rating_aggregates() FROM PUBLIC;
