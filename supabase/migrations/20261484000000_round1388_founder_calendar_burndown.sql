BEGIN;
-- r1388 — /founder-calendar-burndown — all due-dated obligations across founder console.

DROP FUNCTION IF EXISTS public.founder_calendar_burndown_summary();
CREATE OR REPLACE FUNCTION public.founder_calendar_burndown_summary()
RETURNS TABLE (
  amc_contracts_renewal_due_30d   bigint,
  amc_contracts_renewal_due_90d   bigint,
  amc_contracts_overdue           bigint,
  vendor_contracts_expiring_30d   bigint,
  compliance_docs_renewal_due_30d bigint,
  board_meetings_scheduled_30d    bigint,
  board_action_items_due_30d      bigint,
  board_action_items_overdue      bigint,
  postmortem_actions_due_30d      bigint,
  postmortem_actions_overdue      bigint,
  hiring_target_due_30d           bigint,
  investor_followups_due_30d      bigint,
  equipment_warranties_expiring_30d bigint,
  decisions_revisit_due_30d       bigint,
  total_overdue                   bigint,
  total_due_next_30d              bigint,
  generated_at                    timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp
AS $$
DECLARE
  v_amc_30d bigint := 0; v_amc_90d bigint := 0; v_amc_overdue bigint := 0;
  v_vendor_30d bigint := 0;
  v_compliance_30d bigint := 0;
  v_board_meetings_30d bigint := 0;
  v_board_actions_30d bigint := 0; v_board_actions_overdue bigint := 0;
  v_postmortem_actions_30d bigint := 0; v_postmortem_actions_overdue bigint := 0;
  v_hiring_30d bigint := 0;
  v_investor_30d bigint := 0;
  v_equipment_30d bigint := 0;
  v_decisions_30d bigint := 0;
  v_total_overdue bigint := 0;
  v_total_due_30d bigint := 0;
BEGIN
  IF NOT public.is_founder() THEN RAISE EXCEPTION 'founder only' USING ERRCODE='42501'; END IF;

  -- amc_contracts renewal windows
  SELECT count(*) INTO v_amc_30d FROM public.amc_contracts
  WHERE status = 'active' AND end_date IS NOT NULL
    AND end_date BETWEEN current_date AND (current_date + interval '30 days')::date;

  SELECT count(*) INTO v_amc_90d FROM public.amc_contracts
  WHERE status = 'active' AND end_date IS NOT NULL
    AND end_date BETWEEN current_date AND (current_date + interval '90 days')::date;

  SELECT count(*) INTO v_amc_overdue FROM public.amc_contracts
  WHERE status = 'active' AND end_date IS NOT NULL AND end_date < current_date;

  -- vendor contracts expiring (r1369)
  BEGIN
    SELECT count(*) INTO v_vendor_30d FROM public.founder_vendor_contracts
    WHERE status NOT IN ('expired','terminated','renewed')
      AND expires_at IS NOT NULL
      AND expires_at BETWEEN current_date AND (current_date + interval '30 days')::date;
  EXCEPTION WHEN OTHERS THEN v_vendor_30d := 0; END;

  -- compliance docs renewal (r1358)
  BEGIN
    SELECT count(*) INTO v_compliance_30d FROM public.founder_compliance_documents
    WHERE status = 'active' AND valid_until IS NOT NULL
      AND valid_until BETWEEN current_date AND (current_date + interval '30 days')::date;
  EXCEPTION WHEN OTHERS THEN v_compliance_30d := 0; END;

  -- board meetings + action items (r1350)
  BEGIN
    SELECT count(*) INTO v_board_meetings_30d FROM public.founder_board_meetings
    WHERE status = 'scheduled' AND scheduled_at IS NOT NULL
      AND scheduled_at BETWEEN now() AND (now() + interval '30 days');

    SELECT count(*) INTO v_board_actions_30d FROM public.founder_board_meeting_action_items
    WHERE status IN ('open','in_progress') AND due_date IS NOT NULL
      AND due_date BETWEEN current_date AND (current_date + interval '30 days')::date;

    SELECT count(*) INTO v_board_actions_overdue FROM public.founder_board_meeting_action_items
    WHERE status IN ('open','in_progress') AND due_date IS NOT NULL
      AND due_date < current_date;
  EXCEPTION WHEN OTHERS THEN
    v_board_meetings_30d := 0; v_board_actions_30d := 0; v_board_actions_overdue := 0;
  END;

  -- postmortem action items (r1332)
  BEGIN
    SELECT count(*) INTO v_postmortem_actions_30d FROM public.founder_incident_postmortem_action_items
    WHERE status IN ('open','in_progress') AND due_date IS NOT NULL
      AND due_date BETWEEN current_date AND (current_date + interval '30 days')::date;

    SELECT count(*) INTO v_postmortem_actions_overdue FROM public.founder_incident_postmortem_action_items
    WHERE status IN ('open','in_progress') AND due_date IS NOT NULL
      AND due_date < current_date;
  EXCEPTION WHEN OTHERS THEN v_postmortem_actions_30d := 0; v_postmortem_actions_overdue := 0; END;

  -- hiring target dates (r1351)
  BEGIN
    SELECT count(*) INTO v_hiring_30d FROM public.founder_headcount_plan_roles
    WHERE status NOT IN ('hired','cancelled') AND target_filled_by IS NOT NULL
      AND target_filled_by BETWEEN current_date AND (current_date + interval '30 days')::date;
  EXCEPTION WHEN OTHERS THEN v_hiring_30d := 0; END;

  -- investor follow-ups (r1343)
  BEGIN
    SELECT count(*) INTO v_investor_30d FROM public.founder_investor_targets
    WHERE deal_status NOT IN ('passed','closed_won') AND next_followup_due_at IS NOT NULL
      AND next_followup_due_at BETWEEN current_date AND (current_date + interval '30 days')::date;
  EXCEPTION WHEN OTHERS THEN v_investor_30d := 0; END;

  -- equipment warranties (r1374)
  BEGIN
    SELECT count(*) INTO v_equipment_30d FROM public.founder_equipment_warranties
    WHERE status IN ('active','expiring_soon') AND warranty_end IS NOT NULL
      AND warranty_end BETWEEN current_date AND (current_date + interval '30 days')::date;
  EXCEPTION WHEN OTHERS THEN v_equipment_30d := 0; END;

  -- decisions revisit (r1336)
  BEGIN
    SELECT count(*) INTO v_decisions_30d FROM public.founder_decisions
    WHERE revisited_at IS NULL AND revisit_at IS NOT NULL
      AND revisit_at BETWEEN current_date AND (current_date + interval '30 days')::date;
  EXCEPTION WHEN OTHERS THEN v_decisions_30d := 0; END;

  v_total_overdue := v_amc_overdue + v_board_actions_overdue + v_postmortem_actions_overdue;
  v_total_due_30d := v_amc_30d + v_vendor_30d + v_compliance_30d + v_board_meetings_30d
                  + v_board_actions_30d + v_postmortem_actions_30d + v_hiring_30d
                  + v_investor_30d + v_equipment_30d + v_decisions_30d;

  RETURN QUERY SELECT
    v_amc_30d, v_amc_90d, v_amc_overdue,
    v_vendor_30d, v_compliance_30d,
    v_board_meetings_30d, v_board_actions_30d, v_board_actions_overdue,
    v_postmortem_actions_30d, v_postmortem_actions_overdue,
    v_hiring_30d, v_investor_30d, v_equipment_30d, v_decisions_30d,
    v_total_overdue, v_total_due_30d, now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.founder_calendar_burndown_summary() FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.founder_calendar_burndown_summary() TO authenticated;

COMMIT;
