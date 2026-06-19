import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder action items cockpit — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  priority_actions_open: number;
  priority_acked: number;
  priority_resolved: number;
  priority_escalated: number;
  priority_ignored: number;
  postmortem_actions_open: number;
  postmortem_actions_in_progress: number;
  postmortem_actions_closed: number;
  postmortem_actions_overdue: number;
  total_open: number;
  oldest_open_age_days: number;
  today_added: number;
  this_week_added: number;
  last_30d_added: number;
  escalated_ratio_pct: number;
  completion_ratio_pct: number;
};

type CombinedRow = {
  source_kind: "priority" | "postmortem";
  item_id: string;
  title: string;
  kind_label: string;
  status: string;
  owner: string;
  age_days: number;
  due_date: string | null;
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const STATUS_TONE: Record<string, string> = {
  open:        "text-[var(--color-warn)]",
  in_progress: "text-[var(--color-info)]",
  closed:      "text-[var(--color-ok)]",
  wont_do:     "text-[var(--color-muted)]",
  acked:       "text-[var(--color-info)]",
  resolved:    "text-[var(--color-ok)]",
  escalated:   "text-[var(--color-warn)]",
  ignored:     "text-[var(--color-muted)]",
};

const SOURCE_TONE: Record<string, string> = {
  priority:   "border-[var(--color-info)] text-[var(--color-info)]",
  postmortem: "border-[var(--color-accent)] text-[var(--color-accent)]",
};

export default async function FounderActionItemsCockpitPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, combinedRes] = await Promise.all([
    supabase.rpc("founder_action_items_cockpit_summary"),
    supabase.rpc("founder_action_items_cockpit_combined", { p_limit: 100 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_action_items_cockpit_summary: ${summaryRes.error.message}`);
  if (combinedRes.error) throw new Error(`founder_action_items_cockpit_combined: ${combinedRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (combinedRes.data ?? []) as CombinedRow[];

  const statusCounts = rows.reduce<Record<string, number>>((acc, r) => {
    acc[r.status] = (acc[r.status] ?? 0) + 1;
    return acc;
  }, {});
  const priorityCount = rows.filter((r) => r.source_kind === "priority").length;
  const postmortemCount = rows.filter((r) => r.source_kind === "postmortem").length;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder action items cockpit ★★★ r1334</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Unified action-tracker across <code>founder_priority_actions</code> (write-transition log) and{" "}
          <code>founder_incident_postmortem_action_items</code> (postmortem follow-ups).
        </p>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          This is the engineer + leadership single-screen action-tracker. Pair with{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-center">/founder-action-center</a>{" "}
          for the priority queue itself.
        </p>
      </header>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Priority slice (last 30d)</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <Card label="Open (30d)"   value={formatNumber(s.priority_actions_open ?? 0)} tone="border-[var(--color-info)]" />
          <Card label="Acked"        value={formatNumber(s.priority_acked ?? 0)} />
          <Card label="Resolved"     value={formatNumber(s.priority_resolved ?? 0)} tone="border-[var(--color-ok)]" />
          <Card label="Escalated"    value={formatNumber(s.priority_escalated ?? 0)} tone="border-[var(--color-warn)]" />
          <Card label="Ignored"      value={formatNumber(s.priority_ignored ?? 0)} />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Postmortem action items</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Card label="Open"        value={formatNumber(s.postmortem_actions_open ?? 0)} tone="border-[var(--color-warn)]" />
          <Card label="In progress" value={formatNumber(s.postmortem_actions_in_progress ?? 0)} tone="border-[var(--color-info)]" />
          <Card label="Closed"      value={formatNumber(s.postmortem_actions_closed ?? 0)} tone="border-[var(--color-ok)]" />
          <Card label="Overdue"     value={formatNumber(s.postmortem_actions_overdue ?? 0)} tone="border-[var(--color-danger)]" />
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Aggregates</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          <Card label="Total open" value={formatNumber(s.total_open ?? 0)} tone="border-[var(--color-accent)]"
                sub="postmortem open+in_progress + priority 30d" />
          <Card label="Oldest open age" value={`${s.oldest_open_age_days ?? 0}d`} />
          <Card label="Added today"    value={formatNumber(s.today_added ?? 0)} />
          <Card label="Added this week" value={formatNumber(s.this_week_added ?? 0)} />
          <Card label="Added last 30d"  value={formatNumber(s.last_30d_added ?? 0)} />
          <Card label="Escalated ratio" value={`${s.escalated_ratio_pct ?? 0}%`}
                sub="priority: escalated / all-time" />
          <Card label="Completion ratio" value={`${s.completion_ratio_pct ?? 0}%`} tone="border-[var(--color-ok)]"
                sub="postmortem: closed / all" />
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
        <div className="text-xs uppercase tracking-wider text-[var(--color-muted)] mb-2">Filter banner — combined list breakdown</div>
        <div className="flex flex-wrap gap-2 text-[11px]">
          <span className="rounded border border-[var(--color-info)] text-[var(--color-info)] px-2 py-1">priority · {priorityCount}</span>
          <span className="rounded border border-[var(--color-accent)] text-[var(--color-accent)] px-2 py-1">postmortem · {postmortemCount}</span>
          {Object.entries(statusCounts).map(([st, n]) => (
            <span key={st} className={`rounded border border-[var(--color-border)] px-2 py-1 ${STATUS_TONE[st] ?? "text-[var(--color-muted)]"}`}>
              {st} · {n}
            </span>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Combined feed (top 100, newest first)</h2>
        {rows.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-6 text-center text-sm">
            <span className="text-[var(--color-ok)] font-semibold">All clear</span> — no action items in either source.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="py-2 pr-3">Source</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Owner</th>
                  <th className="py-2 pr-3 tabular-nums">Age</th>
                  <th className="py-2 pr-3 tabular-nums">Due</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={`${r.source_kind}-${r.item_id}`} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3">
                      <span className={`text-[10px] uppercase tracking-wider font-semibold border rounded px-2 py-0.5 ${SOURCE_TONE[r.source_kind] ?? ""}`}>
                        {r.source_kind}
                      </span>
                    </td>
                    <td className="py-2 pr-3 max-w-md">{r.title}</td>
                    <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{r.kind_label}</td>
                    <td className={`py-2 pr-3 text-xs uppercase tracking-wider font-semibold ${STATUS_TONE[r.status] ?? "text-[var(--color-muted)]"}`}>
                      {r.status}
                    </td>
                    <td className="py-2 pr-3 text-xs">{r.owner}</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">{r.age_days}d</td>
                    <td className="py-2 pr-3 tabular-nums text-xs">
                      {r.due_date ? <span className={new Date(r.due_date) < new Date() && (r.status === "open" || r.status === "in_progress") ? "text-[var(--color-danger)]" : ""}>{r.due_date}</span> : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Source #1: <code>founder_priority_actions</code> r1306 — write-transition log for /founder-action-center (acked / resolved / escalated / ignored).
        Source #2: <code>founder_incident_postmortem_action_items</code> r1332 — concrete owner+due-date items emerging from incident postmortems.
        Pair with{" "}
        <a className="text-[var(--color-accent)] hover:underline" href="/founder-action-center">/founder-action-center</a>{" "}
        ·{" "}
        <a className="text-[var(--color-accent)] hover:underline" href="/founder-priority-actions-log">/founder-priority-actions-log</a>{" "}
        ·{" "}
        <a className="text-[var(--color-accent)] hover:underline" href="/founder-incident-postmortem-ledger">/founder-incident-postmortem-ledger</a>.
      </p>
    </div>
  );
}
