-- Round 4: close remaining UPDATE policies missing WITH_CHECK.
-- Each ALTER POLICY copies USING into WITH_CHECK so the NEW row is validated
-- against the same ownership/membership predicate as the OLD row. Prevents
-- ownership-transfer attacks (flipping user_id / org_id / listing_id etc.).
--
-- Excluded from this migration (need product decisions first):
--   - organizations: USING (auth.uid() = created_by). Adding WITH_CHECK would
--     block legitimate ownership-transfer flows if any exist.
--   - equipment: USING (org member of organization_id). Adding WITH_CHECK would
--     block sale flows that flip organization_id to buyer org.

ALTER POLICY "amc parties update" ON public.amcs
  WITH CHECK (
    is_org_member(auth.uid(), hospital_org_id)
    OR is_org_member(auth.uid(), service_company_id)
    OR is_admin(auth.uid())
  );

ALTER POLICY "calib_svc parties update" ON public.calibration_services
  WITH CHECK (
    is_org_member(auth.uid(), organization_id)
    OR is_org_member(auth.uid(), service_provider_id)
    OR (EXISTS (
      SELECT 1 FROM engineers e
      WHERE e.id = calibration_services.engineer_id
        AND e.user_id = auth.uid()
    ))
    OR is_admin(auth.uid())
  );

ALTER POLICY "chat_conv participants update" ON public.chat_conversations
  WITH CHECK (auth.uid() = ANY (participant_user_ids));

ALTER POLICY "disputes admin update" ON public.disputes
  WITH CHECK (is_admin(auth.uid()) OR auth.uid() = raised_by_user_id);

ALTER POLICY "Engineers can update own profile" ON public.engineers
  WITH CHECK (auth.uid() = user_id);

ALTER POLICY "fin_app applicant update" ON public.financing_applications
  WITH CHECK (auth.uid() = applicant_user_id OR is_admin(auth.uid()));

ALTER POLICY "logistics_jobs parties update" ON public.logistics_jobs
  WITH CHECK (
    is_org_member(auth.uid(), requester_org_id)
    OR (EXISTS (
      SELECT 1 FROM logistics_partners lp
      WHERE lp.id = logistics_jobs.logistics_partner_id
        AND lp.user_id = auth.uid()
    ))
    OR is_admin(auth.uid())
  );

ALTER POLICY "logistics_partners owner update" ON public.logistics_partners
  WITH CHECK (auth.uid() = user_id OR is_admin(auth.uid()));

ALTER POLICY "Sellers can update listings" ON public.marketplace_listings
  WITH CHECK (auth.uid() = seller_user_id);

ALTER POLICY "txn parties update" ON public.marketplace_transactions
  WITH CHECK (
    is_org_member(auth.uid(), seller_org_id)
    OR is_org_member(auth.uid(), buyer_org_id)
    OR is_admin(auth.uid())
  );

ALTER POLICY "Users can update own notifications" ON public.notifications
  WITH CHECK (auth.uid() = user_id);

ALTER POLICY "rental parties update" ON public.rental_contracts
  WITH CHECK (
    is_org_member(auth.uid(), renter_org_id)
    OR is_org_member(auth.uid(), owner_org_id)
    OR is_admin(auth.uid())
  );

ALTER POLICY "Involved parties can update repair jobs" ON public.repair_jobs
  WITH CHECK (
    auth.uid() = hospital_user_id
    OR auth.uid() IN (
      SELECT engineers.user_id FROM engineers
      WHERE engineers.id = repair_jobs.engineer_id
    )
  );

ALTER POLICY "rfqs requester update" ON public.rfqs
  WITH CHECK (auth.uid() = requester_user_id OR is_admin(auth.uid()));

ALTER POLICY "Suppliers can update parts" ON public.spare_parts
  WITH CHECK (
    supplier_org_id IN (
      SELECT profiles.organization_id FROM profiles
      WHERE profiles.id = auth.uid()
    )
  );

ALTER POLICY "tickets owner update" ON public.support_tickets
  WITH CHECK (
    auth.uid() = user_id
    OR auth.uid() = assigned_to
    OR is_admin(auth.uid())
  );
