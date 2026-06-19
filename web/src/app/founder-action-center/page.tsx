import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder action center — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type ActionRow = {
  priority_rank: number;
  source_domain: string;
  item_kind: string;
  item_id: string;
  label: string;
  severity: number;
  severity_label: "critical" | "high" | "medium" | "low";
  age_hours: number;
  money_at_stake_inr: number;
  created_at: string;
};

const SEVERITY_TONE: Record<ActionRow["severity_label"], string> = {
  critical: "text-[var(--color-danger)] border-[var(--color-danger)]",
  high:     "text-[var(--color-warn)] border-[var(--color-warn)]",
  medium:   "text-[var(--color-info)] border-[var(--color-info)]",
  low:      "text-[var(--color-muted)] border-[var(--color-border)]",
};

const SOURCE_DRILLDOWN: Record<string, string> = {
  payouts:       "/payouts-snapshot-summary",
  code_red:      "/code-red-snapshot-summary",
  disputes:      "/disputes-snapshot-summary",
  escrow:        "/escrow-snapshot-summary",
  spare_parts:   "/spare-parts-snapshot-summary",
  amc:           "/amc-snapshot-summary",
  kyc:           "/kyc-pipeline-snapshot-summary",
  refunds:       "/refund-authorization-queue-summary",
  collusion:     "/collusion-flags-summary",
  dpdp:          "/dpdp-grievance-pulse-summary",
  amc_sla:       "/amc-sla-breaches-summary",
  risk_score:    "/risk-score-snapshots-summary",
  spot_audit:    "/spot-audits-snapshot-summary",
};

const inr = (n: number) => Number(n) > 0 ? `₹${Number(n).toLocaleString("en-IN")}` : "";
const ageStr = (h: number) => {
  if (h < 24) return `${h}h`;
  return `${Math.floor(h / 24)}d`;
};

export default async function FounderActionCenterPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_action_center", { p_limit: 100 });
  if (error) throw new Error(`founder_action_center: ${error.message}`);
  const actions = (data ?? []) as ActionRow[];

  const counts = {
    critical: actions.filter(a => a.severity_label === "critical").length,
    high:     actions.filter(a => a.severity_label === "high").length,
    medium:   actions.filter(a => a.severity_label === "medium").length,
    low:      actions.filter(a => a.severity_label === "low").length,
  };
  const total_money = actions.reduce((s, a) => s + Number(a.money_at_stake_inr || 0), 0);

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder action center ★ r1303</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Unified action queue · top {actions.length} items prioritized across 14 source domains · do these in order</p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <div className={`rounded-lg border-2 ${SEVERITY_TONE.critical} bg-[var(--color-surface)] p-4`}>
          <div className="text-xs uppercase tracking-wider">Critical</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{counts.critical}</div>
        </div>
        <div className={`rounded-lg border-2 ${SEVERITY_TONE.high} bg-[var(--color-surface)] p-4`}>
          <div className="text-xs uppercase tracking-wider">High</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{counts.high}</div>
        </div>
        <div className={`rounded-lg border-2 ${SEVERITY_TONE.medium} bg-[var(--color-surface)] p-4`}>
          <div className="text-xs uppercase tracking-wider">Medium</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{counts.medium}</div>
        </div>
        <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Total $ at stake</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{total_money > 0 ? `₹${total_money.toLocaleString("en-IN")}` : "—"}</div>
        </div>
      </section>

      {actions.length === 0 ? (
        <div className="rounded-lg border-2 border-[var(--color-ok)] bg-[var(--color-surface)] p-8 text-center">
          <div className="text-2xl font-bold text-[var(--color-ok)]">✓ Inbox zero</div>
          <p className="mt-2 text-sm text-[var(--color-muted)]">No outstanding founder actions across all 14 source domains. Good time to take a break — or scout new opportunities.</p>
        </div>
      ) : (
        <section>
          <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Action queue (sorted by severity → age)</h2>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3 tabular-nums">#</th>
                  <th className="py-2 pr-3">Severity</th>
                  <th className="py-2 pr-3">Action</th>
                  <th className="py-2 pr-3">Domain</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                  <th className="py-2 pr-3 tabular-nums">$ at stake</th>
                  <th className="py-2">Drill down</th>
                </tr>
              </thead>
              <tbody>
                {actions.map((a) => (
                  <tr key={`${a.source_domain}-${a.item_id}`} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{a.priority_rank}</td>
                    <td className={`py-2 pr-3 ${SEVERITY_TONE[a.severity_label].split(" ")[0]} uppercase tracking-wider text-[10px] font-semibold`}>{a.severity_label}</td>
                    <td className="py-2 pr-3">{a.label}</td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{a.source_domain}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{ageStr(a.age_hours)}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{inr(a.money_at_stake_inr)}</td>
                    <td className="py-2 text-xs">
                      {SOURCE_DRILLDOWN[a.source_domain] ? (
                        <a href={SOURCE_DRILLDOWN[a.source_domain]} className="text-[var(--color-accent)] hover:underline">→ {a.source_domain}</a>
                      ) : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <p className="text-xs text-[var(--color-muted)]">
        Source domains: stuck payouts &gt;7d · unresolved Code Red &gt;4h · open disputes &gt;7d · escrow held &gt;14d or in dispute · spare parts paid-not-shipped &gt;7d · AMC renewals due 30d · engineer KYC pending &gt;7d · refund queue open &gt;3d · collusion flags critical/high · DPDP grievances &gt;30d SLA · AMC SLA breaches today · risk score critical actors (alert_only) · spot audit invites unresponded &gt;7d.
      </p>
    </div>
  );
}
