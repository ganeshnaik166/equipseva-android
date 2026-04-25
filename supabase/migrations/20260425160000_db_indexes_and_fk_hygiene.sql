-- DB performance + FK hygiene.
-- (1) Composite indexes for the two hottest read paths;
-- (2) ON DELETE SET NULL on org/engineer references so deleting an org or
--     engineer preserves audit-trail rows (repair_jobs / spare_part_orders).

CREATE INDEX IF NOT EXISTS idx_spare_part_orders_buyer_created
  ON public.spare_part_orders(buyer_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_spare_parts_supplier_listing
  ON public.spare_parts(supplier_org_id, listing_type);

-- FK ON DELETE SET NULL: repair_jobs.engineer_id (already nullable)
ALTER TABLE public.repair_jobs
  DROP CONSTRAINT IF EXISTS repair_jobs_engineer_id_fkey;
ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_engineer_id_fkey
  FOREIGN KEY (engineer_id) REFERENCES public.engineers(id)
  ON DELETE SET NULL;

-- FK ON DELETE SET NULL: repair_jobs.hospital_org_id (already nullable)
ALTER TABLE public.repair_jobs
  DROP CONSTRAINT IF EXISTS repair_jobs_hospital_org_id_fkey;
ALTER TABLE public.repair_jobs
  ADD CONSTRAINT repair_jobs_hospital_org_id_fkey
  FOREIGN KEY (hospital_org_id) REFERENCES public.organizations(id)
  ON DELETE SET NULL;

-- spare_part_orders.supplier_org_id is currently NOT NULL; make it nullable
-- so we can ON DELETE SET NULL without losing buyer-side audit history.
ALTER TABLE public.spare_part_orders
  ALTER COLUMN supplier_org_id DROP NOT NULL;
ALTER TABLE public.spare_part_orders
  DROP CONSTRAINT IF EXISTS spare_part_orders_supplier_org_id_fkey;
ALTER TABLE public.spare_part_orders
  ADD CONSTRAINT spare_part_orders_supplier_org_id_fkey
  FOREIGN KEY (supplier_org_id) REFERENCES public.organizations(id)
  ON DELETE SET NULL;
