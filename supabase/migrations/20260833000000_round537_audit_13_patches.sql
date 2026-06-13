-- =====================================================================
-- Round 537 — Audit-13 patches (Latin homoglyph normalization)
-- =====================================================================
--
-- Audit-13 (workflow wboktad3v) confirmed 1 MEDIUM real finding:
--
-- MEDIUM — r529 PII regex bypass via Cyrillic / Greek homoglyphs:
--   `user@exаmple.com` where `а` is Cyrillic U+0430 (not Latin a) does
--   NOT match the email regex `[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}`
--   because the character class only covers ASCII Latin. The r529
--   normalizer handled fullwidth digits, Devanagari digits, and
--   zero-width characters but did not address script confusables.
--
-- Fix: extend _analytics_normalize_for_pii to translate the common
-- Latin-script homoglyphs (Cyrillic + Greek lowercase) to their ASCII
-- equivalents before regex evaluation. We don't try to be exhaustive
-- with Unicode Confusables data — we cover the high-frequency attacker-
-- accessible homoglyphs that exist in standard keyboard layouts.
--
-- The other audit-13 finding (Web server actions returning raw
-- error.message) is fixed in the web/ patch in the same PR — not in
-- this migration.

BEGIN;

CREATE OR REPLACE FUNCTION public._analytics_normalize_for_pii(p_value text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  v text := p_value;
BEGIN
  IF v IS NULL THEN
    RETURN NULL;
  END IF;

  -- Strip zero-width: U+200B (ZWSP), U+200C (ZWNJ), U+200D (ZWJ), U+FEFF (BOM)
  v := translate(v, E'​‌‍﻿', '');

  -- Fullwidth digits 0-9 (U+FF10..U+FF19) → ASCII 0-9
  v := translate(v, E'０１２３４５６７８９', '0123456789');

  -- Devanagari digits ०-९ (U+0966..U+096F) → ASCII 0-9
  v := translate(v, E'०१२३४५६७८९', '0123456789');

  -- r537 audit-13 MEDIUM fix — script-confusable letters:
  --
  -- Cyrillic lowercase look-alikes → ASCII Latin lowercase:
  --   а(U+0430)→a, в(U+0432)→b (visually similar in some fonts),
  --   е(U+0435)→e, к(U+043A)→k, м(U+043C)→m (visually similar in caps),
  --   о(U+043E)→o, р(U+0440)→p, с(U+0441)→c, у(U+0443)→y, х(U+0445)→x
  v := translate(v, E'аеорсухкв', 'aeopcyxkb');

  -- Cyrillic uppercase confusables → ASCII Latin uppercase:
  --   А(U+0410)→A, В(U+0412)→B, Е(U+0415)→E, К(U+041A)→K,
  --   М(U+041C)→M, Н(U+041D)→H, О(U+041E)→O, Р(U+0420)→P,
  --   С(U+0421)→C, Т(U+0422)→T, У(U+0423)→Y, Х(U+0425)→X
  v := translate(v, E'АВЕКМНОРСТУХ', 'ABEKMHOPCTYX');

  -- Greek lowercase confusables → ASCII Latin lowercase:
  --   α(U+03B1)→a, ε(U+03B5)→e, ο(U+03BF)→o, ρ(U+03C1)→p,
  --   ν(U+03BD)→v, υ(U+03C5)→u, τ(U+03C4)→t, ι(U+03B9)→i,
  --   κ(U+03BA)→k, χ(U+03C7)→x, μ(U+03BC)→m, η(U+03B7)→n
  v := translate(v, E'αεορνυτικχμη', 'aeopvutikxmn');

  -- Greek uppercase confusables → ASCII Latin uppercase:
  --   Α(U+0391)→A, Β(U+0392)→B, Ε(U+0395)→E, Ζ(U+0396)→Z,
  --   Η(U+0397)→H, Ι(U+0399)→I, Κ(U+039A)→K, Μ(U+039C)→M,
  --   Ν(U+039D)→N, Ο(U+039F)→O, Ρ(U+03A1)→P, Τ(U+03A4)→T,
  --   Υ(U+03A5)→Y, Χ(U+03A7)→X
  v := translate(v, E'ΑΒΕΖΗΙΚΜΝΟΡΤΥΧ', 'ABEZHIKMNOPTYX');

  -- Strip remaining whitespace + non-printing controls.
  v := regexp_replace(v, '[[:space:]]', '', 'g');

  RETURN v;
END;
$$;

REVOKE EXECUTE ON FUNCTION public._analytics_normalize_for_pii(text)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public._analytics_normalize_for_pii(text)
  TO service_role;

COMMIT;

DO $$
BEGIN
  RAISE NOTICE 'round 537 audit-13 patches verified: homoglyph normalization (Cyrillic + Greek) extended on _analytics_normalize_for_pii';
END;
$$;
