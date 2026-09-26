# EquipSeva continuation contract

Before any model starts or resumes work, read these files in order:

1. `docs/CURRENT_STATE.md` — current branch, checkpoint, active slice, blockers and next step.
2. `PRODUCT_PLAN.md` and `docs/product-plan/DELIVERY_LEDGER.md` — governing scope and acceptance gates.
3. The latest handoff and review linked by CURRENT_STATE; then `docs/AGENTS_READ_FIRST.md` for source/CI conventions.

Verify this information against `git status`, branch/HEAD, fetched origin and the actual source. Historical handoffs describe their revisions; they are not current completion claims. Do not restart finished work or use the old two-role/map roadmap.

## Standing product decisions (owner)

- **English only — 23 September 2026.** The owner directed: "no need of Hindi, Telugu translations or words, all should be in English." Every string resource, UI label, notification, document and plan item is English. Do not add, translate, restore or maintain `values-hi`, `values-te` or any other locale resource directory, language picker, per-app locale config or Hindi/Telugu copy. Where an older document says EN/HI/TE or "translate", English alone applies. Number/date formatting still pins `Locale.ENGLISH`/`Locale.US` where tests require it; that is device-locale robustness, not translation.

## Preserve ownership and evidence

- Preserve other checkouts, uncommitted changes and active reservations. Never switch, reset, clean or force-push another task's checkout.
- Check the shared build slot before Gradle and immediately before launching it. On the founder's laptop it is `C:/Users/lokes/Documents/Codex/2026-09-07/im/outputs/equipseva-build-slot.md`. Reserve with task, branch, time and command; release only your reservation after your processes finish.
- Do not store credentials, tokens, private account details, payment proofs or raw production data in handoffs, memory or logs.
- Keep failing tests, security gates and screenshot tolerances intact. Record an unverified or failed result plainly. Unsigned assembly is not release approval.
- At each implementation milestone, obtain separate critic and QA agent reviews of the frozen diff/evidence. Each must reach 9.5/10 for the declared scope, with no unresolved mandatory gate. Do not turn a planning or narrow-slice score into an app score.

## Mandatory progress updates

Before changing an implementation slice, record its scope and ownership in CURRENT_STATE. After a milestone, interruption or checkpoint:

1. Update `docs/CURRENT_STATE.md` and append a dated entry to `docs/MILESTONE_LOG.md` with the exact verified code SHA, branch/PR, changed scope, test commands/counts/failures, review scope, blockers and next concrete action.
2. Update the affected delivery-ledger row and create/update the detailed handoff. Distinguish implementation, main integration and release acceptance.
3. Commit/push the authorised branch after fetching. Publish safe continuity documentation separately to main when app code is still blocked; do not merge blocked app code to publish a status update.
4. The owner explicitly requested continuing memory updates on 19 September 2026. If the current tool supports persistent project memory, save a small non-secret update pointing to these repository records. Follow that tool's memory mechanism; do not assume another model shares its private memory.

The repository records are the portable source of continuity. Model-specific memory is a convenience and must be checked against Git. Do not claim that an agent read the handoff unless its actual work demonstrates it.
