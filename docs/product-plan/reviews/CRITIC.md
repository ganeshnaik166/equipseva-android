# Independent critic review — product plan

Date: 19 September 2026. Reviewer: independent `product_plan_critic` agent. Scope: the frozen documentation set below, its internal consistency, source reconciliation, feasibility, authority boundaries and acceptance contracts. **Planning score: 9.5/10. Accepted for this bounded planning scope. No unresolved critical/high planning finding was identified after the revisions described below.**

This score does not accept the Android implementation, production schema, security, payments, release, legal compliance or capacity. It is a review judgment, not a measured percentage of product completion. The existing app draft remains unaccepted.

## Reviewed baseline and method

- Documentation checkout starts from main `6df0ec6ab1f92aaae6ac4e51e72f2c801ac51823`; the source candidate inspected is exactly `ccda4e4addef7e995f6e55a106c703dbee7af253` in the separate quality-integration checkout.
- Read `docs/AGENTS_READ_FIRST.md`, the master plan, page/workflow plan, architecture/migration plan, security/payments/abuse plan and delivery ledger. Checked the prominent README entry and the candidate's quality handoff.
- Independently scanned the page table against candidate Kotlin declarations: **98 unique mapped Screen names, zero duplicates and zero mapped names missing from the declaration scan**. The apparent additional `SecureScreen`/`consumeLastScreen` names are the excluded effect/helper surfaces. This confirms the bounded declaration inventory, not runtime reachability or every overlay.
- Spot-checked `UserRole.kt`, `Profile.kt`, `SignOutCleanup.kt`, and hospital-chain migration `20260834000000_round544_hospital_chains_seed.sql`. These support the distinction between public intent, legacy scalar organisation/role data, global cleanup debt and old site-account chain semantics.
- The candidate handoff independently confirms the carried-forward **3,675 tests / three enabled cleanup failures**, **116 changed screenshot cases / two sampled images**, and separate lint/unsigned assembly evidence. These are recorded earlier executions, not tests rerun in this review.
- No app code, build, database, provider, device, remote account, production mutation or push was performed. Official policy references are documented by the security author; this critic did not independently recertify their current legal/payment applicability.

Frozen content hashes reviewed, SHA-256:

| Document | SHA-256 |
|---|---|
| `PRODUCT_PLAN.md` | `30C8DC6BA64A9588BD0313CBB3F74DDD48ACA869AF0A3EE328FDCAAD443E4F92` |
| `PAGES_AND_WORKFLOWS.md` | `471E795F66F62FE9C23FECC660FD8D2C72CE206AA6F71CCC886A0BA32EB9B1CB` |
| `ARCHITECTURE_AND_MIGRATION.md` | `8B1764B352B668811E10F35B8ED20CEFBBCA9AD25AE200A96B6A905D8F368DB4` |
| `SECURITY_PAYMENTS_AND_ABUSE.md` | `61F0C5BF1E31E316EFC41B91E7922CC679CAE07A7AE6E57BF3A79F6DCA693F26` |
| `DELIVERY_LEDGER.md` | `96190363B0199405A7125D617516DE07CF61CFF0351D7E5AF8BAEA536B6AF002` |

Publication/review receipts may subsequently update the ledger without implying a new implementation review. Material changes to the contracts require a corresponding review update.

**Follow-up review receipt, 19 September 2026:** independently read the two QA-requested clarifications and refreshed the hashes above. Master §4, architecture §3 and security §2 now explicitly authorize an independent engineer's personal workspace through authenticated identity matching its immutable owner, plus normal role/verification/resource checks, without requiring company membership or a team subscription. The contract forbids falling back from a rejected organisation context and requires both independent-engineer success and foreign-personal-workspace denial tests. Master §8 and ledger P8.1/human acceptance now include hospital staff, independent/team engineers, team owner/dispatcher and platform operator, with participant context, completion/errors/recovery and validation limitations recorded separately. These close the two additional planning ambiguities without weakening tenant controls. **The bounded 9.5/10 planning disposition is reconfirmed.** No app execution or new acceptance evidence is claimed; the PDF overview remains outside this critic review.

## Findings raised and verified resolved

| Finding | Original consequence | Resolution in frozen set |
|---|---|---|
| C1: Conflicting team navigation | Master proposed five destinations; page plan proposed four with a different settings destination. Designers would implement incompatible shells. | Both now use **Overview / Jobs / Team / Organisation**, with Reports from Overview and billing/settings under Organisation. Master §7; pages §3 and N18. |
| C2: Reused P0–P8 identifiers for different milestones | One document called cleanup P0 while the master/ledger called it P1; entry, billing and team gates also differed. A follow-on task could skip the intended authority prerequisite. | Pages §9 and final handoff now use the canonical master/ledger sequence. Live P4 selling is explicitly gated by purchased P6 capability readiness and relevant P5 service safety. |
| C3: Organisation membership omitted an explicit hospital-site boundary | A hospital manager delegated to one site could be implemented with access to every site in the same organisation. Hospital biomedical staff were mentioned without a concrete scope primitive. | Architecture §3 adds `membership_site_scopes`, composite tenant FKs, explicit owner-wide scope, default-deny empty scopes and staff limitations. §6 adds same-organisation foreign-site, suspended attachment, invalid FK and empty-scope tests. Master §4 carries the same rule. |
| C4: Subscription states mixed provider lifecycle and access state | Differing pending/grace/past-due/trial/cancellation lists risked inconsistent access and immediate cancellation denial. | Master §5, architecture §5 and security §4 use **Pending / Active / Grace / Restricted / Suspended** as derived access, with billing lifecycle separate. The security transition matrix covers paid-through cancellation, revocation precedence, stale webhooks, membership loss during purchase and provider outage. Live trial is deferred. |
| C5: Immediate revocation wording exceeded disconnected-device capability | A remote membership change cannot instantly erase a disconnected cache. Without a lease contract, implementations could claim impossible guarantees or retain private reads indefinitely. | Master §4 and architecture §6 distinguish immediate server denial from offline detection. Security §2 specifies a proposed maximum 24-hour routine-read lease, trusted-time/reboot handling, foreground/reconnect validation, online-only sensitive actions and the limits of recalling previously viewed data. SEC-02 includes these tests. |
| C6: Demo isolation launch choice was ambiguous | Client-local fixtures and a separate backend were both described as current options, creating different side-effect and operational boundaries. | Master, pages and architecture fix launch to client-local synthetic fixtures; a hosted demo is deferred. Security's possible future backend constraints do not authorize it for launch. No live trial or sample-record promotion is included. |

