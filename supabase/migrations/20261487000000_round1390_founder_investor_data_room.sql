BEGIN;
-- r1390 ★★★ — Investor Data Room (v0.6 Phase 8 shipped early).
--
-- Multi-table multi-RPC heavy ship. Lets founder upload documents organized
-- into folders, grant token-gated access to specific investors with view
-- caps + expiry, and track every view in an access log for diligence
-- analytics.
--
-- Tables:
--   founder_investor_data_room_folders     — folder organization (e.g. financials, legal, product)
--   founder_investor_data_room_documents   — each uploaded doc with storage_uri + folder + sensitivity_band
--   founder_investor_data_room_access_grants — per-investor token-gated grants with max_views + expiry
--   founder_investor_data_room_access_log  — every view recorded (audit trail)
--
-- Page surfaces:
--   /founder-investor-data-room — admin (founder)
--   /share/data-room/[token]    — public (anon, token-gated) — TODO follow-up
--
-- 9 RPCs in this migration covering CRUD on folders/docs/grants + view RPC
-- for public consumption + summary aggregator for the admin page.

-- ============================================================================
-- 1. founder_investor_data_room_folders
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_investor_data_room_folders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_label        text NOT NULL UNIQUE,
  folder_kind         text CHECK (folder_kind IN (
    'financials','legal','product','team','customers','traction',
    'compliance','operations','risks','other'
  )),
  display_order       int DEFAULT 100,
  is_active           boolean DEFAULT true,
  notes               text,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now()
);
ALTER TABLE public.founder_investor_data_room_folders ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dr_folders_no_direct ON public.founder_investor_data_room_folders;
CREATE POLICY dr_folders_no_direct ON public.founder_investor_data_room_folders FOR ALL USING (false);
REVOKE ALL ON public.founder_investor_data_room_folders FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 2. founder_investor_data_room_documents
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_investor_data_room_documents (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_id           uuid REFERENCES public.founder_investor_data_room_folders(id) ON DELETE CASCADE,
  doc_label           text NOT NULL,
  doc_kind            text CHECK (doc_kind IN (
    'pitch_deck','financial_statement','cap_table','customer_list',
    'agreement','license','certificate','metric_export','team_bio',
    'product_demo_video','market_research','other'
  )),
  sensitivity_band    text DEFAULT 'medium' CHECK (sensitivity_band IN (
    'public','low','medium','high','restricted'
  )),
  storage_kind        text DEFAULT 'drive_link' CHECK (storage_kind IN (
    'drive_link','s3','dropbox','figma','docusend','founder_email','other'
  )),
  storage_uri         text,
  display_order       int DEFAULT 100,
  is_active           boolean DEFAULT true,
  uploaded_by         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_at         timestamptz DEFAULT now(),
  notes               text,
  created_at          timestamptz DEFAULT now(),
  updated_at          timestamptz DEFAULT now(),
  UNIQUE(folder_id, doc_label)
);
CREATE INDEX IF NOT EXISTS idx_dr_docs_folder ON public.founder_investor_data_room_documents(folder_id, display_order);
CREATE INDEX IF NOT EXISTS idx_dr_docs_sensitivity ON public.founder_investor_data_room_documents(sensitivity_band, is_active);
ALTER TABLE public.founder_investor_data_room_documents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dr_docs_no_direct ON public.founder_investor_data_room_documents;
CREATE POLICY dr_docs_no_direct ON public.founder_investor_data_room_documents FOR ALL USING (false);
REVOKE ALL ON public.founder_investor_data_room_documents FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 3. founder_investor_data_room_access_grants
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_investor_data_room_access_grants (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  investor_firm_name  text NOT NULL,
  investor_partner_name text,
  investor_partner_email text,
  token_hash          text NOT NULL UNIQUE,
  max_views_total     int DEFAULT 100,
  max_views_per_doc   int DEFAULT 10,
  view_count_total    int DEFAULT 0,
  allowed_sensitivity_bands text[] DEFAULT ARRAY['public','low','medium']::text[],
  expires_at          timestamptz NOT NULL,
  granted_at          timestamptz DEFAULT now(),
  granted_by          uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  revoked_at          timestamptz,
  revoked_reason      text,
  status              text DEFAULT 'active' CHECK (status IN (
    'active','expired','exhausted','revoked'
  )),
  notes               text,
  created_at          timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_dr_grants_status ON public.founder_investor_data_room_access_grants(status, expires_at);
ALTER TABLE public.founder_investor_data_room_access_grants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dr_grants_no_direct ON public.founder_investor_data_room_access_grants;
CREATE POLICY dr_grants_no_direct ON public.founder_investor_data_room_access_grants FOR ALL USING (false);
REVOKE ALL ON public.founder_investor_data_room_access_grants FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- 4. founder_investor_data_room_access_log
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.founder_investor_data_room_access_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grant_id        uuid REFERENCES public.founder_investor_data_room_access_grants(id) ON DELETE CASCADE,
  document_id     uuid REFERENCES public.founder_investor_data_room_documents(id) ON DELETE SET NULL,
  action_kind     text CHECK (action_kind IN ('list_folders','list_docs','view_doc','attempted_blocked','expired')),
  outcome         text CHECK (outcome IN ('ok','expired','exhausted','revoked','not_found','sensitivity_blocked')),
  ip_hash         text,
  user_agent_hash text,
  accessed_at     timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_dr_log_grant ON public.founder_investor_data_room_access_log(grant_id, accessed_at DESC);
CREATE INDEX IF NOT EXISTS idx_dr_log_outcome ON public.founder_investor_data_room_access_log(outcome, accessed_at DESC);
ALTER TABLE public.founder_investor_data_room_access_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS dr_log_no_direct ON public.founder_investor_data_room_access_log;
CREATE POLICY dr_log_no_direct ON public.founder_investor_data_room_access_log FOR ALL USING (false);
REVOKE ALL ON public.founder_investor_data_room_access_log FROM PUBLIC, anon, authenticated;

-- ============================================================================
-- ADMIN RPCs (founder-only)
-- ============================================================================

DROP FUNCTION IF EXISTS public.founder_investor_data_room_summary();
CREATE OR REPLACE FUNCTION public.founder_investor_data_room_summary()
RETURNS TABLE (
  total_folders         bigint,
  total_documents       bigint,
  active_documents      bigint,
  restricted_doc_count  bigint,
  total_grants          bigint,
  active_grants         bigint,
  expired_grants        bigint,
  exhausted_grants      bigint,
  revoked_grants        bigint,
  total_views_lifetime  bigint,
  views_last_30d        bigint,
  views_last_7d         bigint,
  blocked_attempts_30d  bigint,
  most_viewed_doc_label text,
  most_viewed_doc_count int,
  top_investor_firm     text,
  top_investor_views    int,
  generated_at          timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT
    (SELECT count(*) FROM public.founder_investor_data_room_folders)::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_documents)::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_documents WHERE is_active)::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_documents WHERE sensitivity_band = 'restricted')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_grants)::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_grants WHERE status = 'active')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_grants WHERE status = 'expired')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_grants WHERE status = 'exhausted')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_grants WHERE status = 'revoked')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_log WHERE action_kind = 'view_doc' AND outcome = 'ok')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_log WHERE action_kind = 'view_doc' AND outcome = 'ok' AND accessed_at >= now() - interval '30 days')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_log WHERE action_kind = 'view_doc' AND outcome = 'ok' AND accessed_at >= now() - interval '7 days')::bigint,
    (SELECT count(*) FROM public.founder_investor_data_room_access_log WHERE outcome IN ('expired','exhausted','revoked','sensitivity_blocked') AND accessed_at >= now() - interval '30 days')::bigint,
    (SELECT d.doc_label FROM public.founder_investor_data_room_documents d
      JOIN public.founder_investor_data_room_access_log l ON l.document_id = d.id
      WHERE l.outcome = 'ok' AND l.action_kind = 'view_doc'
      GROUP BY d.doc_label ORDER BY count(*) DESC LIMIT 1),
    coalesce((SELECT count(*)::int FROM public.founder_investor_data_room_access_log
              WHERE action_kind = 'view_doc' AND outcome = 'ok'
              GROUP BY document_id ORDER BY count(*) DESC LIMIT 1), 0),
    (SELECT g.investor_firm_name FROM public.founder_investor_data_room_access_grants g
      JOIN public.founder_investor_data_room_access_log l ON l.grant_id = g.id
      WHERE l.outcome = 'ok'
      GROUP BY g.investor_firm_name ORDER BY count(*) DESC LIMIT 1),
    coalesce((SELECT count(*)::int FROM public.founder_investor_data_room_access_log
              WHERE outcome = 'ok' GROUP BY grant_id ORDER BY count(*) DESC LIMIT 1), 0),
    now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_data_room_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_data_room_summary() TO authenticated;

