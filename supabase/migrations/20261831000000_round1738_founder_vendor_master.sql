BEGIN;

-- =========================================================================
-- Round 1738 — Founder Vendor Master
-- =========================================================================

CREATE TABLE IF NOT EXISTS public.founder_vendor_master_r1738 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_name text NOT NULL,
  vendor_category text NOT NULL CHECK (vendor_category IN ('spare_parts','tools','software','legal','accounting','marketing','logistics')),
  primary_contact_email text,
  primary_contact_phone text,
  payment_terms_days int NOT NULL DEFAULT 30,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','under_review','blocked','dropped')),
  onboarded_at timestamptz NOT NULL DEFAULT now(),
  last_review_at timestamptz,
  performance_score int CHECK (performance_score BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.founder_vendor_review_notes_r1738 (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vendor_id uuid NOT NULL REFERENCES public.founder_vendor_master_r1738(id) ON DELETE CASCADE,
  reviewer_email text NOT NULL,
  decision text NOT NULL CHECK (decision IN ('approve','concern','block','upgrade')),
  decision_note text,
  at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vendor_master_r1738_status ON public.founder_vendor_master_r1738(status);
CREATE INDEX IF NOT EXISTS idx_vendor_master_r1738_category ON public.founder_vendor_master_r1738(vendor_category);
CREATE INDEX IF NOT EXISTS idx_vendor_review_r1738_vendor ON public.founder_vendor_review_notes_r1738(vendor_id);
CREATE INDEX IF NOT EXISTS idx_vendor_review_r1738_at ON public.founder_vendor_review_notes_r1738(at DESC);

ALTER TABLE public.founder_vendor_master_r1738 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_vendor_review_notes_r1738 ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vendor_master_r1738_founder ON public.founder_vendor_master_r1738;
CREATE POLICY vendor_master_r1738_founder ON public.founder_vendor_master_r1738
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

DROP POLICY IF EXISTS vendor_review_r1738_founder ON public.founder_vendor_review_notes_r1738;
CREATE POLICY vendor_review_r1738_founder ON public.founder_vendor_review_notes_r1738
  FOR ALL TO authenticated
  USING (public.is_founder())
  WITH CHECK (public.is_founder());

-- =========================================================================
-- RPCs
-- =========================================================================

DROP FUNCTION IF EXISTS public.list_vendors_r1738();
CREATE OR REPLACE FUNCTION public.list_vendors_r1738()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_category text,
  primary_contact_email text,
  primary_contact_phone text,
  payment_terms_days int,
  status text,
  onboarded_at timestamptz,
  last_review_at timestamptz,
  performance_score int
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
  SELECT v.id, v.vendor_name, v.vendor_category, v.primary_contact_email,
         v.primary_contact_phone, v.payment_terms_days, v.status,
         v.onboarded_at, v.last_review_at, v.performance_score
  FROM public.founder_vendor_master_r1738 v
  ORDER BY v.onboarded_at DESC;
END;
$$;

DROP FUNCTION IF EXISTS public.add_vendor_r1738(text, text, text, text, int);
CREATE OR REPLACE FUNCTION public.add_vendor_r1738(
  p_vendor_name text,
  p_vendor_category text,
  p_primary_contact_email text,
  p_primary_contact_phone text,
  p_payment_terms_days int
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

  INSERT INTO public.founder_vendor_master_r1738(
    vendor_name, vendor_category, primary_contact_email,
    primary_contact_phone, payment_terms_days
  )
  VALUES (
    p_vendor_name, p_vendor_category, p_primary_contact_email,
    p_primary_contact_phone, COALESCE(p_payment_terms_days, 30)
  )
  RETURNING id INTO v_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'add_vendor_r1738',
    jsonb_build_object('vendor_id', v_id, 'vendor_name', p_vendor_name, 'category', p_vendor_category)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.list_reviews_r1738(uuid);
CREATE OR REPLACE FUNCTION public.list_reviews_r1738(p_vendor_id uuid)
RETURNS TABLE (
  id uuid,
  vendor_id uuid,
  vendor_name text,
  reviewer_email text,
  decision text,
  decision_note text,
  at timestamptz
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
  SELECT r.id, r.vendor_id, v.vendor_name, r.reviewer_email,
         r.decision, r.decision_note, r.at
  FROM public.founder_vendor_review_notes_r1738 r
  JOIN public.founder_vendor_master_r1738 v ON v.id = r.vendor_id
  WHERE (p_vendor_id IS NULL OR r.vendor_id = p_vendor_id)
  ORDER BY r.at DESC
  LIMIT 200;
END;
$$;

DROP FUNCTION IF EXISTS public.log_review_r1738(uuid, text, text);
CREATE OR REPLACE FUNCTION public.log_review_r1738(
  p_vendor_id uuid,
  p_decision text,
  p_decision_note text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_id uuid;
  v_email text;
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_email := (auth.jwt()->>'email');

  INSERT INTO public.founder_vendor_review_notes_r1738(
    vendor_id, reviewer_email, decision, decision_note
  )
  VALUES (p_vendor_id, v_email, p_decision, p_decision_note)
  RETURNING id INTO v_id;

  UPDATE public.founder_vendor_master_r1738
  SET last_review_at = now(), updated_at = now()
  WHERE id = p_vendor_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    v_email,
    'log_review_r1738',
    jsonb_build_object('vendor_id', p_vendor_id, 'decision', p_decision)
  );

  RETURN v_id;
END;
$$;

DROP FUNCTION IF EXISTS public.update_status_r1738(uuid, text);
CREATE OR REPLACE FUNCTION public.update_status_r1738(
  p_vendor_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.founder_vendor_master_r1738
  SET status = p_status, updated_at = now()
  WHERE id = p_vendor_id;

  INSERT INTO public.founder_action_log(actor_user_id, actor_email, op_name, after_value)
  VALUES (
    auth.uid(),
    (auth.jwt()->>'email'),
    'update_status_r1738',
    jsonb_build_object('vendor_id', p_vendor_id, 'status', p_status)
  );
END;
$$;

DROP FUNCTION IF EXISTS public.top_performing_vendors_r1738();
CREATE OR REPLACE FUNCTION public.top_performing_vendors_r1738()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_category text,
  performance_score int,
  status text,
  onboarded_at timestamptz
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
  SELECT v.id, v.vendor_name, v.vendor_category, v.performance_score,
         v.status, v.onboarded_at
  FROM public.founder_vendor_master_r1738 v
  WHERE v.performance_score IS NOT NULL
    AND v.status = 'active'
  ORDER BY v.performance_score DESC, v.onboarded_at DESC
  LIMIT 25;
END;
$$;

DROP FUNCTION IF EXISTS public.vendors_under_review_r1738();
CREATE OR REPLACE FUNCTION public.vendors_under_review_r1738()
RETURNS TABLE (
  id uuid,
  vendor_name text,
  vendor_category text,
  status text,
  last_review_at timestamptz,
  review_count int
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
  SELECT v.id, v.vendor_name, v.vendor_category, v.status, v.last_review_at,
         (COUNT(r.id) FILTER (WHERE r.id IS NOT NULL))::int AS review_count
  FROM public.founder_vendor_master_r1738 v
  LEFT JOIN public.founder_vendor_review_notes_r1738 r ON r.vendor_id = v.id
  WHERE v.status IN ('under_review','blocked')
  GROUP BY v.id, v.vendor_name, v.vendor_category, v.status, v.last_review_at
  ORDER BY v.last_review_at DESC NULLS LAST
  LIMIT 100;
END;
$$;

-- =========================================================================
-- Privileges
-- =========================================================================

REVOKE EXECUTE ON FUNCTION public.list_vendors_r1738() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.add_vendor_r1738(text, text, text, text, int) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_reviews_r1738(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_review_r1738(uuid, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.update_status_r1738(uuid, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.top_performing_vendors_r1738() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.vendors_under_review_r1738() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.list_vendors_r1738() TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_vendor_r1738(text, text, text, text, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_reviews_r1738(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_review_r1738(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_status_r1738(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.top_performing_vendors_r1738() TO authenticated;
GRANT EXECUTE ON FUNCTION public.vendors_under_review_r1738() TO authenticated;

COMMIT;