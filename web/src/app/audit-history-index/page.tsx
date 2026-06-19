import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Audit history index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type AuditEvent = {
  round: string;
  workflow: string;
  scope: string;
  found: number;
  confirmed: number;
  highlights: string;
  fix_round: string;
};

const AUDITS: AuditEvent[] = [
  {
    round: "r1163",
    workflow: "w3gkpbc6w",
    scope: "16 founder RPCs across r992-r1154",
    found: 30, confirmed: 23,
    highlights: "engineer_payouts amount_inr/engineer_id → amount_rupees/engineer_user_id (10 fns); repair_jobs FK semantics (engineers.id NOT profiles); r1055 CTE alias; r1043 r1085-omission",
    fix_round: "r1163 sweep migration",
  },
  {
    round: "r1180-r1185",
    workflow: "wf2f5z89h",
    scope: "6 batch-1 RPCs (referrals/chains/supervised/notifications/signups-funnel/spot-audits)",
    found: 0, confirmed: 0,
    highlights: "All clean. Workflow agents respected schema-gotchas brief",
    fix_round: "—",
  },
  {
    round: "r1197-r1218",
    workflow: "ws4nf361d",
    scope: "22 RPCs spanning batches 2-4",
    found: 4, confirmed: 3,
    highlights: "CRITICAL: r1209 amc_pool_ledger doesn't exist (real: amc_payment_pool); HIGH+LOW: 'paid' dead literal on engineer_payouts.status in r1208 + r1211",
    fix_round: "r1230 sweep migration",
  },
  {
    round: "r1220-r1225",
    workflow: "wwc5rgoqp",
    scope: "6 batch-5 RPCs (engineer-availability + razorpay + email + checkpoints + regional-city + repair-types)",
    found: 4, confirmed: 4,
    highlights: "CRITICAL: r1224 profiles.city doesn't exist (dropped earlier sweep); HIGH x2: r1225 kind='amc'/'warranty' not in CHECK constraint",
    fix_round: "r1237 sweep migration",
  },
  {
    round: "r1231-r1236",
    workflow: "w9f46jxo3",
    scope: "6 batch-6 RPCs (collusion/dupe-accounts/promo/device-integrity/equipment-pm/cart-abandonment)",
    found: 1, confirmed: 0,
    highlights: "All clean. One forward-compat note (3 of 7 signal_kind counter columns dormant until upstream detectors ship) — auditor said keep",
    fix_round: "—",
  },
  {
    round: "r1238-r1243",
    workflow: "w3d2w4swi",
    scope: "6 batch-7 RPCs (phone-otp/bonded-parts/virtual-call/pre-visit-dossier/tds/dpdp-grievance)",
    found: 0, confirmed: 0,
    highlights: "All clean. Strengthened 'verify every table' instruction was internalized by design agents",
    fix_round: "—",
  },
];

const totalFound = AUDITS.reduce((s, a) => s + a.found, 0);
const totalConfirmed = AUDITS.reduce((s, a) => s + a.confirmed, 0);

export default async function AuditHistoryIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Audit history index ★ r1254</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Pre-deploy adversarial audit log · {AUDITS.length} audit workflows ridden · {totalConfirmed} confirmed bugs caught of {totalFound} candidates surfaced</p>
      </header>

      <section className="rounded-lg border-2 border-[var(--color-ok)] bg-[var(--color-surface)] p-6">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">Why the audit-vs-design pattern matters</div>
        <p className="mt-2 text-sm">
          Postgres plpgsql validates NEITHER column refs NOR table refs at <code>CREATE FUNCTION</code> time.
          Silent typos ship green and only surface at first execution. Across {AUDITS.length} audit workflows we&apos;ve confirmed
          {" "}<b>{totalConfirmed} real prod bugs</b> that would have 500-errored on first founder call —
          including a CRITICAL table-name typo and a CRITICAL column-removal drift.
          Every design workflow now ships paired with an audit workflow as standard ops.
        </p>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Audit log</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                <th className="py-2 pr-3">Round(s)</th>
                <th className="py-2 pr-3">Workflow</th>
                <th className="py-2 pr-3">Scope</th>
                <th className="py-2 pr-3">Surfaced</th>
                <th className="py-2 pr-3">Confirmed</th>
                <th className="py-2 pr-3">Highlights</th>
                <th className="py-2">Fix</th>
              </tr>
            </thead>
            <tbody>
              {AUDITS.map((a) => (
                <tr key={a.workflow} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 font-mono text-xs">{a.round}</td>
                  <td className="py-2 pr-3 font-mono text-xs">{a.workflow}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{a.scope}</td>
                  <td className="py-2 pr-3 tabular-nums">{a.found}</td>
                  <td className={`py-2 pr-3 tabular-nums ${a.confirmed > 0 ? "text-[var(--color-danger)] font-semibold" : "text-[var(--color-ok)]"}`}>{a.confirmed}</td>
                  <td className="py-2 pr-3 text-xs">{a.highlights}</td>
                  <td className="py-2 text-xs font-mono">{a.fix_round}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
