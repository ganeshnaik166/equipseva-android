import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder priority actions log — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_actions_all_time: number;
  actions_today: number;
  actions_7d: number;
  acked_count: number;
  resolved_count: number;
  escalated_count: number;
  ignored_count: number;
  acked_active_now: number;
  escalated_active_now: number;
  most_recent_action_at: string | null;
  distinct_domains_acted: number;
};

type LogRow = {
  id: string;
  source_domain: string;
  item_kind: string;
  source_item_id: string;
  action_taken: "acked" | "resolved" | "escalated" | "ignored";
  note: string | null;
  ack_expires_at: string | null;
  created_at: string;
};

const ACTION_TONE: Record<LogRow["action_taken"], string> = {
  acked:     "text-[var(--color-info)]",
  resolved:  "text-[var(--color-ok)]",
  escalated: "text-[var(--color-warn)]",
  ignored:   "text-[var(--color-muted)]",
};

export default async function FounderPriorityActionsLogPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, recentRes] = await Promise.all([
    supabase.rpc("founder_priority_actions_summary"),
    supabase.rpc("founder_priority_actions_recent", { p_limit: 100 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_priority_actions_summary: ${summaryRes.error.message}`);
  if (recentRes.error) throw new Error(`founder_priority_actions_recent: ${recentRes.error.message}`);
  const s = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const log = (recentRes.data ?? []) as LogRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder priority actions log ★ r1306</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">Audit trail of every ACK / RESOLVE / ESCALATE / IGNORE the founder took on /founder-action-center items</p>
      </header>

      {s ? (
        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total actions all-time</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.total_actions_all_time)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Actions today</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.actions_today)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Actions 7d</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.actions_7d)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Domains acted</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.distinct_domains_acted)}</div>
          </div>

          <div className="rounded-lg border border-[var(--color-info)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Acked (lifetime)</div>
            <div className={`mt-1 text-2xl font-semibold tabular-nums ${ACTION_TONE.acked}`}>{formatNumber(s.acked_count)}</div>
            <div className="text-xs text-[var(--color-muted)]">{formatNumber(s.acked_active_now)} active (24h timer)</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Resolved (lifetime)</div>
            <div className={`mt-1 text-2xl font-semibold tabular-nums ${ACTION_TONE.resolved}`}>{formatNumber(s.resolved_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Escalated (lifetime)</div>
            <div className={`mt-1 text-2xl font-semibold tabular-nums ${ACTION_TONE.escalated}`}>{formatNumber(s.escalated_count)}</div>
            <div className="text-xs text-[var(--color-muted)]">{formatNumber(s.escalated_active_now)} active (7d timer)</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Ignored (lifetime)</div>
            <div className={`mt-1 text-2xl font-semibold tabular-nums ${ACTION_TONE.ignored}`}>{formatNumber(s.ignored_count)}</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Recent actions (latest 100)</h2>
        {log.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No actions logged yet. Visit <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-center">/founder-action-center</a> to start triaging.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">When</th>
                  <th className="py-2 pr-3">Action</th>
                  <th className="py-2 pr-3">Domain</th>
                  <th className="py-2 pr-3">Item kind</th>
                  <th className="py-2 pr-3">Source ID</th>
                  <th className="py-2 pr-3">Silenced until</th>
                  <th className="py-2">Note</th>
                </tr>
              </thead>
              <tbody>
                {log.map((l) => (
                  <tr key={l.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 text-xs tabular-nums text-[var(--color-muted)]">{new Date(l.created_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })}</td>
                    <td className={`py-2 pr-3 ${ACTION_TONE[l.action_taken]} uppercase tracking-wider text-[10px] font-semibold`}>{l.action_taken}</td>
                    <td className="py-2 pr-3 text-xs font-mono">{l.source_domain}</td>
                    <td className="py-2 pr-3 text-xs">{l.item_kind}</td>
                    <td className="py-2 pr-3 text-[10px] font-mono text-[var(--color-muted)]">{l.source_item_id.slice(0, 8)}…</td>
                    <td className="py-2 pr-3 text-xs">{l.ack_expires_at ? new Date(l.ack_expires_at).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" }) : <span className="text-[var(--color-muted)]">never (terminal)</span>}</td>
                    <td className="py-2 text-xs text-[var(--color-muted)]">{l.note ?? ""}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
