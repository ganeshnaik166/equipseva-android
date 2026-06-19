BEGIN;
DROP FUNCTION IF EXISTS public.founder_bonded_parts_pipeline_summary();
CREATE OR REPLACE FUNCTION public.founder_bonded_parts_pipeline_summary()
RETURNS TABLE (
  active_suppliers          bigint,
  oem_supplier_pct          numeric,
  intake_lots_total         bigint,
  units_in_bond             bigint,
  units_dispatched_total    bigint,
  units_installed_total     bigint,
  dispatched_pending_install bigint,
  dispatched_not_installed_7d bigint,
  install_evidence_pct      numeric,
  unmatched_qr_scans        bigint,
  units_lost_total          bigint,
  intake_value_in_bond_inr  numeric
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_active_suppliers bigint;
  v_oem_suppliers bigint;
  v_intake_lots bigint;
  v_units_received bigint;
  v_units_dispatched bigint;
  v_units_installed bigint;
  v_units_lost bigint;
  v_pending_install bigint;
  v_stuck_7d bigint;
  v_unmatched bigint;
  v_value_in_bond numeric;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  SELECT count(*)::bigint INTO v_active_suppliers
    FROM public.bonded_parts_suppliers WHERE active = true;

  SELECT count(*)::bigint INTO v_oem_suppliers
    FROM public.bonded_parts_suppliers WHERE active = true AND supplier_tier = 'OEM';

  SELECT count(*)::bigint, coalesce(sum(quantity_received),0)::bigint
    INTO v_intake_lots, v_units_received
    FROM public.bonded_parts_intake;

  SELECT coalesce(sum(quantity),0)::bigint INTO v_units_dispatched
    FROM public.bonded_parts_dispatch;

  SELECT coalesce(sum(quantity),0)::bigint INTO v_units_installed
    FROM public.bonded_parts_dispatch WHERE status = 'installed';

  SELECT coalesce(sum(quantity),0)::bigint INTO v_units_lost
    FROM public.bonded_parts_dispatch WHERE status = 'lost';

  SELECT count(*)::bigint INTO v_pending_install
    FROM public.bonded_parts_dispatch WHERE status = 'dispatched';

  SELECT count(*)::bigint INTO v_stuck_7d
    FROM public.bonded_parts_dispatch
    WHERE status = 'dispatched'
      AND dispatched_at < now() - interval '7 days';

  SELECT count(*)::bigint INTO v_unmatched
    FROM public.bonded_parts_install_event WHERE qr_matched = false;

  SELECT coalesce(sum(unit_cost_rupees * quantity_received),0)::numeric
    INTO v_value_in_bond
    FROM public.bonded_parts_intake WHERE status IN ('received','in_stock');

  RETURN QUERY
  SELECT
    coalesce(v_active_suppliers, 0),
    CASE WHEN coalesce(v_active_suppliers,0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_oem_suppliers / v_active_suppliers, 1) END,
    coalesce(v_intake_lots, 0),
    GREATEST(coalesce(v_units_received,0) - coalesce(v_units_dispatched,0), 0),
    coalesce(v_units_dispatched, 0),
    coalesce(v_units_installed, 0),
    coalesce(v_pending_install, 0),
    coalesce(v_stuck_7d, 0),
    CASE WHEN coalesce(v_units_dispatched,0) = 0 THEN 0::numeric
         ELSE round(100.0 * v_units_installed / v_units_dispatched, 1) END,
    coalesce(v_unmatched, 0),
    coalesce(v_units_lost, 0),
    coalesce(v_value_in_bond, 0);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_bonded_parts_pipeline_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_bonded_parts_pipeline_summary() TO authenticated;
COMMIT;
