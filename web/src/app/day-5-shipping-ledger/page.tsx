import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Day 5 shipping ledger — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Milestone = { round: string; pr: string; title: string; date: string };

const MILESTONES: Milestone[] = [
  { round: "r1145", pr: "v0.4-day-5-r1145-350ships",    title: "350 ships milestone · /jobs-index 20th meta-landing", date: "2026-06-18" },
  { round: "r1163", pr: "v0.4-day-5-r1163",             title: "Audit-fix sweep · 23 confirmed bugs across 16 RPCs (workflow w3gkpbc6w)", date: "2026-06-18" },
  { round: "r1168", pr: "v0.4-day-5-r1168-375ships",    title: "375 ships milestone · /engineers-snapshot-summary", date: "2026-06-19" },
  { round: "r1179", pr: "v0.4-day-5-r1179-380ships",    title: "380 ships milestone · /by-month-index 25th meta-landing", date: "2026-06-19" },
  { round: "r1180-85", pr: "v0.4-day-5-r1185-batch",    title: "Batch 1 design workflow (wyhr52otu): referrals/chains/supervised/notifications/signups-funnel/spot-audits", date: "2026-06-19" },
  { round: "r1186", pr: "v0.4-day-5-r1186",             title: "/snapshots-index expansion 9 → 15 surfaces", date: "2026-06-19" },
  { round: "r1193", pr: "v0.4-day-5-r1193",             title: "/money-in-flight-summary cross-domain cash position", date: "2026-06-19" },
  { round: "r1195", pr: "v0.4-day-5-r1195-390ships",    title: "390 ships milestone · /trust-pulse-summary composite trust score", date: "2026-06-19" },
  { round: "r1196", pr: "v0.4-day-5-r1196",             title: "/executive-dashboard-index 26th meta-landing Tier 1/2/3 priority", date: "2026-06-19" },
  { round: "r1197-1201", pr: "v0.4-day-5-r1201-batch",  title: "Batch 2 design workflow (wk1njvfff): equipment-category/engineer-certifications/compliance-evidence/cumulative-rollup/regional-state", date: "2026-06-19" },
  { round: "r1202-09", pr: "v0.4-day-5-r1209-batch",    title: "Batch 3 design workflow (wxq6jth6i): kyc-pipeline/webhooks/gst-invoice/rfq-marketplace/amc-sla-warranty/reconciliation-tax + r1209 amc-pool-pulse-summary (manual)", date: "2026-06-19" },
  { round: "r1211-12", pr: "v0.4-day-5-r1212",          title: "/supply-quality-summary + /demand-quality-summary composite scores", date: "2026-06-19" },
  { round: "r1213-18", pr: "v0.4-day-5-r1218-batch",    title: "Batch 4 design workflow (wwqe1qwrs): chat-moderation/onboarding-velocity/dsr-data-export-sla/consent-ledger/founder-action-followups/system-throughput-hourly", date: "2026-06-19" },
  { round: "r1220-25", pr: "v0.4-day-5-r1225-batch",    title: "Batch 5 design workflow (wos16xp6o): engineer-availability/razorpay-payments-pulse/email-delivery-health/founder-checkpoints/regional-city/repair-types", date: "2026-06-19" },
  { round: "r1228", pr: "v0.4-day-5-r1228",             title: "/pulse-summaries-index 27th meta-landing (11 cross-domain pulses)", date: "2026-06-19" },
  { round: "r1230", pr: "v0.4-day-5-r1230",             title: "Audit-fix sweep · r1208/r1209/r1211 (workflow ws4nf361d caught critical amc_pool_ledger → amc_payment_pool)", date: "2026-06-19" },
  { round: "r1231-36", pr: "v0.4-day-5-r1236-batch",    title: "Batch 6 design workflow (wcrg2jxpp): collusion-flags/duplicate-account-flags/promo-redemptions/device-integrity-checks/equipment-pm-schedule/cart-abandonment", date: "2026-06-19" },
  { round: "r1237", pr: "v0.4-day-5-r1237",             title: "Audit-fix sweep · r1224/r1225 (workflow wwc5rgoqp caught profiles.city + repair_jobs.kind CHECK)", date: "2026-06-19" },
];

