import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Incident RCA Readout — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_postmortems_with_rca: number | null;
  postmortems_last_30d: number | null;
  avg_resolution_duration_hours: number | null;
  avg_detection_lag_minutes: number | null;
  total_revenue_impact_rupees: number | null;
  total_affected_users: number | null;
  process_gap_count: number | null;
  code_bug_count: number | null;
  data_inconsistency_count: number | null;
  vendor_failure_count: number | null;
  external_event_count: number | null;
  people_error_count: number | null;
  design_gap_count: number | null;
  other_rca_count: number | null;
  top_root_cause: string | null;
  top_root_cause_count: number | null;
};

type RecentRow = {
  postmortem_id: string;
  incident_id: string;
  title: string | null;
  root_cause_classification: string | null;
  severity: string | null;
  revenue_impact_rupees: number | null;
  affected_user_count: number | null;
  resolution_duration_hours: number | null;
  detection_lag_minutes: number | null;
  written_at: string;
  action_items_open_count: number | null;
  action_items_total_count: number | null;
  completion_pct: number | null;
  source_domain: string | null;
};

function classBand(cls: string | null): string {
  switch ((cls ?? "other").toLowerCase()) {
    case "process_gap":
      return "bg-yellow-100 text-[var(--color-warn)]";
    case "code_bug":
      return "bg-red-100 text-[var(--color-danger)]";
    case "data_inconsistency":
      return "bg-orange-100 text-[var(--color-warn)]";
    case "vendor_failure":
      return "bg-purple-100 text-purple-700";
    case "external_event":
      return "bg-blue-100 text-blue-700";
    case "people_error":
      return "bg-pink-100 text-pink-700";
    case "design_gap":
      return "bg-indigo-100 text-indigo-700";
    default:
      return "bg-gray-100 text-[var(--color-muted)]";
  }
}

function sevBand(sev: string | null): string {
  switch ((sev ?? "p3").toLowerCase()) {
    case "p0":
      return "bg-red-100 text-[var(--color-danger)] font-semibold";
    case "p1":
      return "bg-orange-100 text-[var(--color-warn)] font-semibold";
    case "p2":
      return "bg-yellow-100 text-[var(--color-warn)]";
    default:
      return "bg-gray-100 text-[var(--color-muted)]";
  }
}

export default async function FounderIncidentRcaReadoutPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [sumRes, recentRes] = await Promise.all([
    supabase.rpc("founder_incident_rca_readout_summary"),
    supabase.rpc("founder_incident_rca_readout_recent", { p_limit: 30 }),
  ]);
  if (sumRes.error) throw new Error(`founder_incident_rca_readout_summary: ${sumRes.error.message}`);
  if (recentRes.error) throw new Error(`founder_incident_rca_readout_recent: ${recentRes.error.message}`);

  const s = ((sumRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (recentRes.data ?? []) as RecentRow[];

  const cards: { label: string; value: string; hint?: string }[] = [
    { label: "Postmortems with RCA", value: formatNumber(s.total_postmortems_with_rca), hint: "classification not null" },
    { label: "Published last 30d", value: formatNumber(s.postmortems_last_30d) },
    { label: "Avg resolution", value: `${(s.avg_resolution_duration_hours ?? 0).toFixed(2)} h` },
    { label: "Avg detection lag", value: `${(s.avg_detection_lag_minutes ?? 0).toFixed(1)} min` },
    { label: "Revenue impact (sum)", value: `Rs ${formatNumber(s.total_revenue_impact_rupees)}` },
    { label: "Affected users (sum)", value: formatNumber(s.total_affected_users) },
    { label: "Top root cause", value: s.top_root_cause ?? "n/a", hint: `${formatNumber(s.top_root_cause_count)} postmortems` },
    { label: "Process gap", value: formatNumber(s.process_gap_count) },
    { label: "Code bug", value: formatNumber(s.code_bug_count) },
    { label: "Data inconsistency", value: formatNumber(s.data_inconsistency_count) },
    { label: "Vendor failure", value: formatNumber(s.vendor_failure_count) },
    { label: "External event", value: formatNumber(s.external_event_count) },
    { label: "People error", value: formatNumber(s.people_error_count) },
    { label: "Design gap", value: formatNumber(s.design_gap_count) },
    { label: "Other / unclassified", value: formatNumber(s.other_rca_count) },
    {
      label: "Discipline window",
      value: "7 days",
      hint: "p0/p1 must publish RCA within 7d of resolved_at",
    },
  ];

  const cols: Column<RecentRow>[] = [
    {
      key: "when",
      header: "Published",
      render: (r) => <span title={r.written_at}>{formatRelativeTime(r.written_at)}</span>,
    },
    {
      key: "sev",
      header: "Severity",
      render: (r) => (
        <span className={`rounded px-1.5 py-0.5 text-xs ${sevBand(r.severity)}`}>{(r.severity ?? "—").toUpperCase()}</span>
      ),
    },
    {
      key: "title",
      header: "Title",
      render: (r) => <span className="font-medium">{r.title ?? shortId(r.postmortem_id)}</span>,
    },
    {
      key: "cls",
      header: "Root cause",
      render: (r) => (
        <span className={`rounded px-1.5 py-0.5 text-xs ${classBand(r.root_cause_classification)}`}>
          {r.root_cause_classification ?? "other"}
        </span>
      ),
    },
    {
      key: "domain",
      header: "Domain",
      render: (r) => <span className="text-xs text-[var(--color-muted)]">{r.source_domain ?? "general"}</span>,
    },
    {
      key: "revenue",
      header: "Revenue impact",
      render: (r) => `Rs ${formatNumber(r.revenue_impact_rupees)}`,
    },
    {
      key: "users",
      header: "Users",
      render: (r) => formatNumber(r.affected_user_count),
    },
    {
      key: "res",
      header: "Resolution",
      render: (r) =>
        r.resolution_duration_hours != null ? `${r.resolution_duration_hours.toFixed(2)} h` : "—",
    },
    {
      key: "lag",
      header: "Detection lag",
      render: (r) => (r.detection_lag_minutes != null ? `${formatNumber(r.detection_lag_minutes)} min` : "—"),
    },
    {
      key: "ai",
      header: "Action items",
      render: (r) => {
        const open = r.action_items_open_count ?? 0;
        const total = r.action_items_total_count ?? 0;
        const cls = open > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return (
          <span className={cls}>
            {formatNumber(open)} open / {formatNumber(total)} total
          </span>
        );
      },
    },
    {
      key: "pct",
      header: "Completion",
      render: (r) => {
        const pct = r.completion_pct ?? 0;
        const cls =
          pct >= 80
            ? "text-[var(--color-ok)] font-semibold"
            : pct >= 50
              ? "text-[var(--color-warn)]"
              : "text-[var(--color-danger)]";
        return <span className={cls}>{pct.toFixed(1)}%</span>;
      },
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Incident RCA Readout</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Published root-cause analyses from founder_incident_postmortems (r1332). Discipline rule:
          every p0/p1 founder_incident must have a postmortem with a non-null root-cause
          classification published within 7 days of resolved_at. Action-item burndown tracked per
          postmortem.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold">RCA readout KPIs</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {cards.map((c) => (
            <div key={c.label} className="rounded border border-[var(--color-border)] bg-white p-3">
              <div className="text-xs text-[var(--color-muted)]">{c.label}</div>
              <div className="mt-1 text-lg font-semibold">{c.value}</div>
              {c.hint ? <div className="mt-0.5 text-xs text-[var(--color-muted)]">{c.hint}</div> : null}
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Recent readouts <span className="text-[var(--color-muted)]">({rows.length})</span>
        </h2>
        <DataTable
          columns={cols}
          rows={rows}
          rowKey={(r) => r.postmortem_id}
          emptyMessage="No postmortems published yet — write one for every resolved p0/p1."
        />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-gray-50 p-4 text-xs text-[var(--color-muted)]">
        <div className="font-semibold text-[var(--color-fg)]">RCA publishing discipline</div>
        <ul className="mt-2 list-disc space-y-1 pl-5">
          <li>Every p0/p1 founder_incident MUST have a postmortem within 7 days of resolved_at.</li>
          <li>Every postmortem MUST carry a non-null root_cause_classification (8 enum values).</li>
          <li>Every postmortem MUST list {">"}= 1 action item with an owner + due date.</li>
          <li>Completion {"<"} 50% on action items {"->"} surface in founder digest.</li>
          <li>"Other / unclassified" should trend to 0 over time as taxonomy matures.</li>
        </ul>
      </section>
    </div>
  );
}
