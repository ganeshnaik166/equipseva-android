-- Round 3757 — Enable RLS on 36 more tables (17 ships) that shipped
-- without it, found via a corpus-wide follow-up to the r3755 ops-dashboard
-- audit.
--
-- r3755 audited every migration file matching the `founder_r[0-9]+_`
-- naming pattern specifically. This round's sweep instead checked EVERY
-- table ever CREATEd anywhere in the whole migration corpus (not
-- filtered by any naming convention) for whether it ever gets
-- `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` anywhere at all. That
-- surfaced 39 candidates — including 17 ships (34 tables) that r3755's
-- file filter never even looked at, because they use a THIRD RPC-naming
-- convention (`rpc_r####_*` instead of `founder_r####_*`), plus the 2
-- `analytics_funnels` / `analytics_funnel_steps` metadata tables from an
-- unrelated, much older migration.
--
-- Of the 39, 1 (founder_payroll_batches) had a live direct grant to
-- `authenticated` and was genuinely exploitable — fixed separately and
-- immediately in r3756. The 38 tables here are NOT currently exploitable:
-- confirmed via grep that NONE of them have any GRANT to a client-facing
-- role (authenticated/anon) on the raw table — the only way in is via
-- their SECURITY DEFINER RPCs (or analytics_funnels/steps' service_role-
-- only path). Verified all 17 `rpc_r####_*` ships have exact
-- function/guard/grant count parity (34/34/34 total across the 2 tables
-- each) and spot-checked the guard pattern directly: `security definer
-- ... if not public.is_founder() then raise exception 'forbidden';
-- end if;` as the unconditional first statement, matching the r3755
-- convention exactly. This is purely closing the same defense-in-depth
-- gap as r3755 — access was never actually bypassable, but a future
-- migration that ever adds a table-level grant (as happened accidentally
-- in the r3756 case) would otherwise have nothing stopping it.
--
-- Enabling RLS only, no policies added — matches the zero-policy
-- convention used by every other ship; doesn't touch the RPCs.

BEGIN;

-- 17 ships, 34 tables (rpc_r####_* naming convention)
ALTER TABLE public.coldchain_compressor_audits_r3094 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coldchain_compressor_corrective_queue_r3094 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.vaporizer_calibration_logs_r3096 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaporizer_capa_queue_r3096 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.concentration_actions_r3097 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.concentration_customers_r3097 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dexa_phantom_capa_events_r3098 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dexa_phantom_qa_readings_r3098 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.govt_tender_bid_loss_postmortems_r3099 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.govt_tender_replay_playbook_actions_r3099 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.ot_hepa_filter_bank_r3100 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ot_hepa_particulate_readings_r3100 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.credit_facility_lines_r3101 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_facility_stress_snapshots_r3101 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.founder_diligence_readiness_workstreams_r3103 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_strategic_acquirer_targets_r3103 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.founder_health_checkup_panels_r3105 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_health_recovery_actions_r3105 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.patient_monitor_calibration_capa_r3108 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_monitor_calibration_sessions_r3108 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.esu_output_power_audits_r3110 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.esu_plate_capa_findings_r3110 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.founder_indemnity_clearance_r3117 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_statutory_clock_items_r3117 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.picu_incubator_audits_r3118 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.picu_incubator_capa_r3118 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.soda_lime_canister_audits_r3122 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.soda_lime_capa_followups_r3122 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.pump_dose_library_entries_r3124 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pump_dose_override_events_r3124 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.founder_authority_signals_r3125 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.founder_linkedin_posts_r3125 ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.phaco_tubing_sterility_audit_r3130 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.phaco_vacuum_performance_log_r3130 ENABLE ROW LEVEL SECURITY;

-- analytics funnel metadata tables (round510_analytics_event_ledger.sql) —
-- already REVOKE ALL FROM PUBLIC, anon, authenticated with GRANT only to
-- service_role, so not exploitable, but closing the RLS gap for
-- consistency with every other table in the schema.
ALTER TABLE public.analytics_funnels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.analytics_funnel_steps ENABLE ROW LEVEL SECURITY;

COMMIT;
