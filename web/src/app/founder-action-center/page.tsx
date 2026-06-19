import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import { logFounderActionAction } from "./actions";

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
const ageStr = (h: number) => h < 24 ? `${h}h` : `${Math.floor(h / 24)}d`;

function ActionButton({ row, action, label, tone }: { row: ActionRow; action: "acked" | "resolved" | "escalated" | "ignored"; label: string; tone: string }) {
  return (
    <form action={logFounderActionAction} className="inline">
      <input type="hidden" name="source_domain" value={row.source_domain} />
      <input type="hidden" name="item_kind" value={row.item_kind} />
      <input type="hidden" name="source_item_id" value={row.item_id} />
      <input type="hidden" name="action_taken" value={action} />
      <button type="submit" className={`px-2 py-1 rounded text-[10px] uppercase tracking-wider font-semibold border ${tone} hover:opacity-80`}>
        {label}
      </button>
    </form>
  );
}

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
        <h1 className="text-xl font-semibold">Founder action center ★★★ r1303 · r1306 (write transitions)</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Unified action queue · top {actions.length} items prioritized across 14 source domains · ACK / RESOLVE / ESCALATE / IGNORE each to silence</p>
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
          <p className="mt-2 text-sm text-[var(--color-muted)]">No outstanding founder actions across all 14 source domains.</p>
          <p className="mt-1 text-xs text-[var(--color-muted)]">See <a className="text-[var(--color-accent)] hover:underline" href="/founder-priority-actions-log">/founder-priority-actions-log</a> for the history of what was acked/resolved/escalated/ignored.</p>
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
                  <th className="py-2 pr-3">Drill</th>
                  <th className="py-2">Mark</th>
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
                    <td className="py-2 pr-3 text-xs">
                      {SOURCE_DRILLDOWN[a.source_domain] ? (
                        <a href={SOURCE_DRILLDOWN[a.source_domain]} className="text-[var(--color-accent)] hover:underline">→</a>
                      ) : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                    <td className="py-2">
                      <div className="flex flex-wrap gap-1">
                        <ActionButton row={a} action="acked"     label="Ack (24h)"   tone="border-[var(--color-info)] text-[var(--color-info)]" />
                        <ActionButton row={a} action="resolved"  label="Resolved"    tone="border-[var(--color-ok)] text-[var(--color-ok)]" />
                        <ActionButton row={a} action="escalated" label="Escalate"   tone="border-[var(--color-warn)] text-[var(--color-warn)]" />
                        <ActionButton row={a} action="ignored"   label="Ignore"     tone="border-[var(--color-muted)] text-[var(--color-muted)]" />
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <p className="text-xs text-[var(--color-muted)]">
        Silencing semantics: <b>Ack</b> = silence for 24h (will re-surface if not resolved) · <b>Resolved</b> / <b>Ignored</b> = silence forever · <b>Escalate</b> = silence for 7 days. All actions logged to <code>founder_priority_actions</code> with auditor trail.
      </p>
    </div>
  );
}