const WORKFLOWS = [
  { id: "w3gkpbc6w", kind: "Audit",  result: "23 confirmed bugs across 16 RPCs · fed r1163 sweep" },
  { id: "wyhr52otu", kind: "Design", result: "6 designs r1180-r1185 batch 1" },
  { id: "wf2f5z89h", kind: "Audit",  result: "0 bugs in r1180-r1185 (clean)" },
  { id: "wk1njvfff", kind: "Design", result: "6 designs r1197-r1201 (skipped trust-pulse dupe)" },
  { id: "wxq6jth6i", kind: "Design", result: "6 designs r1202-r1207" },
  { id: "ws4nf361d", kind: "Audit",  result: "3 bugs in r1197-r1218 (CRITICAL: amc_pool_ledger → amc_payment_pool) · fed r1230 sweep" },
  { id: "wwqe1qwrs", kind: "Design", result: "6 designs r1213-r1218 batch 4" },
  { id: "wos16xp6o", kind: "Design", result: "6 designs r1220-r1225 batch 5" },
  { id: "wwc5rgoqp", kind: "Audit",  result: "4 bugs in r1220-r1225 (CRITICAL: profiles.city; HIGH: kind='amc'/'warranty') · fed r1237 sweep" },
  { id: "wcrg2jxpp", kind: "Design", result: "6 designs r1231-r1236 batch 6 (fraud/integrity/cart-abandonment)" },
  { id: "w9f46jxo3", kind: "Audit",  result: "in flight · auditing r1231-r1236" },
  { id: "w899xh587", kind: "Design", result: "in flight · batch 7 designs r1238-r1243" },
];

export default async function Day5ShippingLedgerPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Day 5 shipping ledger ★ r1244</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">v0.4 Day 5 autonomous sprint · 350 → 433+ ships · 12 ultracode workflows ridden so far</p>
      </header>
      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Milestones</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                <th className="py-2 pr-3">Date</th>
                <th className="py-2 pr-3">Round</th>
                <th className="py-2">Title</th>
              </tr>
            </thead>
            <tbody>
              {MILESTONES.map((m) => (
                <tr key={m.pr} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)] tabular-nums">{m.date}</td>
                  <td className="py-2 pr-3 font-mono text-xs">{m.round}</td>
                  <td className="py-2">{m.title}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Ultracode workflows ridden</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                <th className="py-2 pr-3">ID</th>
                <th className="py-2 pr-3">Kind</th>
                <th className="py-2">Result</th>
              </tr>
            </thead>
            <tbody>
              {WORKFLOWS.map((w) => (
                <tr key={w.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 font-mono text-xs">{w.id}</td>
                  <td className="py-2 pr-3">
                    <span className={`inline-block text-[10px] font-medium uppercase tracking-wider ${w.kind === "Audit" ? "text-[var(--color-danger)]" : "text-[var(--color-info)]"}`}>{w.kind}</span>
                  </td>
                  <td className="py-2 text-xs">{w.result}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Audit pattern proven</h2>
        <p className="text-sm text-[var(--color-muted)]">
          Every design workflow should pair with an audit workflow. Postgres plpgsql validates NEITHER columns
          NOR tables at CREATE time, so silent typos ship green and only surface at first execution. The audit
          workflow caught 4 confirmed bugs across 3 batches that would have all 500-errored at runtime — including
          a critical table-name typo (amc_pool_ledger doesn&apos;t exist; real table is amc_payment_pool) and a
          column-removal drift (profiles.city was dropped in an earlier security sweep but kept being referenced).
        </p>
      </section>
    </div>
  );
}
