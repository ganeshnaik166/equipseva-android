# Sweep repairs that changed a metric definition (rounds 3796-3800)

**Status: applied to production.** Each item below is a repair that could
not be made without also changing WHAT a founder metric measures. None is a
matter of taste - in every case the original expression could not run at
all, or could never match a row. They are listed so the founder can confirm
the reading, or ask for a different one.

## Why this file exists

Rounds 3788-3795 fixed defects with a shared root cause, where the correct
repair was forced by the catalog - a cast, a corrected column name. Rounds
3796-3800 are the bespoke tail: about 115 distinct causes across 218
functions. There, a broken expression is usually broken because it points at
something that does not exist, and choosing the replacement IS a definition.

Each repair was made by one agent and then re-checked by an independent
reviewer instructed to find problems rather than to agree. Both were required
to declare any change no diagnostic had asked for. This is that declaration
list, unedited except for formatting.

## The financially material ones - read these first

A pattern worth naming, because it recurs and because static analysis CANNOT
see it. A predicate like

```sql
coalesce(payment_status::text, '') = 'paid'
```

is already cast to text, so it never raises. But `payment_status` has no
`'paid'` label - they are pending / completed / refunded / disputed / failed.
So the predicate is **permanently false**: the metric silently reports zero
instead of failing loudly. `plpgsql_check` cannot see through the cast, so
none of these appeared in any diagnostic. They were found only by reading the
enum labels alongside the code.

Consequence: these founder figures have been understated, several to a hard
zero, and now report real values. That is the fix working, not a regression -
but a number moving from 0 to a large value on a dashboard deserves warning.

* **founder_cash_conversion_cycle_summary()** - dso_days_avg_90d is redefined from 'average issue-to-settlement days for invoices settled in the last 90d' to 'average age of receivables still outstanding'. This also feeds cash_conversion_cycle_days.
  _Why:_ gst_invoices has no settlement/updated timestamp of any kind, so the original definition cannot be computed at all. The age-of-open-AR proxy is a standard DSO approximation, uses only real columns, and stays consistent with the function's own AR aging buckets — but it IS a finance-metric definition change and should be signed off (the alternative, hard-zero DSO, would understate CCC).

* **founder_cash_conversion_cycle_summary()** - Payables/AP-aging row selection changed: 'cancelled' orders are now excluded via order_status, not payment_status, and 'paid' became 'completed'.
  _Why:_ payment_status's labels are pending/completed/refunded/disputed/failed — it has no 'paid' and no 'cancelled', and coalesce(payment_status,'') was itself a latent 22P02. Cancellation only exists on order_status, so the author's stated intent ('not yet paid + not cancelled/refunded') required moving that one test to the other column.

* **founder_cash_conversion_history(p_weeks integer)** - Same two items as the summary: per-week dso_days_avg is now the receivables-age proxy (and it is measured against invoices whose status is 'issued' as of today, since historical status is not retained), and ap_open's row selection changed the same way ('completed' + order_status <> 'cancelled').
  _Why:_ Identical root causes; kept deliberately consistent with the summary RPC so the two founder screens cannot disagree.

* **founder_hospital_spend_distribution()** - Spend is measured as contracted_amount_rupees rather than actual_cost_total (both exist on repair_jobs).
  _Why:_ Column choice for a phantom column, resolved by following the existing founder_hospital_spend_30d/leaderboard convention so the spend distribution and the spend leaderboard agree. Note the sibling public.founder_hospital_leaderboard_30d still references the same phantom j.hospital_amount and is presumably broken too — outside this batch.

* **founder_investor_pulse_summary()** - METRIC-AFFECTING, not in the diagnostics: changed `coalesce(payment_status::text,'') = 'paid'` to `= 'completed'` in two places (the 30d spare-part sum and the lifetime spare-part sum).
  _Why:_ payment_status is an enum whose labels are pending/completed/refunded/disputed/failed — 'paid' does not exist, so the ::text cast made this a permanently-false predicate rather than an error. Consequence today: gmv_30d_inr, spare_parts_paid_30d_inr and ttv_lifetime_gmv_inr have all been excluding 100% of spare-part revenue on the investor pulse report. Fixing it makes three investor-facing numbers go UP. spare_part_orders is currently empty so the immediate change is 0, but it will bind as soon as orders exist. Flagging for sign-off because it silently restates investor metrics.

* **founder_cumulative_rollup_summary()** - Changed the spare-part revenue predicate from payment_status::text = 'paid' to = 'completed'. This CHANGES WHICH ROWS THE METRIC COUNTS: lifetime_parts_revenue_inr (and therefore lifetime_gmv_total_inr and avg_gmv_per_day_inr) will go from always-zero to the real paid parts revenue.
  _Why:_ No diagnostic asked for it because the comparison is on a ::text cast, which plpgsql_check cannot see through. 'paid' is not a label of the payment_status enum, so the predicate could never be true - leaving it would keep a silent financial understatement in place, exactly the failure mode the enum-literal rule warns about.

* **founder_critical_actions()** - Changed the spare-part branch predicates: payment_status::text 'paid' -> 'completed', and order_status::text NOT IN (...'refunded') -> (...'returned'). CHANGES WHICH ROWS THIS SURFACE COUNTS - the 'spare_part' rows go from never appearing to appearing for genuinely paid, non-terminal, >7-day-old orders.
  _Why:_ Neither literal is a valid label of its enum (payment_status: pending/completed/refunded/disputed/failed; order_status: placed/confirmed/shipped/delivered/cancelled/returned), so the ::text casts turned a would-be crash into a silently empty critical-actions surface. Fixing e.amount alone would have left that stuck-off.