The initially missing security document was pending author completion, not treated as a completed review. It exists and was read in the frozen set.

## Assessment against the review rubric

| Dimension | Weight | Planning assessment |
|---|---:|---|
| Correctness and source reconciliation | 25 | Four personas/three public choices are coherent; all 98 existing declarations have a disposition; source candidate and main remain distinct; authoritative phase IDs agree. |
| Security and privacy | 25 | Payment, verification and membership remain separate. Tenant/site/job participation, private founder provisioning, storage/realtime/export boundaries, integrity limitations, support audit and offline revocation are testable. |
| Recovery, data and money | 20 | S1/S3 precede wider runtime work. Migration preserves ownership/history, uses shadow/backfill/compatibility gates and avoids two independent membership truths. Payment/seat races and safe restricted completion have explicit contracts. |
| Usability, accessibility and locales | 15 | Returning users, invitation consent, missing hospital representative, unknown payment outcome, stale catalog, blocked integrity and account recovery have exits. The shared page-state contract covers EN/HI/TE, TalkBack, large type, small screens and process restoration. |
| Visual consistency | 10 | Existing lime/ink, original logo and heading/body typography remain authoritative. New roles use labels and task hierarchy. Linux visual review and the 116 unaccepted comparisons remain explicit gates. No new renders were accepted here. |
| Performance and operations | 5 | Pagination, scope-aware queues/cache/realtime, resource limits, tenant fairness, workload tiers, restore/rollback and monitoring are planned without unsupported capacity claims. Measured budgets remain a pilot prerequisite. |

The aggregate judgment is **9.5/10 for planning**; applicable critical planning dimensions meet the same threshold. There is no score averaging that clears an implementation blocker. The deduction from a perfect score reflects deliberately unresolved implementation detail and commercial/operational configuration, which is appropriately gated rather than hidden.

## Required downstream gates and remaining risks

These are explicit future work, not findings silently waived by this review:

1. **P1 evidence:** fix all real cleanup mutation boundaries and the same-account recovery path. Preserve the three failing tests and fresh-success controls; mocks or DTOs alone do not establish isolation.
2. **P2 authority and migration:** inventory the actual non-production schema and helper/grant definitions, settle immutable job parties and beneficiary mapping, and prove direct table/RPC/storage/realtime/worker denial. Run old/new-client and canonical/compatibility atomicity tests. Hospital site access requires its own tests even when both sites belong to one tenant.
3. **P3 demo and entry:** show the third registration intent only under its staged contract. Network/side-effect evidence must prove demo cannot create production accounts, invitations, payments, uploads or notifications. Restored demo objects must fail at live endpoints.
4. **P4/P6 commercial readiness:** settle price, seats, provider configuration, terms, cancellation/refund ownership and lawful payment arrangement before selling. Test restore/linked purchase, entitlement ordering, two purchases, same-workspace races, expired seats and membership removal during checkout. Paid selling must wait for the actual promised team capabilities.
5. **P5 no-map delivery:** import a dated verified region catalog, inspect actual discovery/check-in/attendance dependencies, preserve old job evidence and migrate old clients. Prove the non-location visit protocol, participant absence/manual review and supported offline recovery; district selection never becomes identity or attendance proof.
6. **Privileged operations:** before a live pilot, name real incident/recovery contacts and demonstrate the single-founder exception path. A provider/support reference is not evidence that lost-owner recovery or an exceptional dispute can actually be resolved. High-risk overrides remain disabled until that path works.
7. **Privacy and scale:** choose data-specific retention and cache/lease policy, measure latency/error/cost budgets against the declared tenant workload, and rehearse restore/revocation. The 24-hour offline limit is a proposed ceiling, not permission to cache all data for that duration.
8. **P7/P8 acceptance:** finish scope-specific source review, screenshot review, locale/TalkBack/device/provider journeys, signed distribution and symbol/incident checks. Planning acceptance does not waive S1, S3, M1, M3, incomplete integrity enforcement or the visual backlog.

Exclusions: exhaustive code audit, deployed-schema verification, remote publication verification, policy/legal certification, penetration testing, provider settlement acceptance, human usability validation, device/offline durability validation, production load measurement and the user's subsequent PDF overview. Each needs its own appropriate evidence.