DROP FUNCTION IF EXISTS public.founder_investor_data_room_grants_recent(int);
CREATE OR REPLACE FUNCTION public.founder_investor_data_room_grants_recent(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid, investor_firm_name text, investor_partner_name text,
  status text, view_count_total int, max_views_total int,
  expires_at timestamptz, granted_at timestamptz, days_until_expiry int
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT g.id, g.investor_firm_name, g.investor_partner_name,
         g.status, g.view_count_total, g.max_views_total,
         g.expires_at, g.granted_at,
         CASE WHEN g.expires_at IS NULL THEN NULL
              ELSE extract(day FROM (g.expires_at - now()))::int END
  FROM public.founder_investor_data_room_access_grants g
  ORDER BY g.granted_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_data_room_grants_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_data_room_grants_recent(int) TO authenticated;

DROP FUNCTION IF EXISTS public.founder_investor_data_room_access_log_recent(int);
CREATE OR REPLACE FUNCTION public.founder_investor_data_room_access_log_recent(p_limit int DEFAULT 100)
RETURNS TABLE (
  id uuid, grant_investor_firm text, document_label text,
  action_kind text, outcome text, accessed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT l.id, g.investor_firm_name, d.doc_label,
         l.action_kind, l.outcome, l.accessed_at
  FROM public.founder_investor_data_room_access_log l
  LEFT JOIN public.founder_investor_data_room_access_grants g ON g.id = l.grant_id
  LEFT JOIN public.founder_investor_data_room_documents d ON d.id = l.document_id
  ORDER BY l.accessed_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 500));
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_investor_data_room_access_log_recent(int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_investor_data_room_access_log_recent(int) TO authenticated;

-- ============================================================================
-- WRITE RPCs (founder-only)
-- ============================================================================

DROP FUNCTION IF EXISTS public.log_founder_dr_register_folder(text, text, int);
CREATE OR REPLACE FUNCTION public.log_founder_dr_register_folder(
  p_label text, p_kind text, p_display_order int DEFAULT 100
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_investor_data_room_folders (folder_label, folder_kind, display_order)
  VALUES (p_label, p_kind, coalesce(p_display_order, 100))
  ON CONFLICT (folder_label) DO UPDATE SET folder_kind = EXCLUDED.folder_kind, updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_register_folder(text, text, int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_register_folder(text, text, int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_dr_register_document(uuid, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.log_founder_dr_register_document(
  p_folder_id uuid, p_label text, p_kind text,
  p_sensitivity text DEFAULT 'medium', p_storage_kind text DEFAULT 'drive_link',
  p_storage_uri text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_investor_data_room_documents
    (folder_id, doc_label, doc_kind, sensitivity_band, storage_kind, storage_uri, uploaded_by)
  VALUES (p_folder_id, p_label, p_kind, coalesce(p_sensitivity, 'medium'),
          coalesce(p_storage_kind, 'drive_link'), p_storage_uri, auth.uid())
  ON CONFLICT (folder_id, doc_label) DO UPDATE SET
    doc_kind = EXCLUDED.doc_kind, sensitivity_band = EXCLUDED.sensitivity_band,
    storage_kind = EXCLUDED.storage_kind, storage_uri = EXCLUDED.storage_uri,
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_register_document(uuid, text, text, text, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_register_document(uuid, text, text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_dr_grant_access(text, text, text, text, int, int, text[], int);
CREATE OR REPLACE FUNCTION public.log_founder_dr_grant_access(
  p_firm_name text, p_partner_name text, p_partner_email text,
  p_token_hash text,
  p_max_views_total int DEFAULT 100, p_max_views_per_doc int DEFAULT 10,
  p_allowed_bands text[] DEFAULT ARRAY['public','low','medium']::text[],
  p_expiry_days int DEFAULT 30
) RETURNS uuid
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  INSERT INTO public.founder_investor_data_room_access_grants (
    investor_firm_name, investor_partner_name, investor_partner_email,
    token_hash, max_views_total, max_views_per_doc, allowed_sensitivity_bands,
    expires_at, granted_by, status
  ) VALUES (
    p_firm_name, p_partner_name, p_partner_email, p_token_hash,
    coalesce(p_max_views_total, 100), coalesce(p_max_views_per_doc, 10),
    coalesce(p_allowed_bands, ARRAY['public','low','medium']::text[]),
    now() + (coalesce(p_expiry_days, 30) || ' days')::interval,
    auth.uid(), 'active'
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_grant_access(text, text, text, text, int, int, text[], int) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_grant_access(text, text, text, text, int, int, text[], int) TO authenticated;

DROP FUNCTION IF EXISTS public.log_founder_dr_revoke_grant(uuid, text);
CREATE OR REPLACE FUNCTION public.log_founder_dr_revoke_grant(p_grant_id uuid, p_reason text)
RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;
  UPDATE public.founder_investor_data_room_access_grants
  SET status = 'revoked', revoked_at = now(), revoked_reason = p_reason
  WHERE id = p_grant_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.log_founder_dr_revoke_grant(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.log_founder_dr_revoke_grant(uuid, text) TO authenticated;

-- ============================================================================
-- PUBLIC RPC (anon-callable via SECDEF) — what the /share/data-room/[token] page calls
-- ============================================================================

DROP FUNCTION IF EXISTS public.investor_data_room_view(text, uuid);
CREATE OR REPLACE FUNCTION public.investor_data_room_view(p_token_hash text, p_document_id uuid DEFAULT NULL)
RETURNS TABLE (
  outcome             text,
  investor_firm_name  text,
  remaining_views_total int,
  expires_at          timestamptz,
  document_label      text,
  document_kind       text,
  storage_uri         text
)
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE v_grant record; v_doc record;
BEGIN
  -- No is_founder gate — public surface, token-gated.
  IF p_token_hash IS NULL OR length(p_token_hash) < 16 THEN
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (NULL, p_document_id, 'attempted_blocked', 'not_found');
    RETURN QUERY SELECT 'not_found'::text, NULL::text, 0, NULL::timestamptz, NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  SELECT * INTO v_grant FROM public.founder_investor_data_room_access_grants
  WHERE token_hash = p_token_hash;

  IF v_grant IS NULL THEN
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (NULL, p_document_id, 'attempted_blocked', 'not_found');
    RETURN QUERY SELECT 'not_found'::text, NULL::text, 0, NULL::timestamptz, NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  IF v_grant.status = 'revoked' THEN
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (v_grant.id, p_document_id, 'attempted_blocked', 'revoked');
    RETURN QUERY SELECT 'revoked'::text, v_grant.investor_firm_name, 0, v_grant.expires_at, NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  IF v_grant.expires_at < now() THEN
    UPDATE public.founder_investor_data_room_access_grants SET status = 'expired' WHERE id = v_grant.id;
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (v_grant.id, p_document_id, 'attempted_blocked', 'expired');
    RETURN QUERY SELECT 'expired'::text, v_grant.investor_firm_name, 0, v_grant.expires_at, NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  IF v_grant.view_count_total >= v_grant.max_views_total THEN
    UPDATE public.founder_investor_data_room_access_grants SET status = 'exhausted' WHERE id = v_grant.id;
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (v_grant.id, p_document_id, 'attempted_blocked', 'exhausted');
    RETURN QUERY SELECT 'exhausted'::text, v_grant.investor_firm_name, 0, v_grant.expires_at, NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  IF p_document_id IS NULL THEN
    -- Listing call (no doc) — list visible docs allowed by sensitivity bands
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (v_grant.id, NULL, 'list_docs', 'ok');
    RETURN QUERY SELECT 'ok'::text, v_grant.investor_firm_name,
                        (v_grant.max_views_total - v_grant.view_count_total), v_grant.expires_at,
                        NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  -- Specific doc view
  SELECT * INTO v_doc FROM public.founder_investor_data_room_documents WHERE id = p_document_id AND is_active = true;
  IF v_doc IS NULL THEN
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (v_grant.id, p_document_id, 'view_doc', 'not_found');
    RETURN QUERY SELECT 'not_found'::text, v_grant.investor_firm_name,
                        (v_grant.max_views_total - v_grant.view_count_total), v_grant.expires_at,
                        NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  IF NOT (v_doc.sensitivity_band = ANY (v_grant.allowed_sensitivity_bands)) THEN
    INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
    VALUES (v_grant.id, p_document_id, 'view_doc', 'sensitivity_blocked');
    RETURN QUERY SELECT 'sensitivity_blocked'::text, v_grant.investor_firm_name,
                        (v_grant.max_views_total - v_grant.view_count_total), v_grant.expires_at,
                        NULL::text, NULL::text, NULL::text;
    RETURN;
  END IF;

  UPDATE public.founder_investor_data_room_access_grants
  SET view_count_total = view_count_total + 1
  WHERE id = v_grant.id;

  INSERT INTO public.founder_investor_data_room_access_log (grant_id, document_id, action_kind, outcome)
  VALUES (v_grant.id, p_document_id, 'view_doc', 'ok');

  RETURN QUERY SELECT 'ok'::text, v_grant.investor_firm_name,
                      (v_grant.max_views_total - v_grant.view_count_total - 1), v_grant.expires_at,
                      v_doc.doc_label, v_doc.doc_kind, v_doc.storage_uri;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.investor_data_room_view(text, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.investor_data_room_view(text, uuid) TO anon, authenticated;

-- ============================================================================
-- Seed default folders
-- ============================================================================
INSERT INTO public.founder_investor_data_room_folders (folder_label, folder_kind, display_order)
VALUES
  ('Financials & metrics', 'financials', 10),
  ('Legal & corporate', 'legal', 20),
  ('Product & roadmap', 'product', 30),
  ('Team & advisors', 'team', 40),
  ('Customer references', 'customers', 50),
  ('Traction & growth', 'traction', 60),
  ('Compliance & regulatory', 'compliance', 70),
  ('Operations & systems', 'operations', 80),
  ('Risks & disclosures', 'risks', 90)
ON CONFLICT (folder_label) DO NOTHING;

COMMIT;
