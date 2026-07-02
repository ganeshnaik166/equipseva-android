BEGIN;

CREATE TABLE IF NOT EXISTS public.investor_irr_benchmark_comparisons_r1849 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fiscal_year int NOT NULL,
  our_avg_irr_pct numeric(6,2),
  our_median_irr_pct numeric(6,2),
  cambridge_us_vc_irr_pct numeric(6,2),
  preqin_india_irr_pct numeric(6,2),
  our_top_quartile_irr_pct numeric(6,2),
  status text NOT NULL DEFAULT 'current' CHECK (status IN ('current','superseded')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.investor_irr_benchmark_notes_r1849 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  comparison_id uuid NOT NULL REFERENCES public.investor_irr_benchmark_comparisons_r1849(id) ON DELETE CASCADE,
  note_text text NOT NULL,
  by_email text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_irr_bench_cmp_r1849_year ON public.investor_irr_benchmark_comparisons_r1849(fiscal_year DESC);
CREATE INDEX IF NOT EXISTS idx_irr_bench_cmp_r1849_status ON public.investor_irr_benchmark_comparisons_r1849(status);
CREATE INDEX IF NOT EXISTS idx_irr_bench_notes_r1849_cmp ON public.investor_irr_benchmark_notes_r1849(comparison_id);

ALTER TABLE public.investor_irr_benchmark_comparisons_r1849 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.investor_irr_benchmark_notes_r1849 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS founder_all_irr_cmp_r1849 ON public.investor_irr_benchmark_comparisons_r1849;
CREATE POLICY founder_all_irr_cmp_r1849 ON public.investor_irr_benchmark_comparisons_r1849
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS founder_all_irr_notes_r1849 ON public.investor_irr_benchmark_notes_r1849;
CREATE POLICY founder_all_irr_notes_r1849 ON public.investor_irr_benchmark_notes_r1849
  FOR ALL TO authenticated
  USING (public.is_founder()) WITH CHECK (public.is_founder());

-- RPC 1: list_comparisons
CREATE OR REPLACE FUNCTION public.list_irr_benchmark_comparisons_r1849()
RETURNS TABLE (
  id uuid, fiscal_year int, our_avg_irr_pct numeric, our_median_irr_pct numeric,
  cambridge_us_vc_irr_pct numeric, preqin_india_irr_pct numeric,
  our_top_quartile_irr_pct numeric, status text, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.fiscal_year, c.our_avg_irr_pct, c.our_median_irr_pct,
         c.cambridge_us_vc_irr_pct, c.preqin_india_irr_pct,
         c.our_top_quartile_irr_pct, c.status, c.created_at
  FROM public.investor_irr_benchmark_comparisons_r1849 c
  ORDER BY c.fiscal_year DESC, c.created_at DESC;
END;
$$;

-- RPC 2: save_comparison
CREATE OR REPLACE FUNCTION public.save_irr_benchmark_comparison_r1849(
  p_fiscal_year int,
  p_our_avg numeric,
  p_our_median numeric,
  p_cambridge numeric,
  p_preqin numeric,
  p_top_quartile numeric
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  UPDATE public.investor_irr_benchmark_comparisons_r1849
     SET status = 'superseded', updated_at = now()
   WHERE fiscal_year = p_fiscal_year AND status = 'current';

  INSERT INTO public.investor_irr_benchmark_comparisons_r1849(
    fiscal_year, our_avg_irr_pct, our_median_irr_pct,
    cambridge_us_vc_irr_pct, preqin_india_irr_pct, our_top_quartile_irr_pct, status
  ) VALUES (
    p_fiscal_year, p_our_avg, p_our_median, p_cambridge, p_preqin, p_top_quartile, 'current'
  ) RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'save_irr_benchmark_comparison_r1849',
          jsonb_build_object('id', v_id, 'fiscal_year', p_fiscal_year));
  RETURN v_id;
END;
$$;

-- RPC 3: list_notes
CREATE OR REPLACE FUNCTION public.list_irr_benchmark_notes_r1849(p_comparison_id uuid)
RETURNS TABLE (id uuid, comparison_id uuid, note_text text, by_email text, at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.id, n.comparison_id, n.note_text, n.by_email, n.at
  FROM public.investor_irr_benchmark_notes_r1849 n
  WHERE n.comparison_id = p_comparison_id
  ORDER BY n.at DESC;
END;
$$;

-- RPC 4: add_note
CREATE OR REPLACE FUNCTION public.add_irr_benchmark_note_r1849(p_comparison_id uuid, p_note_text text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  INSERT INTO public.investor_irr_benchmark_notes_r1849(comparison_id, note_text, by_email)
  VALUES (p_comparison_id, p_note_text, (auth.jwt()->>'email'))
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (auth.uid(), (auth.jwt()->>'email'), 'add_irr_benchmark_note_r1849',
          jsonb_build_object('id', v_id, 'comparison_id', p_comparison_id));
  RETURN v_id;
END;
$$;

-- RPC 5: latest_comparison
CREATE OR REPLACE FUNCTION public.latest_irr_benchmark_comparison_r1849()
RETURNS TABLE (
  id uuid, fiscal_year int, our_avg_irr_pct numeric, our_median_irr_pct numeric,
  cambridge_us_vc_irr_pct numeric, preqin_india_irr_pct numeric,
  our_top_quartile_irr_pct numeric, status text, created_at timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.id, c.fiscal_year, c.our_avg_irr_pct, c.our_median_irr_pct,
         c.cambridge_us_vc_irr_pct, c.preqin_india_irr_pct,
         c.our_top_quartile_irr_pct, c.status, c.created_at
  FROM public.investor_irr_benchmark_comparisons_r1849 c
  WHERE c.status = 'current'
  ORDER BY c.fiscal_year DESC
  LIMIT 1;
END;
$$;

-- RPC 6: year_summary
CREATE OR REPLACE FUNCTION public.irr_benchmark_year_summary_r1849()
RETURNS TABLE (
  fiscal_year int,
  current_count int,
  superseded_count int,
  our_avg_irr_pct numeric,
  cambridge_us_vc_irr_pct numeric,
  preqin_india_irr_pct numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.fiscal_year,
         (COUNT(*) FILTER (WHERE c.status = 'current'))::int AS current_count,
         (COUNT(*) FILTER (WHERE c.status = 'superseded'))::int AS superseded_count,
         MAX(CASE WHEN c.status = 'current' THEN c.our_avg_irr_pct END) AS our_avg_irr_pct,
         MAX(CASE WHEN c.status = 'current' THEN c.cambridge_us_vc_irr_pct END) AS cambridge_us_vc_irr_pct,
         MAX(CASE WHEN c.status = 'current' THEN c.preqin_india_irr_pct END) AS preqin_india_irr_pct
  FROM public.investor_irr_benchmark_comparisons_r1849 c
  GROUP BY c.fiscal_year
  ORDER BY c.fiscal_year DESC;
END;
$$;

-- RPC 7: top_performers
CREATE OR REPLACE FUNCTION public.irr_benchmark_top_performers_r1849()
RETURNS TABLE (
  fiscal_year int,
  our_top_quartile_irr_pct numeric,
  our_avg_irr_pct numeric,
  cambridge_us_vc_irr_pct numeric,
  alpha_vs_cambridge numeric
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT c.fiscal_year,
         c.our_top_quartile_irr_pct,
         c.our_avg_irr_pct,
         c.cambridge_us_vc_irr_pct,
         (COALESCE(c.our_avg_irr_pct,0) - COALESCE(c.cambridge_us_vc_irr_pct,0))::numeric AS alpha_vs_cambridge
  FROM public.investor_irr_benchmark_comparisons_r1849 c
  WHERE c.status = 'current'
  ORDER BY (COALESCE(c.our_avg_irr_pct,0) - COALESCE(c.cambridge_us_vc_irr_pct,0)) DESC NULLS LAST
  LIMIT 20;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_irr_benchmark_comparisons_r1849() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.save_irr_benchmark_comparison_r1849(int,numeric,numeric,numeric,numeric,numeric) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_irr_benchmark_notes_r1849(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_irr_benchmark_note_r1849(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.latest_irr_benchmark_comparison_r1849() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.irr_benchmark_year_summary_r1849() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.irr_benchmark_top_performers_r1849() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_irr_benchmark_comparisons_r1849() TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_irr_benchmark_comparison_r1849(int,numeric,numeric,numeric,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_irr_benchmark_notes_r1849(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_irr_benchmark_note_r1849(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.latest_irr_benchmark_comparison_r1849() TO authenticated;
GRANT EXECUTE ON FUNCTION public.irr_benchmark_year_summary_r1849() TO authenticated;
GRANT EXECUTE ON FUNCTION public.irr_benchmark_top_performers_r1849() TO authenticated;

COMMIT;