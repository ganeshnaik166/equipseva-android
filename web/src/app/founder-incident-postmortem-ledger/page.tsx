import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder incident postmortem ledger — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_postmortems: number;
  class_process_gap: number;
  class_code_bug: number;
  class_data_inconsistency: number;
  class_vendor_failure: number;
  class_external_event: number;
  class_people_error: number;
  class_design_gap: number;
  class_other: number;
  total_revenue_impact_rupees: number;
  total_affected_users: number;
  median_detection_lag_minutes: number;
  median_resolution_minutes: number;
  postmortems_30d: number;
  action_items_open: number;
  action_items_closed_pct: number;
  oldest_open_action_age_days: number;
};

type Postmortem = {
  id: string;
  incident_id: string;
  incident_title: string | null;
  incident_severity: string | null;
  incident_status: string | null;
  title: string;
  root_cause_classification: string | null;
  severity_at_resolution: string | null;
  revenue_impact_rupees: number;
  affected_user_count: number;
  detection_lag_minutes: number | null;
  resolution_duration_minutes: number | null;
  action_items_count: number;
  action_items_closed_count: number;
  written_at: string;
};

type ActionItem = {
  id: string;
  postmortem_id: string;
  postmortem_title: string | null;
  description: string;
  owner_user_id: string | null;
  owner_email: string | null;
  due_date: string | null;
  status: "open" | "in_progress" | "closed" | "wont_do";
  age_days: number;
  is_overdue: boolean;
  created_at: string;
};

const CLASS_LABEL: Record<string, string> = {
  process_gap: "Process gap",
  code_bug: "Code bug",
  data_inconsistency: "Data inconsistency",
  vendor_failure: "Vendor failure",
  external_event: "External event",
  people_error: "People error",
  design_gap: "Design gap",
  other: "Other",
};

const SEV_TONE: Record<string, string> = {
  p0: "text-[var(--color-danger)] border-[var(--color-danger)]",
  p1: "text-[var(--color-warn)] border-[var(--color-warn)]",
  p2: "text-[var(--color-info)] border-[var(--color-info)]",
  p3: "text-[var(--color-muted)] border-[var(--color-border)]",
};

function rupeesShort(n: number): string {
  const v = Number(n) || 0;
  if (v >= 10_000_000) return `Rs ${(v / 10_000_000).toFixed(1)}Cr`;
  if (v >= 100_000) return `Rs ${(v / 100_000).toFixed(1)}L`;
  if (v >= 1_000) return `Rs ${(v / 1_000).toFixed(1)}K`;
  return `Rs ${formatNumber(v)}`;
}

export default async function FounderIncidentPostmortemLedgerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes, actionsRes] = await Promise.all([
    supabase.rpc("founder_postmortem_ledger_summary"),
    supabase.rpc("founder_postmortems_recent", { p_limit: 30 }),
    supabase.rpc("founder_postmortem_action_items_open", { p_limit: 50 }),
  ]);
  if (sumRes.error) throw new Error(`founder_postmortem_ledger_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_postmortems_recent: ${recRes.error.message}`);
  if (actionsRes.error) throw new Error(`founder_postmortem_action_items_open: ${actionsRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const postmortems = (recRes.data ?? []) as Postmortem[];
  const actions = (actionsRes.data ?? []) as ActionItem[];

  const classBuckets = s ? [
    { key: "process_gap",        n: s.class_process_gap },
    { key: "code_bug",           n: s.class_code_bug },
    { key: "data_inconsistency", n: s.class_data_inconsistency },
    { key: "vendor_failure",     n: s.class_vendor_failure },
    { key: "external_event",     n: s.class_external_event },
    { key: "people_error",       n: s.class_people_error },
    { key: "design_gap",         n: s.class_design_gap },
    { key: "other",              n: s.class_other },
  ] : [];
  const classMax = classBuckets.reduce((m, b) => Math.max(m, b.n), 0) || 1;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder incident postmortem ledger ★ r1332</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Institutional memory · 1:1 with founder_incidents · 8-class root-cause taxonomy · action-item tracking · evidence we are learning, not just patching
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-5">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total postmortems</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.total_postmortems)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Written last 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.postmortems_30d)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Revenue impact (cum)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{rupeesShort(s.total_revenue_impact_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Users affected (cum)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.total_affected_users)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median detect-lag (min)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.median_detection_lag_minutes).toFixed(0)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median resolve (min)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.median_resolution_minutes).toFixed(0)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Process gaps</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_process_gap)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Code bugs</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_code_bug)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Data inconsistencies</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_data_inconsistency)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Vendor failures</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_vendor_failure)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">External events</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_external_event)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">People errors</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_people_error)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Design gaps</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.class_design_gap)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Action items open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.action_items_open)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Action closure rate</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{Number(s.action_items_closed_pct).toFixed(1)}%</div>
            <div className="text-xs text-[var(--color-muted)]">oldest open {formatNumber(s.oldest_open_action_age_days)}d</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Root-cause classification distribution</h2>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 space-y-2">
          {classBuckets.map(b => (
            <div key={b.key} className="flex items-center gap-3">
              <div className="w-44 text-xs text-[var(--color-muted)] truncate">{CLASS_LABEL[b.key]}</div>
              <div className="flex-1 h-2 rounded bg-[var(--color-bg)] overflow-hidden">
                <div className="h-full bg-[var(--color-accent)]" style={{ width: `${(b.n / classMax) * 100}%` }} />
              </div>
              <div className="w-12 text-right text-xs font-mono tabular-nums">{formatNumber(b.n)}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Top 30 recent postmortems</h2>
        {postmortems.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No postmortems yet. Write one for every resolved p0/p1 incident within 48h.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Written</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Class</th>
                  <th className="py-2 pr-3">Sev</th>
                  <th className="py-2 pr-3 text-right">Rev impact</th>
                  <th className="py-2 pr-3 text-right">Users</th>
                  <th className="py-2 pr-3 text-right">Detect</th>
                  <th className="py-2 pr-3 text-right">Resolve</th>
                  <th className="py-2 pr-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {postmortems.map(p => (
                  <tr key={p.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 whitespace-nowrap text-[var(--color-muted)]">{new Date(p.written_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" })}</td>
                    <td className="py-2 pr-3 max-w-[260px] truncate" title={p.title}>{p.title}</td>
                    <td className="py-2 pr-3">{p.root_cause_classification ? CLASS_LABEL[p.root_cause_classification] : <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className="py-2 pr-3">
                      {p.severity_at_resolution ? (
                        <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${SEV_TONE[p.severity_at_resolution] ?? ""}`}>{p.severity_at_resolution}</span>
                      ) : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                    <td className="py-2 pr-3 text-right tabular-nums">{rupeesShort(p.revenue_impact_rupees)}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{formatNumber(p.affected_user_count)}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{p.detection_lag_minutes ?? "—"}{p.detection_lag_minutes != null ? "m" : ""}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{p.resolution_duration_minutes ?? "—"}{p.resolution_duration_minutes != null ? "m" : ""}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">
                      <span className="text-[var(--color-ok)]">{p.action_items_closed_count}</span>
                      <span className="text-[var(--color-muted)]">/{p.action_items_count}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Open action items (top 50 oldest)</h2>
        {actions.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No open action items. Either everything is closed or postmortems haven't generated any — investigate which.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Age</th>
                  <th className="py-2 pr-3">Postmortem</th>
                  <th className="py-2 pr-3">Description</th>
                  <th className="py-2 pr-3">Owner</th>
                  <th className="py-2 pr-3">Due</th>
                  <th className="py-2 pr-3">Status</th>
                </tr>
              </thead>
              <tbody>
                {actions.map(a => (
                  <tr key={a.id} className={`border-b border-[var(--color-border)] ${a.is_overdue ? "bg-[color-mix(in_srgb,var(--color-danger)_8%,transparent)]" : ""}`}>
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{a.age_days}d</td>
                    <td className="py-2 pr-3 max-w-[180px] truncate text-[var(--color-muted)]" title={a.postmortem_title ?? ""}>{a.postmortem_title ?? "—"}</td>
                    <td className="py-2 pr-3 max-w-[320px] truncate" title={a.description}>{a.description}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{a.owner_email ?? <span className="italic">unassigned</span>}</td>
                    <td className={`py-2 pr-3 tabular-nums ${a.is_overdue ? "text-[var(--color-danger)] font-semibold" : "text-[var(--color-muted)]"}`}>
                      {a.due_date ?? "—"}{a.is_overdue ? " OVERDUE" : ""}
                    </td>
                    <td className="py-2 pr-3 uppercase text-[10px] tracking-wider">{a.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <h3 className="text-sm font-semibold text-[var(--color-fg)]">Writing discipline</h3>
        <ul className="list-disc list-inside space-y-1">
          <li>Every p0/p1 resolved incident MUST get a postmortem within 48h — institutional memory or it didn't happen.</li>
          <li>Every postmortem MUST list {">="} 1 action item. Zero items means we didn't learn — re-open the postmortem.</li>
          <li>Action items have explicit owners + due dates. Overdue items show in red above — clear them weekly.</li>
          <li>Classification taxonomy is fixed (8 buckets). Don't invent new categories; force-fit and patch later.</li>
          <li>Revenue impact + affected users come from forensic estimation at write-time. Conservative, not theatrical.</li>
        </ul>
        <p className="pt-2">Write via <code className="font-mono">log_founder_postmortem_create()</code> · add actions via <code className="font-mono">log_founder_postmortem_add_action_item()</code> · close via <code className="font-mono">log_founder_postmortem_close_action_item()</code>.</p>
      </section>
    </div>
  );
}
