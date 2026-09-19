# Independent QA review — product planning only

Reviewed 19 September 2026 by the independent QA agent. **Result: accepted for the declared planning scope, 9.60/10.** This is not an application, integration, security certification, device or release score. The critic review was performed separately; this report does not reuse the critic's score.

The reviewed documents define a coherent, testable continuation of the existing Android app. No unresolved critical/high planning contradiction remains in the reviewed content after the corrections below. Existing application blockers remain open, and publication of this plan cannot accept draft PR 1877.

## Frozen review inputs

Planning checkout base: `6df0ec6ab1f92aaae6ac4e51e72f2c801ac51823`. Application source independently inspected: `ccda4e4addef7e995f6e55a106c703dbee7af253` in the separate quality-integration checkout. That source checkout was clean when inspected. The hashes below identify the reviewed working-tree documents before publication metadata is appended; a later substantive requirement change needs review of its diff.

| Document | SHA-256 |
|---|---|
| [PRODUCT_PLAN.md](../../../PRODUCT_PLAN.md) | `30C8DC6BA64A9588BD0313CBB3F74DDD48ACA869AF0A3EE328FDCAAD443E4F92` |
| [PAGES_AND_WORKFLOWS.md](../PAGES_AND_WORKFLOWS.md) | `471E795F66F62FE9C23FECC660FD8D2C72CE206AA6F71CCC886A0BA32EB9B1CB` |
| [ARCHITECTURE_AND_MIGRATION.md](../ARCHITECTURE_AND_MIGRATION.md) | `8B1764B352B668811E10F35B8ED20CEFBBCA9AD25AE200A96B6A905D8F368DB4` |
| [DELIVERY_LEDGER.md](../DELIVERY_LEDGER.md) | `96190363B0199405A7125D617516DE07CF61CFF0351D7E5AF8BAEA536B6AF002` |
| [SECURITY_PAYMENTS_AND_ABUSE.md](../SECURITY_PAYMENTS_AND_ABUSE.md) | `61F0C5BF1E31E316EFC41B91E7922CC679CAE07A7AE6E57BF3A79F6DCA693F26` |

## Independent checks and findings

| Check | Observed planning result |
|---|---|
| Complete existing-page carry-forward | Extracted names from the page table and independently scanned Kotlin `fun ...Screen` declarations at the candidate, excluding the documented `SecureScreen` effect and two non-page helpers. Both sets contain **98 unique names**, with no missing or extra names. All **98 source path/line anchors** resolve to the named declaration. Historical registry grouping independently confirms **91 registered associations, five root/activity surfaces and two legacy screens**; this does not prove runtime reachability. |
| Proposed surfaces | The page table contains **30 proposed N01–N30 surfaces** with entry/action/exit and exceptional states. They are explicitly excluded from implemented counts. Common state profiles also cover sheets, photo/OTP/provider returns, unknown results, denied access, process restoration and safe recovery. |
| Persona and authority model | Three public registration intents, returning-user sign-in and privately provisioned founder are consistent. Tenant payment cannot create founder authority or verification. Hospital membership includes explicit site/task scope; empty delegated scope denies access. A service relationship grants the shared job slice, not membership in the customer's hospital. |
| Independent engineer preservation | Personal access now explicitly requires the authenticated identity to match its immutable owner, with normal verification/resource checks, without company membership or a team subscription. A rejected organisation context cannot fall back to personal access. Positive independent-engineer and foreign-personal-owner denial tests are required. |
| Team workflows and navigation | Overview / Jobs / Team / Organisation are the four labelled destinations. Reports are reachable from Overview. Consent, qualifications, capacity, immutable contracting parties/payee, reassignment and independent hospital approval are covered. Personal earnings, KYC originals and unrelated work do not become employer data. |
| Demo isolation | Launch is strictly client-local synthetic fixtures. Production repositories, checkout, invitations/messages, FCM and uploads are excluded. A hosted demo requires a later separate decision. Reset/exit/real setup cannot promote synthetic records or receipts. |
| Source reconciliation | Independently inspected the two-role root gate, public `UserRole`, cleanup global mutations and ownerless outbox, AMC-linked subscription schema, contradictory region-catalog comments, M1 dispatch update, M3 structured outage handling and incomplete integrity binding. These support the plan's stated gaps; source inspection does not establish deployed database or provider state. |
| Existing evidence preserved | Candidate handoff confirms the recorded **3,675 unit tests with three enabled cleanup failures**, the separate lint follow-up, passed debug/unsigned release assembly, and **116 changed screenshot cases with only two individually sampled**. Documents do not promote these to a green suite, accepted screenshots or signed release. S3's 9.2 scoped review remains unaccepted. |
| Map-free migration | Canonical versioned state/district IDs, hierarchy, aliases, ambiguous legacy values and historical snapshots are specified. Discovery, attendance RPCs/triggers, private addresses, old clients, permissions and dependencies migrate deliberately. No zero-coordinate workaround or district-as-presence claim is permitted. Challenge/evidence attendance has absent-representative, offline, replay, reassignment and collusion cases. |
| Migration feasibility | Schema census precedes SQL. Additive schema, proven backfill/quarantine, shadow comparison, atomic compatibility projection, gated canary and eventual legacy contraction have explicit recovery rules. No two writable membership truths, destructive reassignment or speculative schema deployment is assumed. |
| Security and offline revocation | Direct server, storage, realtime, export and worker denials are required, with fresh permitted controls. Remote revocation is immediate for new server requests, while disconnected caches have a proposed maximum 24-hour lease, trusted-time/boot rules, lock and reconnect validation. Previously viewed/exported data and tampered-device limits are acknowledged. |
| Billing and money | Digital SaaS and physical repair/AMC have separate ledgers and policy gates. Provider lifecycle is separate from Pending / Active / Grace / Restricted / Suspended app access. Twelve precedence/race cases cover paid-through cancellation, authoritative grace, stale events, revoked membership, capacity and workspace switching. Existing-work obligations and dispute/receipt access survive subscription lapse within explicit authority. |
| Privileged and fraud controls | Founder access is private, scoped, fresh-authenticated and audited. Solo-founder self-approved exceptional money releases and ownership overrides are disabled. Risk cases cover false claims, copied evidence, collusion, takeover, beneficiary changes, insider abuse and false positives with appeal. Integrity is action-bound server enforcement, not an unhackability promise. |
| Design, accessibility and human evidence | Lime/ink, original logo, Space Grotesk/Inter and language fallback remain. Rendered contrast, light/dark, EN/HI/TE, narrow displays, 2x text, native Back/IME and TalkBack are explicit gates. Human validation now covers hospital, independent/team engineer, team owner/dispatcher and platform operator, recording participants, completion, errors, recovery and limitations. |
| Operations and delivery | P0 plan, P1 safety, P2 tenants/regions, P3 entry/demo, P4 billing, P5 map-free jobs, P6 team, P7 remaining pages and P8 release agree. Live sales require purchased operational capabilities as well as billing. Load tiers are hypotheses; measured budgets, tenant fairness, restore/key/provider-outage drills, signing, symbolication and rollback remain release work. |

