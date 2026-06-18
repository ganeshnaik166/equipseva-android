BEGIN;
DROP FUNCTION IF EXISTS public.founder_critical_actions();
CREATE OR REPLACE FUNCTION public.founder_critical_actions()
RETURNS TABLE (
  surface          text,
  item_id          uuid,
  item_label       text,
  amount_inr       numeric,
  created_at       timestamptz,
  age_days         int,
  severity         text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE = '42501'; END IF;

  RETURN QUERY
  (
    SELECT
      'payout'::text                                                                        AS surface,
      p.id::uuid                                                                            AS item_id,
      ('payout to ' || coalesce((SELECT full_name FROM public.profiles WHERE id = p.engineer_id), '?')) AS item_label,
      p.amount_inr::numeric                                                                 AS amount_inr,
      p.queued_at                                                                           AS created_at,
      extract(day from (now() - p.queued_at))::int                                          AS age_days,
      CASE WHEN p.queued_at < now() - interval '14 days' THEN 'critical' ELSE 'warn' END    AS severity
    FROM public.engineer_payouts p
    WHERE p.status IN ('queued','processing')
      AND p.queued_at < now() - interval '7 days'
    ORDER BY p.queued_at ASC
    LIMIT 20
  )
  UNION ALL
  (
    SELECT
      'code_red'::text,
      r.id::uuid,
      ('code red request')::text,
      NULL::numeric,
      r.created_at,
      extract(day from (now() - r.created_at))::int,
      CASE WHEN r.created_at < now() - interval '24 hours' THEN 'critical' ELSE 'warn' END
    FROM public.code_red_requests r
    WHERE r.status NOT IN ('resolved','timed_out')
      AND r.created_at < now() - interval '4 hours'
    ORDER BY r.created_at ASC
    LIMIT 20
  )
  UNION ALL
  (
    SELECT
      'spare_part'::text,
      o.id::uuid,
      ('order ' || coalesce(o.order_number, o.id::text)),
      o.total_amount::numeric,
      o.created_at,
      extract(day from (now() - o.created_at))::int,
      CASE WHEN o.created_at < now() - interval '14 days' THEN 'critical' ELSE 'warn' END
    FROM public.spare_part_orders o
    WHERE coalesce(o.payment_status,'') = 'paid'
      AND coalesce(o.order_status,'') NOT IN ('shipped','delivered','cancelled','refunded')
      AND o.created_at < now() - interval '7 days'
    ORDER BY o.created_at ASC
    LIMIT 20
  )
  UNION ALL
  (
    SELECT
      'escrow'::text,
      e.id::uuid,
      ('escrow for job ' || e.repair_job_id::text),
      e.amount::numeric,
      e.created_at,
      extract(day from (now() - e.created_at))::int,
      CASE WHEN e.created_at < now() - interval '30 days' THEN 'critical' ELSE 'warn' END
    FROM public.repair_job_escrow e
    WHERE e.status = 'held'
      AND e.created_at < now() - interval '14 days'
    ORDER BY e.created_at ASC
    LIMIT 20
  )
  ORDER BY 7 DESC, 5 ASC;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_critical_actions() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_critical_actions() TO authenticated;
COMMIT;
