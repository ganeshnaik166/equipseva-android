BEGIN;

CREATE TABLE IF NOT EXISTS public.hospital_service_excellence_awards_r1827 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  award_year int NOT NULL,
  award_category text NOT NULL CHECK (award_category IN ('engineer_of_year','ops_lead','customer_champion','lifetime_impact')),
  recipient_user_id uuid,
  recipient_name text NOT NULL,
  citation_md text NOT NULL DEFAULT '',
  voted_by text[] NOT NULL DEFAULT ARRAY[]::text[],
  announced_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.hospital_service_excellence_nominations_r1827 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  award_id uuid NOT NULL REFERENCES public.hospital_service_excellence_awards_r1827(id) ON DELETE CASCADE,
  nominator_email text NOT NULL,
  nominee_user_id uuid,
  nominee_name text NOT NULL DEFAULT '',
  citation_text text NOT NULL DEFAULT '',
  votes int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.hospital_service_excellence_awards_r1827 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospital_service_excellence_nominations_r1827 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_awards_r1827 ON public.hospital_service_excellence_awards_r1827;
CREATE POLICY founder_all_awards_r1827 ON public.hospital_service_excellence_awards_r1827
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_nominations_r1827 ON public.hospital_service_excellence_nominations_r1827;
CREATE POLICY founder_all_nominations_r1827 ON public.hospital_service_excellence_nominations_r1827
  FOR ALL TO authenticated USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_awards
CREATE OR REPLACE FUNCTION public.list_excellence_awards_r1827()
RETURNS TABLE (
  id uuid,
  award_year int,
  award_category text,
  recipient_user_id uuid,
  recipient_name text,
  citation_md text,
  voted_by_count int,
  announced_at timestamptz,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.id, a.award_year, a.award_category, a.recipient_user_id, a.recipient_name,
         a.citation_md, COALESCE(array_length(a.voted_by, 1), 0)::int, a.announced_at, a.created_at
  FROM public.hospital_service_excellence_awards_r1827 a
  ORDER BY a.award_year DESC, a.created_at DESC
  LIMIT 300;
END;
$$;

-- RPC 2: present_award
CREATE OR REPLACE FUNCTION public.present_excellence_award_r1827(
  p_award_year int,
  p_award_category text,
  p_recipient_user_id uuid,
  p_recipient_name text,
  p_citation_md text,
  p_voted_by text[]
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_excellence_awards_r1827(
    award_year, award_category, recipient_user_id, recipient_name, citation_md, voted_by, announced_at
  )
  VALUES (
    p_award_year, p_award_category, p_recipient_user_id, p_recipient_name,
    COALESCE(p_citation_md, ''), COALESCE(p_voted_by, ARRAY[]::text[]), now()
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'present_excellence_award_r1827',
          jsonb_build_object('id', v_id, 'award_year', p_award_year, 'category', p_award_category, 'recipient', p_recipient_name));

  RETURN v_id;
END;
$$;

-- RPC 3: list_nominations
CREATE OR REPLACE FUNCTION public.list_excellence_nominations_r1827(p_award_id uuid)
RETURNS TABLE (
  id uuid,
  award_id uuid,
  nominator_email text,
  nominee_user_id uuid,
  nominee_name text,
  citation_text text,
  votes int,
  created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.award_id, n.nominator_email, n.nominee_user_id, n.nominee_name,
         n.citation_text, n.votes, n.created_at
  FROM public.hospital_service_excellence_nominations_r1827 n
  WHERE p_award_id IS NULL OR n.award_id = p_award_id
  ORDER BY n.votes DESC, n.created_at DESC
  LIMIT 300;
END;
$$;

-- RPC 4: log_nomination
CREATE OR REPLACE FUNCTION public.log_excellence_nomination_r1827(
  p_award_id uuid,
  p_nominator_email text,
  p_nominee_user_id uuid,
  p_nominee_name text,
  p_citation_text text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.hospital_service_excellence_nominations_r1827(
    award_id, nominator_email, nominee_user_id, nominee_name, citation_text, votes
  )
  VALUES (p_award_id, p_nominator_email, p_nominee_user_id, COALESCE(p_nominee_name, ''), COALESCE(p_citation_text, ''), 0)
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'log_excellence_nomination_r1827',
          jsonb_build_object('id', v_id, 'award_id', p_award_id, 'nominee_name', p_nominee_name));

  RETURN v_id;
END;
$$;

-- RPC 5: vote_nominee
CREATE OR REPLACE FUNCTION public.vote_excellence_nominee_r1827(p_nomination_id uuid)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_votes int;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.hospital_service_excellence_nominations_r1827
     SET votes = votes + 1, updated_at = now()
   WHERE id = p_nomination_id
  RETURNING votes INTO v_votes;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'vote_excellence_nominee_r1827',
          jsonb_build_object('nomination_id', p_nomination_id, 'votes', v_votes));

  RETURN COALESCE(v_votes, 0);
END;
$$;

-- RPC 6: year_summary
CREATE OR REPLACE FUNCTION public.excellence_year_summary_r1827()
RETURNS TABLE (
  award_year int,
  awards_count int,
  categories_filled int,
  total_nominations int,
  total_votes int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT a.award_year,
         (COUNT(*) )::int AS awards_count,
         (COUNT(DISTINCT a.award_category))::int AS categories_filled,
         COALESCE((SELECT COUNT(*) FROM public.hospital_service_excellence_nominations_r1827 n
                    WHERE n.award_id IN (SELECT id FROM public.hospital_service_excellence_awards_r1827 a2 WHERE a2.award_year = a.award_year)), 0)::int,
         COALESCE((SELECT SUM(n.votes) FROM public.hospital_service_excellence_nominations_r1827 n
                    WHERE n.award_id IN (SELECT id FROM public.hospital_service_excellence_awards_r1827 a2 WHERE a2.award_year = a.award_year)), 0)::int
  FROM public.hospital_service_excellence_awards_r1827 a
  GROUP BY a.award_year
  ORDER BY a.award_year DESC
  LIMIT 50;
END;
$$;

-- RPC 7: top_nominees
CREATE OR REPLACE FUNCTION public.excellence_top_nominees_r1827()
RETURNS TABLE (
  nominee_user_id uuid,
  nominee_name text,
  nomination_count int,
  total_votes int,
  last_nominated_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.nominee_user_id,
         MAX(n.nominee_name) AS nominee_name,
         (COUNT(*))::int AS nomination_count,
         COALESCE(SUM(n.votes), 0)::int AS total_votes,
         MAX(n.created_at) AS last_nominated_at
  FROM public.hospital_service_excellence_nominations_r1827 n
  GROUP BY n.nominee_user_id
  ORDER BY total_votes DESC, nomination_count DESC
  LIMIT 100;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_excellence_awards_r1827() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.present_excellence_award_r1827(int, text, uuid, text, text, text[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_excellence_nominations_r1827(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_excellence_nomination_r1827(uuid, text, uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vote_excellence_nominee_r1827(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.excellence_year_summary_r1827() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.excellence_top_nominees_r1827() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_excellence_awards_r1827() TO authenticated;
GRANT EXECUTE ON FUNCTION public.present_excellence_award_r1827(int, text, uuid, text, text, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_excellence_nominations_r1827(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_excellence_nomination_r1827(uuid, text, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.vote_excellence_nominee_r1827(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.excellence_year_summary_r1827() TO authenticated;
GRANT EXECUTE ON FUNCTION public.excellence_top_nominees_r1827() TO authenticated;

COMMIT;