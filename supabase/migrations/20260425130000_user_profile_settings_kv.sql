-- Generic per-user JSONB key/value store for the profile sub-screens.
-- Each Profile row (BankDetails, Addresses, Storefront, GST, etc.) writes to
-- one (user_id, key) pair; the value is freeform jsonb. Forms that later
-- graduate to dedicated tables can migrate their rows out without breaking
-- the schema.

CREATE TABLE IF NOT EXISTS public.user_profile_settings (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  key text NOT NULL,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, key)
);

ALTER TABLE public.user_profile_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owners read own settings" ON public.user_profile_settings;
CREATE POLICY "owners read own settings"
  ON public.user_profile_settings
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "owners insert own settings" ON public.user_profile_settings;
CREATE POLICY "owners insert own settings"
  ON public.user_profile_settings
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "owners update own settings" ON public.user_profile_settings;
CREATE POLICY "owners update own settings"
  ON public.user_profile_settings
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "owners delete own settings" ON public.user_profile_settings;
CREATE POLICY "owners delete own settings"
  ON public.user_profile_settings
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_user_profile_settings_key ON public.user_profile_settings(key);
