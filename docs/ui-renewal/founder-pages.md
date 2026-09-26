# Founder/admin page designs

Planning at `1dc9188e212ab217393e055b4c238b18c72521ae`; source exploration and
navigation association, not runtime or full-line security audit. Apply the main
[theme/state/verification contract](../UI_THEME_PAGE_PLAN_2026-09-12.md).
Exact files, definition lines, graph bindings and hashes are in [source-map.md](source-map.md).

All rows belong to UI-10. Entry is the existing founder menu/dashboard or its
drill-down; keep entity IDs and optional filter arguments. Navigation visibility
does not grant permission: every read/write requires validated session/owner and
server-side founder authorization. A3/A4 and sensitive-action evidence gate final
acceptance. Back returns to the source queue/filter, not an unrelated Home screen.

Use the same Space Grotesk/Inter and paired light/dark tokens as the customer app,
with compact readable rows and fewer large hero cards. Financial amounts, document
identity and action consequences remain visible. Red/danger is reserved for
destructive actions; a lime control does not certify approval or settlement.

| Page / source composable | Proposed layout and purpose | Main action and secondary actions | States and specific acceptance |
| --- | --- | --- | --- |
| Dashboard / `FounderDashboardScreen` | Admin heading; actionable payout/review queues first, compact real metrics, grouped Operations and Integrity links | Open the selected queue; refresh and existing drill-downs | Load/error/partial-data separately; unavailable counts must not become zero. Every current queue remains reachable |
| Engineer KYC queue / `FounderKycQueueScreen` | Pending engineer rows with identity, submitted details, documents and review status | Review application; existing approve/reject actions retain confirmation context | Empty versus failed read; document access failure; decision in progress/error; changed/already-reviewed record |
| Engineer KYC review / `FounderKycReviewScreen` | Identity header, personal/work sections, document list, fixed-context decision footer that grows/scrolls | Approve; reject with required reason; view documents | Invalid/missing/stale application, expired document link, rejection validation and pending writes; no optimistic verified badge |
| Buyer KYC queue / `FounderBuyerKycQueueScreen` | Buyer identity, application summary and labeled document actions | View evidence; approve/reject with captured buyer context | Empty/error, unreadable document, reason form, duplicate press and stale account/record |
| Reports / `FounderReportsQueueScreen` | Reason/evidence first, subject identity, status and review actions in a stable row | Existing actioned/reviewed/dismissed transitions, with explicit consequence where needed | Distinguish marking reviewed from acting on account; preserve status values; confirm consequential action and show its error inline |
| Users / `FounderUsersScreen` | Search with persistent label; actual role filters, readable identity/role/integrity rows | Open role editor for selected user; filter/search/refresh | No results versus failed search; current target visible in modal, pending/error selection, server-authorized role values |
| Payments / `FounderPaymentsScreen` | Compact amount/status rows, date/party details and truthful summary | View invoice or buyer integrity where offered | Unknown monetary totals stay unavailable; canceled/failed/refunded/paid states distinct; browser or invoice failure is recoverable |
| Engineer payouts / `FounderEngineerPayoutsScreen` | Pending/failed/other filters, amount and transfer state, masked destination plus deliberate utility actions | Existing mark-paid or cancel flow for captured payout | Reference/mode/reason validation, failed external-app return, repeated action, stale status and server rejection; never infer payment from copying destination or opening UPI |
| Integrity / `FounderIntegrityScreen` | Filtered owner context followed by labeled signal rows and actual verdicts | Inspect/refresh; Back retains optional user/name filter context | Unknown/missing verdict distinct from pass; diagnostics remain founder-only |
| Categories / `FounderCategoriesScreen` | Existing categories in compact rows with key/display name/scope/activity; add/edit sheet | Add or save category; edit image/scope/order/activity; cancel | New/existing drafts, uploading image, save failure, invalid values and changed account. Image picker states remain explicit |
| Engineer zones / `FounderEngineerMapScreen` | Overview map with equivalent named zone list and real counts | Select zone and inspect existing detail; refresh | Permission/provider/data unavailable distinct from no coverage; list usable without map. Do not imply individual real-time tracking |
| Expiring AMC / `FounderAmcExpiringScreen` | Contract/customer/expiry rows with labeled urgency | Open contract; refresh | No contracts versus failed lookup; dates/times unambiguous and accessible |
| Paused AMC / `FounderPausedAmcScreen` | Contract identity, paused state and available context | Open contract; refresh | Do not turn a row tap into resume/renewal. Failed reads and removed records recover safely |
| Inactive engineers / `FounderInactiveEngineersScreen` | Identity, inactivity context and explicit date/period | Open public engineer profile; refresh | Unknown last activity not zero activity; missing/deleted profile and no-result handling |
| Escrow disputes / `FounderEscrowDisputesScreen` | Job/parties/amount/reason then timeline/decision actions | Inspect timeline; existing resolve sheet | Decision outcome and side effects visible; require server outcome, captured escrow ID and reason semantics; no automatic payment on opening |
| Escrow timeline / `FounderEscrowDisputeDetailScreen` | Escrow identity, event chronology and separate party records | Read/refresh; Back | Partial party-history failures cannot erase valid timeline or become a clean record; privacy and locale dates |
| AMC escalations / `FounderAmcEscalationsScreen` | Contract/escalation/engineer context and pending status | Open escalation; existing resolve action | Clear difference between viewing roster and resolving escalation; inline pending/failure/retry |
| AMC escalation detail / `FounderAmcEscalationDetailScreen` | Contract, issue, chronology and roster sections, contextual resolve action | Resolve when existing state allows; refresh | Changed/already-resolved state, failed roster versus empty roster, mutation error and captured escalation ownership |
| Cash-suspended engineers / `FounderCashSuspendedScreen` | Engineer identity and explicit suspension/flag context | Open flag history; existing reinstate action | Reinstatement confirmation, in-flight/rejected write and stale eligibility; visual reskin must not relax criteria |
| Cash flag history / `FounderCashFlagHistoryScreen` | Entity heading and chronological flag rows | Read/refresh; Back | Missing engineer, empty history, partial/stale results and unknown flag labels |
| Parts outliers / `FounderPartsOutliersScreen` | Job and cost/comparison context with readable amounts | Inspect existing rows/refresh | Flag means review signal, not proven fraud; unavailable data is distinct from no outliers; no invented adjudication action |
| Resolved disputes / `FounderResolvedDisputesScreen` | Outcome/time/parties rows, compact amount details | Open timeline; refresh | Outcome labels reflect returned values, no-results/error distinction; shared detail preserves source Back |
| Spot audits / `FounderSpotAuditsScreen` | Response/subject/time/answer rows | Read/refresh | Unknown/missing response stays unknown; do not add a new audit-run action without a product/server contract |