The current [Google Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en), [India alternative-billing requirements](https://support.google.com/googleplay/android-developer/answer/13306652) and [purchase-security guidance](https://developer.android.com/google/play/billing/security) were independently reopened during QA. They support the plan's separation of digital and physical payments, its initial Play Billing choice, and backend purchase validation/acknowledgement gate. This was documentation reading, not provider-account verification, enrollment or a payment call. Legal applicability remains a specialist launch decision.

## Corrections raised by this QA and verified before scoring

1. Security's earlier “preferred local demo” wording left a hosted launch alternative open. It now requires client-local launch and a separately reviewed future hosted-demo decision.
2. Master and security wording differed on solo-founder exceptional overrides. Both now prohibit self-approved exceptional money releases/ownership overrides, retaining ordinary validated settlement and accepted owner-to-owner transfer.
3. Personal engineer workspaces lacked an explicit exception to the organisation-membership authorization formula. Master, architecture and security now define immutable personal ownership and prohibit unsafe context fallback.
4. The ledger's human-evidence row named only hospital and engineer. It now includes team-owner/dispatcher and platform-operator tasks and specifies participant/task/error/recovery evidence.

## Planning rubric

| Dimension | Weight | Score / 10 | Basis and remaining limit |
|---|---:|---:|---|
| Correctness/completeness/source reconciliation | 25% | 9.6 | Full bounded inventory and source anchors; compatible contracts and preserved debt. Actual schema census and full code audit still required. |
| Security/privacy | 25% | 9.6 | Explicit tenant/site/personal grants, demo isolation, fraud and founder limits, denial controls. No security execution or legal certification implied. |
| Recovery/data/money | 20% | 9.7 | Concrete ownership barriers, bounded offline leases, payment races, entitlement precedence and rollback. Device durability and provider behavior remain unexecuted. |
| Usability/accessibility/locales | 15% | 9.5 | Page state profiles and all-persona human tasks are testable. Detailed new-page renders, translated copy and participant validation remain future evidence. |
| Visual consistency | 10% | 9.6 | Existing identity and rendered accessibility requirements preserved. No new renders or golden approval were performed. |
| Performance/operations | 5% | 9.5 | Bounded queries, fairness, test tiers and operational drills are specified. Numeric supported-capacity claims await measured budgets. |
| **Weighted planning score** | **100%** | **9.60** | **Planning scope only; all applicable scored dimensions meet 9.5.** |

## Gates that this review does not close

- P1 still must fix the three unchanged cleanup regressions and S3 recovery using real mutation-boundary and root/router tests; subsequent workspaces cannot waive this foundation.
- P2 requires actual schema/grant/policy census, migration/rollback and direct tenant/site/personal-owner denial evidence. Canonical region provenance and legacy mapping are not yet delivered.
- P4/P5/P6 require functional purchased capabilities, provider/channel configuration, settlement correctness, atomic seats, legitimate supported-device paths, complete service obligations and all relevant adversarial integration checks before live sales/service.
- All **116 screenshot changes**, release signing, device/TalkBack/locales, all-persona human tasks, production-representative load, incident/restore exercises and remaining source audit need their own evidence and independent acceptance.
- Prices/seats, provider contracts, retention periods, support/incident owners and policy/legal applicability remain named launch dependencies. Their deferral is bounded; it is not permission to charge or release with missing decisions.

No production/test source was edited by this reviewer; no Gradle, emulator, staging/production SQL, payment, deployment or push was run. The only authored artifact is this report. Read-only inventory/anchor comparisons are planning consistency checks, not application tests. Exclusions also include exhaustive code review, penetration testing, remote publication verification and the later PDF artifact. Review any subsequent code or substantive plan changes in their own declared scope.
