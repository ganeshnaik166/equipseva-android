-- Move pg_trgm extension out of `public` to `extensions`.
-- Clears the Supabase advisor WARN "Extension in Public" (0014). Having
-- extensions in public means the extension's functions and operator classes
-- live alongside user-defined objects, which enlarges the surface for
-- same-name shadowing attacks via search_path and makes it harder to audit
-- what ships with user code vs. what is platform-provided.
--
-- The only dependent object is `public.idx_spare_parts_search`, a gin index
-- using `gin_trgm_ops`. That operator class moves with the extension, so the
-- index must be dropped and recreated with the new fully-qualified op-class
-- name (`extensions.gin_trgm_ops`).
--
-- spare_parts is 14 rows at time of change — recreate is instantaneous.
-- Queries calling `similarity()`, `%`, `<%>`, etc. continue to work because
-- Supabase roles have `extensions` on their search_path by default.

DROP INDEX IF EXISTS public.idx_spare_parts_search;

ALTER EXTENSION pg_trgm SET SCHEMA extensions;

CREATE INDEX idx_spare_parts_search
  ON public.spare_parts
  USING gin (name extensions.gin_trgm_ops);
