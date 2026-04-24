-- Round 6: close the last two UPDATE WITH_CHECK gaps deferred from Round 4.
--
-- organizations.UPDATE used `auth.uid() = created_by` with no WITH_CHECK.
-- equipment.UPDATE used org-membership on organization_id with no WITH_CHECK.
--
-- Round 4 held both pending a product call about ownership-transfer and
-- sale-org-flip flows. Audit of the Android client (no `from("organizations")`
-- or `from("equipment")` anywhere), migrations (no UPDATE statements),
-- edge functions (only Razorpay, no org/equipment writes), and database
-- functions (no pg_proc body updating these tables) confirms there is no
-- existing flow that flips created_by or organization_id. Adding WITH_CHECK
-- is therefore a pure safety net: any future transfer/sale flow will need a
-- SECURITY DEFINER server-side RPC anyway (same pattern as
-- compute_order_totals) and will bypass this policy cleanly.

ALTER POLICY "Org members can update" ON public.organizations
  WITH CHECK (auth.uid() = created_by);

ALTER POLICY "Org members can update equipment" ON public.equipment
  WITH CHECK (
    organization_id IN (
      SELECT profiles.organization_id FROM public.profiles
      WHERE profiles.id = auth.uid()
    )
  );
