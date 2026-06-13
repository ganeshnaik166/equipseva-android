import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Ops — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type CodeRedRow = {
  id: string;
  hospital_email: string | null;
  equipment_type: string | null;
  description: string | null;
  status: string | null;
  sla_minutes: number | null;
  sla_deadline_at: string | null;
  accepted_engineer_email: string | null;
  time_to_accept_minutes: number | null;
  paged_count: number | null;
  declined_count: number | null;
  created_at: string;
};

type FleetRow = {
  hospital_user_id: string;
  hospital_email: string | null;
  total_failures_90d: number | null;
  unique_assets_90d: number | null;
  avg_mttr_hours: number | null;
  replacement_candidates: number | null;
  oldest_unresolved_at: string | null;
};

type PmOverdueRow = {
  hospital_email: string | null;
  equipment_model: string | null;
  last_pm_at: string | null;
  next_pm_due: string | null;
  overdue_days: number | null;
};

export default async function OpsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [crRes, fleetRes, pmRes] = await Promise.all([
    supabase.rpc("founder_code_red_recent", { p_days: 30, p_limit: 50 }),
    supabase.rpc("founder_fleet_red_flags", { p_limit: 50 }),
    supabase.rpc("founder_pm_overdue_summary", { p_days: 30, p_limit: 100 }),
  ]);
  if (crRes.error) throw new Error(`founder_code_red_recent: ${crRes.error.message}`);
  if (fleetRes.error) throw new Error(`founder_fleet_red_flags: ${fleetRes.error.message}`);
  if (pmRes.error) throw new Error(`founder_pm_overdue_summary: ${pmRes.error.message}`);
  const codeRed = (crRes.data ?? []) as CodeRedRow[];
  const fleet = (fleetRes.data ?? []) as FleetRow[];
  const pm = (pmRes.data ?? []) as PmOverdueRow[];

  const crCols: Column<CodeRedRow>[] = [
    {
      key: "when",
      header: "Filed",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? "—" },
    { key: "type", header: "Equipment", render: (r) => r.equipment_type ?? "—" },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const s = (r.status ?? "").toLowerCase();
        const cls =
          s === "accepted"
            ? "bg-green-100 text-[var(--color-ok)]"
            : s === "expired" || s === "no_response"
              ? "bg-red-100 text-[var(--color-danger)]"
              : "bg-yellow-100 text-[var(--color-warn)]";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status ?? "—"}</span>;
      },
    },
    {
      key: "ttap",
      header: "Time to accept",
      render: (r) =>
        r.time_to_accept_minutes != null ? `${r.time_to_accept_minutes.toFixed(0)} min` : "—",
    },
    {
      key: "paged",
      header: "Paged / declined",
      render: (r) => (
        <span>
          {formatNumber(r.paged_count)} /{" "}
          <span className="text-[var(--color-danger)]">{formatNumber(r.declined_count)}</span>
        </span>
      ),
    },
    {
      key: "eng",
      header: "Engineer",
      render: (r) => r.accepted_engineer_email ?? "—",
    },
  ];

  const fleetCols: Column<FleetRow>[] = [
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? shortId(r.hospital_user_id) },
    { key: "fail", header: "Failures 90d", render: (r) => formatNumber(r.total_failures_90d) },
    { key: "assets", header: "Unique assets", render: (r) => formatNumber(r.unique_assets_90d) },
    {
      key: "mttr",
      header: "Avg MTTR",
      render: (r) =>
        r.avg_mttr_hours != null ? `${r.avg_mttr_hours.toFixed(1)} h` : "—",
    },
    {
      key: "replace",
      header: "Replace candidates",
      render: (r) => (
        <span className={(r.replacement_candidates ?? 0) > 0 ? "font-medium text-[var(--color-warn)]" : ""}>
          {formatNumber(r.replacement_candidates)}
        </span>
      ),
    },
    {
      key: "oldest",
      header: "Oldest unresolved",
      render: (r) => formatRelativeTime(r.oldest_unresolved_at),
    },
  ];

  const pmCols: Column<PmOverdueRow>[] = [
    { key: "hospital", header: "Hospital", render: (r) => r.hospital_email ?? "—" },
    { key: "model", header: "Equipment", render: (r) => r.equipment_model ?? "—" },
    { key: "last", header: "Last PM", render: (r) => formatRelativeTime(r.last_pm_at) },
    { key: "due", header: "Due", render: (r) => formatRelativeTime(r.next_pm_due) },
    {
      key: "over",
      header: "Overdue",
      render: (r) => (
        <span className={(r.overdue_days ?? 0) > 7 ? "font-semibold text-[var(--color-danger)]" : "text-[var(--color-warn)]"}>
          {formatNumber(r.overdue_days)} d
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">Operations</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Code Red emergency response (r509), hospital fleet red flags (r508), predictive-PM
          overdue (r507).
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Code Red (last 30 days) <span className="text-[var(--color-muted)]">({codeRed.length})</span>
        </h2>
        <DataTable
          columns={crCols}
          rows={codeRed}
          rowKey={(r) => r.id}
          emptyMessage="No Code Red requests in window."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Fleet red flags <span className="text-[var(--color-muted)]">({fleet.length})</span>
        </h2>
        <DataTable
          columns={fleetCols}
          rows={fleet}
          rowKey={(r) => r.hospital_user_id}
          emptyMessage="No hospitals over the failure-count + MTTR threshold."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Predictive-PM overdue <span className="text-[var(--color-muted)]">({pm.length})</span>
        </h2>
        <DataTable
          columns={pmCols}
          rows={pm}
          rowKey={(r, i) => `${r.hospital_email ?? "x"}-${r.equipment_model ?? "y"}-${i}`}
          emptyMessage="No overdue PM tasks in window."
        />
      </section>
    </div>
  );
}