## Nested surfaces

| Surface | Minimal design and verification |
| --- | --- |
| KYC approve/reject and buyer decision sheets | Title names target and action; reason uses persistent label; confirm/cancel reachable above IME; block duplicate submit; server failure keeps same-target input; account change retires it |
| Role editor (`FounderUsersScreen`) | Current and proposed role, radio semantics, explicit apply/cancel context; preserve actual allowed server roles and test denial |
| Category editor and image picker | Sectioned name/key/scope/order/activity form, image/upload/error state; no successful-save signal during upload; dismissal/Back doesn't imply durability |
| Mark paid / cancel payout (`FounderEngineerPayoutsScreen`) | Payout/engineer/amount visible, reference/mode or cancellation reason, deliberate confirmations; keep actual transfer truth and immutable target while network work runs |
| Escrow resolution (`AdminResolveDisputeSheet`) | Show escrow identity, parties, amount, supported outcomes and consequences; a safe cancellation path; use server-confirmed status |
| Report action confirmation | Subject/reason/action visible; retain exact actioned/reviewed/dismissed meaning; no blanket “success” before acknowledgment |
| Reinstatement / escalation actions | Consequence is explicit, entity remains visible, no background tap-through; failed/stale request allows safe refresh |
| KYC documents / invoices / UPI / dialer / clipboard | Preserve security and external-handler policies, mask sensitive details where supported, name the action and handle unavailable app/expired link/cancel. Opening a handler does not establish successful payment or review |

Before implementation, extract each nested action's existing owner, cancellation,
fresh-auth and permission requirements into its test-first case list. Do not claim
those protections already exist because this table calls for them.