* **founder_engineer_leaderboard_30d()** - Chose `engineer_payout` as the substitute for the non-existent `engineer_amount`, which fixes the value of the total_earnings_inr metric (and the secondary sort).
  _Why:_ repair_jobs carries several money columns (estimated_cost, actual_cost_parts/labor/total, platform_commission, engineer_payout, contracted_amount_rupees). engineer_payout is the only engineer-side earnings column and is the natural read of "total_earnings_inr" on an engineer leaderboard, but it is a judgment call about which money column the founder's leaderboard should report, so it deserves a human sign-off. Row set (completed jobs in the last 30 days) is unchanged.

* **founder_capital_efficiency_kpis()** - Also fixed a second 42702 ambiguity at the `SELECT cash_balance_rupees INTO v_cash` statement, which the diagnostics did not list.
  _Why:_ Same root cause as the reported one (OUT parameter name colliding with a column); it was masked because the function aborts at the earlier statement. Fixing only the reported line would have left the function broken.

* **run_daily_reconciliation(p_date date)** - Changed the spare-part inflow from `sum(amount_paise)/100.0` to `sum(total_amount)`, and rewrote the two-line comment above it that claimed the table 'uses amount_paise (bigint) historically'.
  _Why:_ No diagnostic asked about the comment, but leaving it would assert something false about the schema and invite the same bug back. Note the financial consequence for sign-off: this line item previously could not run at all (42703), so no figure is being restated — but `total_amount` is the order GROSS (subtotal + gst_amount + shipping_cost), which is what Razorpay actually collected and therefore the right inflow number. If the founder intends rzp_spare_part_rupees to mean merchandise net of GST/shipping, this needs a product decision and a different column.

* **run_daily_reconciliation(p_date date)** - Fixed the enum literal `payment_status = 'paid'` to 'completed' in TWO places, which changes which spare_part_orders rows both the inflow sum and anomaly-type-1 count.
  _Why:_ Required by rule 3 — payment_status is a real enum with no 'paid' label, so a ::text cast would have silently produced a wrong answer instead of a 22P02. Flagging it because it alters which rows a financial metric counts: reconciliation runs will now include completed spare-part payments that previously aborted the whole function.

* **founder_hsq_recompute_current_quarter()** - The first-response metric is now computed from the accepted bid's `created_at` because the referenced `responded_at` column does not exist on repair_job_bids.
  _Why:_ Flagging explicitly because this DOES determine a persisted metric value: `first_response_minutes_avg` written into hospital_sq_benchmark_snapshots, which in turn feeds `composite_score`, `letter_grade` and `flagged_for_review`. It is a column substitution, not a pure syntax repair, so it is a judgment call a human should confirm -- the alternative reading would be `updated_at` (when the bid was flipped to accepted), which would measure hospital decision latency rather than engineer response time and contradicts the code comment. No prior values exist to be inconsistent with, since the function has never completed.

* **founder_chains_health()** - Deleted the members-CTE predicate `WHERE coalesce(status, 'active') = 'active'` outright rather than substituting an equivalent, which widens the rows behind member_count, amc_pct and jobs_completed_30d to ALL hospital_chain_memberships rows.
  _Why:_ The column does not exist, so nothing can be substituted -- there is no status, left_at, is_active or ended_at on that table, and the function currently returns no rows at all. Treating every membership as live is the only reading consistent with the author's coalesce-to-'active' default, but it is still a judgement about what a founder-facing metric counts, so it should be signed off (and if chains ever need a leave/suspend concept, that is a schema change, not this fix).

* **sweep_amc_sla_unresponded_visits()** - Replaced the severity DECISION RULE, not just the column name: it now classifies a visit as emergency from the contract's equipment_categories (&& ARRAY['emergency','life_support']) instead of from 'has the critical target already been exceeded'. This alters which visits are recorded as SLA breaches and the goodwill-credit amounts issued.
  _Why:_ FINANCIAL IMPACT -- flagging for sign-off. The literal minimal fix (response_time_critical_hours -> response_time_emergency_hours, keeping the elapsed>target test as the severity selector) is actively wrong: it would set v_target_hours to the 4h emergency default for ANY contract merely past 4h, so the subsequent `IF v_elapsed_hours <= v_target_hours THEN CONTINUE` guard would pass and the sweep would write breach rows plus 25%-of-visit-cost credits for visits that had not missed their own 24h standard SLA. The chosen rule is the one the function's own comment declares it mirrors ('Same severity branching as check_amc_sla_on_visit_status_change') and is copied verbatim from that live trigger, so the sweep and the trigger can no longer disagree about the same visit.

## Other changes no diagnostic asked for

Most of these are the same story in a different shape: one bug masked
another in the same statement, so fixing only what was reported would have
left the function broken with a fresh error. A few are genuine judgment
calls about which real column a phantom one meant, and those are the ones to
look at.

* **founder_onboarding_velocity_summary()** - Changed p.role = 'hospital' to 'hospital_admin' (hosp_cohort) and IN ('engineer','hospital') to IN ('engineer','hospital_admin') (signups_30d). No diagnostic mentioned this.
  _Why:_ The reported 42703 aborted plpgsql_check's analysis of the single big RETURN QUERY before it reached these literals; 'hospital' is not a user_role label, so fixing only the reported error would have left the function dying with 22P02. This changes which rows six hospital-side metrics count (from 'crashes' to 'counts hospital_admin profiles').

* **founder_onboarding_velocity_summary()** - eng_median_signup_to_verified_h and eng_p90_signup_to_verified_h will now always report 0.
  _Why:_ No engineer verification-approval timestamp exists in the schema, so the latency is genuinely unmeasurable. I chose an empty CTE (0 = the function's existing no-data sentinel) over a fabricated number. A real fix needs a schema change: add engineers.verified_at and set it in admin_set_engineer_verification().

* **founder_verified_engineers_recent()** - The report's population changed from 'engineers verified in the last 30 days' to 'verified engineers who signed up in the last 30 days', the verified_at output column now carries the signup timestamp, and signup_to_verified_days is hard-coded 0.
  _Why:_ Same missing column. This follows the substitution admin_inactive_engineers already uses (e.created_at AS verified_at), but a founder reading the verified_at column will be seeing a signup date, so it wants explicit sign-off — or the engineers.verified_at schema change.

* **founder_amc_amount_histogram()** - The histogram's 'amount' is now explicitly the MONTHLY fee, not an annualised contract value.
  _Why:_ monthly_fee_rupees is the only rupee amount on amc_contracts, so I did not invent x12 arithmetic. Worth confirming the bucket ladder (<5k ... >5L) was meant for monthly fees; live fees currently range 1.00-5000.00, which all land in the first two buckets.

* **founder_culture_deck_summary()** - METRIC-AFFECTING: team_total / pct_signed now count `role IN ('admin','engineer')` instead of `IN ('founder','admin','engineer')`.
  _Why:_ Unavoidable — the query could not run at all with the invalid label. But note the founder is now not counted in the denominator, and live profiles data has 28 engineer / 15 hospital_admin / 1 manufacturer and ZERO 'admin' rows, so team_total resolves to the engineer headcount. If the intent was 'every internal person including me', that needs a product decision about how is_founder() identity joins to profiles — I did not invent one.

* **founder_kyc_pending_detail()** - Added `::text` to e.verification_status in the select list — no diagnostic asked for this.
  _Why:_ It is a masked 42804: RETURNS declares that column as text, the query returned the raw enum, and enum->text is not binary-coercible, so the function would still have failed after the enum-literal fix. Zero effect on returned values (the text of a label is the label). Also note the WHERE list lost 'in_review', so the result set is pending+rejected only.

* **founder_marketing_content_pieces_recent(), public.founder_marketing_content_upcoming()** - Only `p.title` was diagnosed; I also remapped content_type -> topic_category, scheduled_for -> planned_publish_date, and (pieces_recent only) estimated_views -> expected_reach_count.
  _Why:_ Those three were masked 42703s in the same RETURN QUERY and the functions cannot run without them. The mapping is mechanical for planned_publish_date and expected_reach_count, but `content_type -> topic_category` is a judgment call: the table has no content-type column, `channel` is already returned separately, and topic_category is the only remaining descriptive text field. Worth a glance to confirm the console column header 'content type' should be showing a topic.

* **founder_regional_state_summary() and public.founder_regional_city_summary()** - Structural rewrite: temp table replaced by an inline CTE, and v_total_jobs_30d now computed by a direct count over repair_jobs joined to the geography source instead of sum(jobs_30d) over the temp table. The returned numbers are intended to be identical.
  _Why:_ Forced by the 0A000 diagnostic: CREATE TEMP TABLE AS cannot run in a STABLE function and rule 1 forbids changing the volatility, so there is no in-place fix. The derived total is equivalent by construction (one geography row per job; the rollup excludes only the '(unknown)' bucket), but it is a rewrite of a metric's computation and worth a human eye - especially the case where a job's hospital profile is missing entirely (NULL state -> '(unknown)'), which both the old and new code exclude from total_jobs_30d and report separately as unknown_*_jobs_30d.

* **founder_cron_status_summary() and public.founder_cron_jobs_recent(p_limit integer)** - Behaviour change: instead of raising 42P01, these now report zero cron jobs / an empty job list when pg_cron is absent. Both are all-metric changes, so the whole surface goes from erroring to reading as 'nothing scheduled'.
  _Why:_ pg_cron is genuinely not installed (verified: no extension, no cron schema, 0 relations), so no column-level fix exists and the functions are 100% dead today. Degrading matches the pattern the founder cockpit function already uses for the same tables. Flagging it because a founder reading '0 jobs, 0 failures, 0% failure rate' could read it as 'cron is healthy' rather than 'cron is not installed' - if that is unacceptable, the alternative product decisions are to install pg_cron or to drop these two console tiles.

* **founder_sales_territory_by_pincode / public.founder_sales_territory_by_city** - Chose public.engineer_job_acceptance_latency_r1976 as the source of truth for accepted_at, and added a LEFT JOIN LATERAL to reach it (a structural addition, not a column rename).
  _Why:_ repair_jobs simply has no acceptance/assignment timestamp, so the diagnostic could not be fixed by renaming a column. That table is the only per-job acceptance record in the schema (repair_job_id + offered_at + accepted_at + latency_minutes + response_type), so it is the intended source. I deliberately rejected substituting rj.started_at, which would have silently redefined 'minutes to response' into 'minutes to work start'. Needs a human nod on two points: (a) that this table is the right source, and (b) that it is actually being populated - pg_class.reltuples is -1 (never analyzed) so I could not tell. If it is empty, avg_minutes_to_response will read 0 via the existing coalesce, i.e. the same value the column would have shown anyway; the other 8 columns are correct regardless.

* **founder_signups_by_role_30d** - Redefined the buyer_signups bucket to read profiles.roles[] / profiles.active_role instead of the enum role column, and excluded that same predicate from other_signups.
  _Why:_ No diagnostic asked for a new data source, but 'buyer' is not a user_role label and (verified live) is not a value anywhere in profiles, so there was no correct enum literal to re-derive. This does change which rows the buyer and other metrics count relative to the author's intent: buyer_signups is 0 for every live row today, and other_signups now means 'role is neither engineer nor hospital_admin' (i.e. manufacturer/supplier/logistics/admin). If the founder would rather see buyer_signups hard-wired to 0, or wants buyers defined off buyer_kyc_status, that is a product call - I did not assume buyer_kyc_status implies a buyer, since it may well be defaulted for everyone.

* **founder_compliance_calendar_auto_seed_year** - No behavioural change beyond the column renames, but calling out that this fix un-silences a dormant code path.
  _Why:_ The renewals INSERT was being swallowed by the surrounding undefined_column handler, so it had never inserted a row. Once the column names are right it will start seeding 'Renewal: ...' events for every founder_compliance_documents row with a future renewal_due_date. That is the documented intent of the block, but it is the first time it will actually write, so a human should expect new calendar rows on the next run.

* **rpc_r2377_current_week_status()** - Qualified `target_conversations`, `target_family` and `target_non_work_minutes` as `t.<col>` even though the only diagnostic named `week_start`.
  _Why:_ Each is simultaneously an OUT parameter and a column of founder_outside_weekly_targets_r2377, so each `(SELECT target_x FROM t)` is the same 42702 the diagnostic reported — plpgsql_check stopped after the first one. Leaving them would just move the error. Values and fallbacks are unchanged.

* **founder_cap_conversion_preview(p_round_id uuid)** - Added an explicit `::text` to the price_source CASE (`... ELSE 'new_price' END::text AS price_source`).
  _Why:_ Not requested by any diagnostic. PostgreSQL already resolves an all-unknown-literal CASE to text, so this is a no-op at runtime; it just makes the RETURN QUERY column type match the declared `price_source text` unambiguously now that the statement can actually be planned for the first time. Revert freely if you prefer strict minimality.

* **founder_tier_progression_rate()** - Renamed `h.user_id` → `h.engineer_user_id AS user_id`, a second column fix the diagnostics did not list.
  _Why:_ The diagnostic only reported `h.old_tier` because both errors are in the same CTE and the first masks the second; engineer_tier_history has no `user_id` column at all, so fixing only `old_tier` would have left the function broken with a fresh 42703. Flagging it because it is an extra column substitution beyond the stated diagnostic — the metric still counts DISTINCT engineers per window, just via the correct column.

* **engagement_distribution_r1799()** - Restructured the query into a CTE and added `bucket_ord` as a second GROUP BY key.
  _Why:_ The ORDER BY could not be repaired in place without either re-deriving the bucket order from the text label (which sorts critical/high/low/medium — wrong) or duplicating the whole CASE inside a nested CASE. bucket_ord is a deterministic 1:1 function of bucket, so the extra GROUP BY key cannot split or add groups — the row count and the four bucket rows are identical to the intended output.

* **founder_culture_deck_version_timeline()** - Restructured the query into a CTE (`v`) and renamed the base-table alias to `ver`, rather than a one-token fix.
  _Why:_ PostgreSQL structurally refuses to match a non-Var GROUP BY expression inside a sub-select, so the grouping key had to become a plain column reference for the two correlated signature counts to be legal. The 180-day filter, DISTINCT version count, new-hire split, DESC ordering and LIMIT 26 are preserved exactly, so the rows and numbers are unchanged.

* **build_pved(p_repair_job_id uuid)** - The dossier's `verified_at` will now always be NULL instead of carrying a verification date.
  _Why:_ No engineer-verification timestamp exists anywhere in the schema, so there is nothing truthful to write. NULL restores the dead feature without fabricating a date; the honest alternatives are a schema change (add engineers.verification_status_updated_at and backfill) or leaving the whole pre-visit dossier flow broken. Sign-off needed on whether hospitals seeing a blank 'verified on' is acceptable in the interim, and separately note that the dossier's police_verification_at / police_verification_ref columns are also never populated by this INSERT (pre-existing, no diagnostic, left alone).

* **open_code_red_request(...)** - Chose `organizations.latitude/longitude` (reached via profiles.organization_id) as the hospital coordinate source.
  _Why:_ No diagnostic named a replacement and profiles has no coords. This choice decides WHICH three engineers get paged for a Code Red, so it is a real product-visible ranking input. The other candidates I rejected were user_addresses (multiple rows per user; would need an is_default tie-break and a policy on which address counts) and hospital_service_geo_locations_r1831. organizations matched the code's own 'coarse look-up' comment and is single-valued. Nothing regressed by picking it -- the function raised 42703 on every call before -- but the distance ranking is now org-address accuracy, not site accuracy.

* **open_code_red_request(...)** - Also fixed the specializations COALESCE/enum-array type mismatch, which no diagnostic listed.
  _Why:_ It was masked by the reported p.latitude error in the same statement (target list is transformed before WHERE). Left unfixed, the function would still have failed -- 42804 instead of 42703 -- so this is the one-bug-masks-the-next case, not an improvement.

* **fading_skills_r1844()** - Restructured the GROUP BY query into a LEFT JOIN against a pre-aggregated derived table rather than just moving the predicate to HAVING.
  _Why:_ Both fix the 42803, but HAVING would have relied on PostgreSQL's PK functional-dependency inference to keep s.skill_name/s.status legal against `GROUP BY s.id, p.email`, and the masking error meant I could not confirm from the diagnostics that id really is the PK. The derived-table form needs no such assumption. Result set, ordering and LIMIT are provably identical -- one row per skill either way.

* **founder_cert_engineer_leaderboard()** - Read `latest_cert_at` as `max(c.issued_on)` rather than `max(c.expires_on)`.
  _Why:_ The dead column was named `acquired_on`, so issued_on is the direct synonym and the leaderboard reads as most-certified engineers with their most recent certification. Flagging it only because it is a semantic choice between the table's two date columns, and it changes what that column reports.

* **run_daily_reconciliation(p_date date)** - Kept the jsonb key literally named 'event_kind' while sourcing its value from the real column `e.event_type`.
  _Why:_ The details payload is a stored output contract read by the founder console; renaming the key could break a consumer, so I fixed the column reference only. If the reader would rather the key match the column, that is a one-word follow-up.

* **founder_dispute_queue(p_limit integer)** - Replaced `ORDER BY coalesce(p.earliest_pack_at, e.repair_job_id::text::timestamptz) ASC NULLS LAST` with `ORDER BY p.earliest_pack_at ASC NULLS LAST` -- the coalesce fallback is deleted, not repaired.
  _Why:_ `e.repair_job_id` is a uuid; casting its text form to timestamptz raises 22007 (invalid input syntax) for every row it is evaluated on. COALESCE evaluates its second argument whenever the first is NULL, i.e. for any disputed escrow that has no submitted evidence pack yet -- exactly the rows a dispute queue exists to show -- so the function would still have died at runtime after the max(uuid) fix. plpgsql_check cannot see this class (it is a runtime cast failure, not a catalog error). The clause already ended in NULLS LAST, so the fallback was redundant even in intent. NOTE FOR SIGN-OFF: this can change WHICH rows survive `LIMIT greatest(coalesce(p_limit,50),1)` -- escrows with no pack now sort last and can be truncated. It does not change which rows the query selects, and there is no prior behaviour to regress against because the old ordering expression could only crash.

* **founder_hsq_recompute_current_quarter()** - Added `#variable_conflict use_column` as the first line of the function body (before DECLARE).
  _Why:_ A masked second bug the 42P01 hid. Plain column names in `ON CONFLICT (hospital_org_id, quarter_label)` are re-parsed as ColumnRefs through plpgsql's column-ref hooks, and `quarter_label` is also a RETURNS TABLE OUT parameter -- so once the missing-relation error stops aborting parse analysis, that clause raises 42702 and the function is still dead. The OUT parameter cannot be renamed (byte-for-byte header rule) and `ON CONFLICT ON CONSTRAINT` would depend on the index actually being constraint-backed, which I could not confirm. The pragma is the pattern already used widely in this database. I verified it is inert for every other reference in this function: the only variables are v_q, v_start, v_end, v_count, v_actor_email (no column of any referenced table shares those names, so they still resolve as variables), and neither OUT parameter is ever read or assigned inside a query.

* **founder_funnel_drop_off()** - Stage iteration order is now guaranteed by `ORDER BY s.ord` on the loop query.
  _Why:_ Side effect of removing the temp table. The original inserted rows with ORDER BY s.ord but then read them back via a bare `SELECT * FROM _stages` with no ORDER BY, so heap order was incidental. Since the function's whole output is consecutive-stage pairs built from a running lag, the loop order decides which stage pairs with which -- it is now deterministically first_touch -> demo_booked -> ... -> first_amc, which is plainly the intent. The set of rows counted is unchanged (same VALUES list, same LEFT JOIN, same COUNT DISTINCT).

* **r2276_kpis()** - Moved the misplaced FROM public.customer_payment_mode_switches_r2276 from the outer query into the switches subquery, so switches_last_90d is now a genuine COUNT(*) FILTER (WHERE s.switched_at > now() - interval '90 days') over that table.
  _Why:_ No diagnostic asked for this -- plpgsql_check aborted the statement on the avg_settlement_hours ambiguity first. But with only the ambiguity fixed the function would still fail: the select list had 5 columns against a 6-column RETURNS TABLE, because the switches table and the final AVG subquery were being parsed as outer FROM items. This change DOES alter which rows the switches_last_90d metric counts (previously it was a correlated aggregate over a no-FROM subselect, i.e. meaningless), so it needs a human sign-off that '90-day switch count over customer_payment_mode_switches_r2276' is the intended metric. Nothing else about the function's row scope changed.

* **rpc_r2888_kpi_summary()** - Also qualified SUM(projected_ltv_uplift_rupees) as SUM(o2.projected_ltv_uplift_rupees) on the last line.
  _Why:_ Not in the diagnostics -- it is a second instance of the same OUT-parameter/column collision that plpgsql_check could not see because it stops at the first error in a statement. Without it the function would still raise 42702 on the next run. No change to which rows are counted (the offer_status IN ('signed','pending') predicate is untouched).

* **sweep_amc_sla_unresponded_visits()** - Changed the severity literal 'critical' -> 'emergency'. No diagnostic asked for this.
  _Why:_ amc_sla_breaches.severity is CHECK (severity IN ('emergency','standard')). plpgsql_check cannot see a CHECK constraint, so had I only renamed the column the function would still have failed on every row with 23514 -- and invisibly, since the loop's WHEN OTHERS handler downgrades it to a NOTICE and the sweep would have kept returning 0 while looking healthy.

* **founder_ownership_at_risk_amcs()** - Chose `effective_date` (not `detected_at`) as the replacement for the non-existent `occurred_on`, and `event_type` as the replacement for `change_kind`. This is an inference, not something a diagnostic named, and it decides which rows the report returns: the 90-day window and the DESC ordering now run on the ownership change's effective date rather than the date EquipSeva detected it.
  _Why:_ hospital_ownership_events has both `effective_date date` and `detected_at timestamptz`. The OUT parameter is declared `occurred_on date`, and only effective_date is a date, so it is the type-compatible and semantically closer match (when the change occurred, vs when we noticed). Worth a founder sign-off if the intended report is really a detection-recency feed.

* **founder_amc_pool_coverage()** - Also qualified `ord` as `t.ord` in the select list and ORDER BY, although the diagnostic only named `cnt`.
  _Why:_ `ord` is likewise a RETURNS TABLE OUT parameter colliding with a column of the same derived table, so it is a second instance of the exact reported error class. plpgsql_check aborts a statement at the first resolution failure, so it could not report it; fixing only `cnt` would leave the function still raising 42702.

* **record_tds_for_payout(p_payout_id uuid)** - Updated one comment line from "fall back to now() if dispatched_at missing" to "...if processed_at missing".
  _Why:_ Cosmetic only, so the comment does not name a column that does not exist. No effect on behavior.

* **founder_vendor_sla_kpis()** - total_vendors now counts distinct public.spare_part_orders.supplier_org_id instead of rows of organizations. This CHANGES WHICH ROWS THE METRIC COUNTS and needs a human sign-off.
  _Why:_ The old predicate was unfixable as written: organizations has no `kind` column and org_type has no 'vendor' label, so there is no vendor flag on organizations at all (live data: all 3 organizations are type 'hospital'). Per rule 3 the literal had to be re-derived rather than cast. I took the definition the platform already uses for the same concept (r1429 founder_vendor_quality_scorecard: 'vendors = distinct supplier_org_id') instead of inventing an org_type set such as manufacturer/distributor. Both the old and new metric evaluate to 0 on today's data (0 spare-part suppliers, 0 rows in vendor_sla_scorecards_v2), so nothing visible changes now; if the founder means something else by total_vendors (e.g. all supply-side org types, or all vendors ever scored), that one sub-SELECT is the only line to swap.

* **founder_vendor_sla_kpis()** - Fixed a second bug no diagnostic listed: unqualified sum(total_value_rupees) -> sum(cur.total_value_rupees).
  _Why:_ plpgsql_check reports only the first error per statement, so this 42702 was masked by the `kind` error and the function would still have been dead after fixing only what was reported.

* **founder_morning_digest_v2()** - Fixed a second phantom column no diagnostic listed (cr.minutes_open -> derived from cr.created_at), and chose the composition of the replacement title label (brand + model, falling back to equipment_type, then the literal 'Code Red').
  _Why:_ minutes_open does not exist on code_red_requests, so the function stayed broken if only equipment_label were fixed. The label composition is a judgment call - there is no single column that reproduces the intended 'equipment_label', so I built the closest human-readable equivalent from the columns that do exist; swap in cr.equipment_type alone if the founder prefers the bare category.

* **log_founder_capv2_simulate_round(text, text, numeric, numeric, numeric)** - Founder/employee pre-round % is now DERIVED from shares_count / total shares rather than read from a stored percentage column, and returns 0 (not NULL) when the cap table is empty or holds 0 total shares.
  _Why:_ No share_pct column exists, so the value must be computed; shares_count is the only ownership quantity on the table. The 0-fallback avoids replacing the 42703 crash with a NULL-propagating (or division-by-zero) result that would write NULL dilution figures into founder_cap_table_dilution_scenarios. Note the cap table is currently EMPTY in prod, so this cannot be validated against real numbers yet - worth a founder eyeball once shareholders are loaded. I deliberately did NOT populate the table's projected_dilution_pct column, which the function computes and returns in JSON but has always left NULL on insert: it is nullable, so it is not a crash, and filling it would be an unrequested data-behaviour change.

* **founder_okr_team_health_r2345(text)** - GROUP BY changed from COALESCE(t.team_name,'(unassigned)') to t.team_name.
  _Why:_ Required to make the correlated sub-SELECT legal. Behaviour is identical unless a real team is literally named '(unassigned)', in which case that team would now form its own row instead of merging with the NULL-team row - which is arguably more correct, but flagging it since it technically alters grouping.

* **monthly_feedback_trend_r2602()** - Restructured the single grouped query into two CTEs plus a LEFT JOIN.
  _Why:_ Rule 7 prefers a minimal cast/rename, but this 42803 has no minimal form: the grouping key must stay the month expression, and PostgreSQL will not let a sub-SELECT reference it. Counts, casts, zero-fill and ordering are preserved one-for-one.

* **founder_tier_1_home_metadata()** - cron_failure_rate_24h_pct now degrades to 0 when the cron schema is absent, instead of the whole function raising 42P01.
  _Why:_ pg_cron is not installed, so no other outcome is available without a schema change; this matches the established convention already live in founder_morning_digest_v2 (and the per-metric EXCEPTION handlers in the cockpit functions). Consequence to note: the metric reads 0 rather than erroring, so a reader cannot distinguish 'no cron failures' from 'no cron'.

* **exec_360_v3_compliance_kpis()** - Repointed the dpdp_grievances_open KPI from public.founder_priority_actions to public.dpdp_grievances (status IN ('open','in_review')). This changes which rows the metric counts — it is a different table, not a column rename.
  _Why:_ founder_priority_actions has no `category` column at all, and its action_taken is NOT NULL, so ANY same-table repair (item_kind or source_domain = 'dpdp_grievance' AND action_taken IS NULL) would have returned a permanent 0 — a silent wrong answer on a DPDP compliance tile with ~Rs250 Cr penalty exposure. dpdp_grievances is the actual grievance table (r485) and I used the exact predicate r499 and r1199 already use, so the founder console stays internally consistent. If the founder in fact wanted "grievance items I have not yet acked", that needs the priority-queue read model, not this log table, and should be a deliberate product call.

* **founder_repair_types_snapshot_summary()** - Mapped the invalid urgency literal 'high' to 'same_day', which determines which rows urgency_high_90d counts.
  _Why:_ job_urgency has no 'high' label so the old value could only ever raise 22P02, and rule 3 forbids fixing it with a cast. 'same_day' is the only defensible reading (it is the tier between 'emergency', already counted in the sibling column, and 'scheduled'), but the label on the founder screen still says "high", so a human should confirm that same-day is the intended bucket or rename the KPI.

* **founder_week_in_review_summary()** - Changed the churn predicate from `status = 'churned'` to `status IN ('cancelled','expired','renewal_failed')` in both places it appears (amcs_churned_count and the amc_net_new subtraction). This alters which rows those two metrics count.
  _Why:_ No diagnostic asked for it (status is plain text, so plpgsql_check cannot see it), but I verified the LIVE CHECK constraint on amc_contracts.status allows only pending_payment/active/paused/expired/cancelled/renewal_failed — 'churned' is impossible, so churn would have read a hard 0 and net-new would have overstated growth by the entire week's churn. Since the function was previously failing loudly, shipping it with a constant-0 churn line would have converted a crash into a silent misstatement in the founder's weekly review. My definition is "terminated in the window", still gated by the existing deactivated_at::date filter; the exact churn definition is a founder call and worth signing off.

* **founder_week_in_review_summary()** - For refunds_issued_rupees I resolved the nonexistent payments.amount_rupees to `amount` rather than to the existing `refund_amount` column.
  _Why:_ It keeps the row identical in shape to its sibling captured-rupees line, which is what the author wrote. Note the trade-off: with status='refunded' this sums the full original payment, so partial refunds are overstated; `sum(coalesce(refund_amount, amount))` would be more precise but adds logic no diagnostic asked for. Flagging so a human can pick.

* **founder_eef_v2_ack_cliff_alert(p_alert_id uuid, p_note text)** - Inlined the audit-log write instead of calling the missing helper, and populated target_table/target_row_id (which the original helper left NULL) plus a COALESCE fallback for actor_email.
  _Why:_ I can only emit one CREATE OR REPLACE for the function under repair, so I could not create the missing log_founder_eef_v2_ack helper; inlining preserves the audit trail exactly (same op_name, same payload) instead of dropping it. The two extra columns are nullable, so this only enriches the log; the actor_email COALESCE exists because that column is NOT NULL. If you would rather re-create the r1505 helper and keep the PERFORM, that is a clean alternative — note pg_proc also shows log_founder_eef_v2_recompute live as (p_count integer), not the migration's (integer, date), so that whole helper set looks partially applied and may deserve its own look.

* **owner_load_r2579()** - Added parentheses around the two COUNT(*) FILTER (...) expressions before their ::bigint casts, i.e. (COUNT(*) FILTER (WHERE ...))::bigint instead of COUNT(*) FILTER (WHERE ...)::bigint.
  _Why:_ Purely cosmetic/defensive readability while the statement was being restructured; count() already returns bigint so the cast is a no-op either way and the parse is identical. No effect on results — flagging it only because no diagnostic asked for it.

* **owner_load_r2579()** - open_touches is now computed once per output row from the outer (ungrouped) query rather than once per group inside the grouped query.
  _Why:_ This is the mechanism of the 42803 fix, not a behaviour change: the subquery's only input was the group key, so it produced exactly one value per group before and produces exactly the same value per row now. Noting it because the execution shape (one correlated subplan per result row) differs from the original even though the answer does not. Confirmed identical-looking output against live data: founder@equipseva.in 1 open touch, cofounder@equipseva.in 1 open touch.

## Declined outright - NOT repaired, deliberately

A correct refusal beats a guess. Each of these would have required inventing
data or a schema change.

* **founder_kyc_pipeline_snapshot_summary()**
  The reported 22P02 ('in_review' is not a verification_status label) is trivially fixable, but it MASKS an unfixable 42703: the function reads `engineers.verified_at` twice (engineer_verified_today, engineer_verified_30d) and that column does not exist. Confirmed with two catalog queries that engineers has NO verification timestamp at all (only aadhaar_verified, verification_status, verification_notes, police_verification_at/_ref) and that no table in public records engineer verification_status transitions. Rejected every candidate substitute: updated_at is bumped by any row edit (would silently mis-state a KYC-throughput KPI in both directions); police_verification_at is a different control; engineer_kyc_renewals.completed_at is re-KYC, which this same function already reports separately, so reusing it would double-count. Dropping the two output columns would change the declared RETURNS type (forbidden), and hard-coding 0/NULL is a product decision. Since a single RETURN QUERY fails atomically, a partial fix would just change the failure mode 22P02->42703 while looking repaired — so no .sql was written. The SKIP.md carries the one-column ALTER TABLE needed (plus the fact that whatever admin path sets verification_status='verified' must also stamp it, or the metrics stay 0), and the complete corrected body ready to apply the moment that column exists; the other 18 metrics are sound.

* **founder_calendar_burndown_summary()**
  FALSE POSITIVE plus a product decision. The missing relation `public.founder_equipment_warranties` is referenced inside its own `BEGIN ... EXCEPTION WHEN OTHERS THEN v_equipment_30d := 0; END` block; plpgsql plans lazily, so the 42P01 is raised at execution time and caught, degrading that one metric to 0 while the function still returns all 17 columns -- the same guarded-with-working-fallback pattern already calibrated as a false positive (the cron.job cockpit case). Nine of the ten optional feeds here use that shape by design. It also cannot simply be repointed: no founder_*warrant* relation exists at all, and the nearest live candidates (customer_equipment_warranties_r2488, customer_warranty_renewals_r2620) are hospital-owned registers whose date column is `warranty_end_date` (not `warranty_end`) and whose status labels are not confirmed to include 'active'/'expiring_soon' -- so swapping one in would change what equipment_warranties_expiring_30d means AND silently move total_due_next_30d, a headline founder number, off 0. Needs either the r1374 table created or a founder ruling on which register the KPI tracks. I did verify the rest of the function is sound: the three unguarded amc_contracts counts type-check, RETURN QUERY is 17 values against 17 declared columns, and no unqualified column collides with an OUT parameter. Full write-up in founder_calendar_burndown_summary.SKIP.md.

* **delete_my_account(p_reason text)**
  FALSE POSITIVE. storage.delete_object() really is absent, but all four call sites (definition lines 65, 81, 97, 115) are individually wrapped in `BEGIN ... EXCEPTION WHEN undefined_function OR undefined_object THEN DELETE FROM storage.objects ...`. PL/pgSQL parses a PERFORM at execution time, so the 42883 is raised inside the block and caught, and each object is purged by the fallback delete instead; there is also a belt-and-braces sweep at lines 185-187. Matches the recorded per-SQLSTATE calibration for this project (wrapped 42883 = false positive). Rewriting it would be behaviour-neutral today while removing the forward-compatible path that would also purge the S3 object once Supabase ships the function -- not worth touching on a destructive DPDP-facing path. Detail in delete_my_account.SKIP.md.

* **founder_eng360_submit(uuid, text, numeric, text)**
  Unfixable without a signature change AND a product decision. The INSERT names four columns that never existed (subject_engineer_user_id, score, comment, submitted_by). Root cause found in the repo: migration 20261546000000_round1449 created a correct 11-arg version, then 20261567000000_round1470's 'audit fix sweep' dropped every overload by name and recreated it as this 4-arg stub against invented column names. (1) HARD RULE 1 blocks the real fix -- CREATE OR REPLACE of the 11-arg original would add a second overload and leave the broken one live; it needs an explicit DROP. (2) The table requires five separate NOT NULL smallint dimension scores each CHECK BETWEEN 1 AND 5, while the stub offers one p_score of unstated scale; fanning it across all five would fabricate ratings nobody gave, break the CHECK for any 0-10/0-100 caller, and defeat composite_score, which is DERIVED from the five -- a silent-wrong-answer outcome, not a fix. (3) p_subject_engineer_user_id is a user id whereas engineer_id is FK'd to engineers(id). No client calls this RPC (the only console page is read-only; nothing in the Android app), so the DROP + restore is safe whenever the founder signs it off. Full recipe in founder_eng360_submit.SKIP.md.

* **schedule_engineer_kyc_renewals()**
  Needs a schema change, not a function fix. public.engineers has NO column recording when verification status last changed — I swept the whole public schema for any column matching %verif% and any table matching %verif%/%kyc%, and grepped every migration: verification_status_updated_at was never added anywhere. It is a phantom column referenced by FIVE sites across two shipped features (this scheduler reads it; founder_complete_kyc_renewal:278 and reap_expired_kyc_renewals:328 both WRITE it; round493's pre-visit dossier issuer:213 reads it into pre_visit_engineer_dossiers.verified_at) — one ALTER TABLE fixes all five, whereas five per-function proxies would each invent a different 'last verified at'. Every proxy I considered is either wrong or dangerous: e.updated_at is bumped by any profile edit so the anniversary never arrives (silent 0 forever); e.created_at — and the COALESCE(last completed renewal, created_at) reconstruction, which degenerates to created_at because no renewal has ever completed — would hand every engineer onboarded >379 days ago a renewal row whose due_at AND grace_until are already in the past, so reap_expired_kyc_renewals (a declared daily job per docs/CRON_SCHEDULING_GAP.md) would expire it on its next run and flip verification_status to 'pending', mass-de-verifying the long-tenured engineer base and hiding them from the hospital directory with zero notice. Making that safe needs a due_at floor (e.g. GREATEST(..., now() + 30 days)) = a product/policy decision, so I escalated instead of guessing. SKIP file gives the recommended ALTER TABLE + the safe backfill (stamp now() for currently-verified engineers, NOT created_at) + the note that the function body then needs no change at all: every other reference checks out, 'verified' is a valid verification_status label, and the INSERT already supplies all NOT NULL non-defaulted columns so there is no hidden 23502 behind the 42703.

* **founder_team_comp_summary / _benchmarks_list / _employee_deltas /
  _submit_raise** - all four read `profiles.role_title`, `profiles.level` and
  `profiles.annual_comp_rupees`, none of which exist. A team-compensation
  feature with no backing schema, so there is nothing to repair in code.

## The single highest-value schema fix

Several independent refusals above converge on ONE missing column:
**`engineers` has no timestamp recording when verification status last
changed.** It is referenced as `verified_at` or
`verification_status_updated_at` by at least five sites across two shipped
features - `schedule_engineer_kyc_renewals` reads it,
`founder_complete_kyc_renewal` and `reap_expired_kyc_renewals` both WRITE it,
round493's pre-visit dossier issuer reads it, and
`founder_onboarding_velocity_summary`, `founder_verified_engineers_recent`
and `founder_kyc_pipeline_snapshot_summary` all want it for latency metrics.

One `ALTER TABLE` fixes all of them coherently. Five per-function proxies
would each invent a different "last verified at" - and one of those proxies
is actively dangerous: backfilling from `created_at` would hand every
engineer onboarded more than 379 days ago a renewal row already past its
grace window, so the daily reaper would flip them to
`verification_status = 'pending'` and drop them out of the hospital directory
with no notice.

**Recommended:** add the column, backfill `now()` for currently-verified
engineers (NOT `created_at`), and make whatever admin path sets
`verification_status = 'verified'` stamp it. Until then those latency metrics
honestly report 0 rather than a fabricated number.
