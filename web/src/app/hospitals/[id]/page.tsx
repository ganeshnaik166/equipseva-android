import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRelativeTime, formatRupees, shortId } from "@/lib/format";

export const metadata = { title: "Hospital detail — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type FleetRedFlag = {
  hospital_user_id: string;
  hospital_email: string | null;
  total_failures_90d: number | null;
  unique_assets_90d: number | null;
  avg_mttr_hours: number | null;
  replacement_candidates: number | null;
  oldest_unresolved_at: string | null;
};

type DisputeRow = {
  id?: string;
  hospital_email?: string | null;
  engineer_email?: string | null;
  escrow_amount_rupees?: number | null;
  status?: string | null;
  created_at?: string | null;
  repair_job_id?: string | null;
};

type GrievanceRow = {
  id: string;
  status: string | null;
  grievance_type?: string | null;
  requester_email?: string | null;
  description?: string | null;
  created_at: string;
};

type AuditRow = {
  id: string;
  op_name: string;
  target_table: string | null;
  target_row_id: string | null;
  outcome: string | null;
  reason: string | null;
  created_at: string;
};

type PmRow = {
  hospital_email: string | null;
  equipment_model: string | null;
  next_pm_due: string | null;
  overdue_days: number | null;
};

export default async function HospitalDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  await requireFounder();
  const { id } = await params;
  const supabase = await getSupabaseServerClient();

  const [fleetRes, disputesRes, grievancesRes, pmRes, auditRes] = await Promise.all([
    supabase.rpc("founder_fleet_red_flags", { p_limit: 500 }),
    supabase.rpc("founder_dispute_queue", { p_limit: 200 }),
    supabase.rpc("founder_dpdp_grievances_list", { p_limit: 200 }),
    supabase.rpc("founder_pm_overdue_summary", { p_days: 30, p_limit: 200 }),
    supabase
      .from("founder_action_log")
      .select("id, op_name, target_table, target_row_id, outcome, reason, created_at")
      .eq("target_row_id", id)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);

  if (fleetRes.error) throw new Error(`fleet_red_flags: ${fleetRes.error.message}`);
  if (disputesRes.error) throw new Error(`dispute_queue: ${disputesRes.error.message}`);
  if (grievancesRes.error) throw new Error(`dpdp_grievances_list: ${grievancesRes.error.message}`);

  const fleet = ((fleetRes.data ?? []) as FleetRedFlag[]).find((r) => r.hospital_user_id === id);
  const allDisputes = (disputesRes.data ?? []) as DisputeRow[];
  const allGrievances = (grievancesRes.data ?? []) as GrievanceRow[];
  const pm = (pmRes.error ? [] : (pmRes.data ?? [])) as PmRow[];
  const audit = (auditRes.data ?? []) as AuditRow[];

  // We don't have hospital_user_id on every queue row — fall back to email match.
  const email = fleet?.hospital_email ?? null;
  const disputes = allDisputes.filter((d) => email != null && d.hospital_email === email);
  const grievances = allGrievances.filter((g) => email != null && g.requester_email === email);
  const pmForHospital = pm.filter((r) => email != null && r.hospital_email === email);

  if (!fleet && disputes.length === 0 && grievances.length === 0 && audit.length === 0) {
    return (
      <div className="space-y-3">
        <h1 className="text-xl font-semibold">Hospital not found</h1>
        <p className="text-sm text-[var(--color-muted)]">
          No fleet, dispute, grievance, or audit-log rows match user_id <code>{id}</code>. They may
          be brand-new (no jobs / fleet history) or a stale link.
        </p>
        <Link
          href="/ops"
          className="inline-block rounded border border-[var(--color-border)] px-3 py-1 text-sm hover:bg-gray-50"
        >
          ← back to ops
        </Link>
      </div>
    );
  }

  const disputeCols: Column<DisputeRow>[] = [
    {
      key: "when",
      header: "Filed",
      render: (r) => <span title={r.created_at ?? ""}>{formatRelativeTime(r.created_at ?? null)}</span>,
    },
    { key: "engineer", header: "Engineer", render: (r) => r.engineer_email ?? "—" },
    { key: "amount", header: "Escrow", render: (r) => formatRupees(r.escrow_amount_rupees ?? null) },
    { key: "status", header: "Status", render: (r) => r.status ?? "open" },
    {
      key: "job",
      header: "Job",
      render: (r) => (
        <code className="text-xs text-[var(--color-muted)]">
          {shortId(r.repair_job_id ?? r.id)}
        </code>
      ),
    },
  ];

  const grievanceCols: Column<GrievanceRow>[] = [
    {
      key: "when",
      header: "Filed",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "kind", header: "Type", render: (r) => r.grievance_type ?? "—" },
    { key: "status", header: "Status", render: (r) => r.status ?? "—" },
    {
      key: "desc",
      header: "Description",
      render: (r) => (
        <details>
          <summary className="cursor-pointer text-xs text-[var(--color-muted)]">view</summary>
          <p className="mt-1 max-w-md whitespace-pre-wrap text-xs">{r.description ?? "—"}</p>
        </details>
      ),
    },
  ];

  const pmCols: Column<PmRow>[] = [
    { key: "model", header: "Equipment", render: (r) => r.equipment_model ?? "—" },
    { key: "due", header: "Due", render: (r) => formatRelativeTime(r.next_pm_due) },
    {
      key: "over",
      header: "Overdue",
      render: (r) => (
        <span className={(r.overdue_days ?? 0) > 7 ? "font-semibold text-[var(--color-danger)]" : ""}>
          {formatNumber(r.overdue_days)} d
        </span>
      ),
    },
  ];

  const auditCols: Column<AuditRow>[] = [
    { key: "when", header: "When", render: (r) => formatRelativeTime(r.created_at) },
    { key: "op", header: "Operation", render: (r) => <code className="text-xs">{r.op_name}</code> },
    { key: "outcome", header: "Outcome", render: (r) => r.outcome ?? "—" },
    { key: "reason", header: "Reason", render: (r) => <span className="text-xs">{r.reason ?? "—"}</span> },
  ];

  return (
    <div className="space-y-8">
      <header>
        <Link
          href="/ops"
          className="text-xs text-[var(--color-muted)] hover:text-[var(--color-fg)]"
        >
          ← ops
        </Link>
        <h1 className="mt-1 text-xl font-semibold">{email ?? "(no fleet record)"}</h1>
        <p className="text-xs text-[var(--color-muted)]">
          user_id <code>{id}</code>
        </p>
      </header>

      {fleet && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Fleet health — last 90 days
          </h2>
          <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
            <StatCard
              label="Total failures"
              value={formatNumber(fleet.total_failures_90d)}
              tone={(fleet.total_failures_90d ?? 0) > 5 ? "warn" : "ok"}
            />
            <StatCard
              label="Unique assets"
              value={formatNumber(fleet.unique_assets_90d)}
            />
            <StatCard
              label="Avg MTTR"
              value={fleet.avg_mttr_hours != null ? `${fleet.avg_mttr_hours.toFixed(1)} h` : "—"}
              tone={(fleet.avg_mttr_hours ?? 0) > 48 ? "danger" : (fleet.avg_mttr_hours ?? 0) > 24 ? "warn" : "ok"}
            />
            <StatCard
              label="Replacement candidates"
              value={formatNumber(fleet.replacement_candidates)}
              tone={(fleet.replacement_candidates ?? 0) > 0 ? "warn" : "ok"}
            />
          </div>
          {fleet.oldest_unresolved_at && (
            <p className="mt-2 text-xs text-[var(--color-muted)]">
              Oldest unresolved failure: {formatRelativeTime(fleet.oldest_unresolved_at)}
            </p>
          )}
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Open disputes targeting this hospital{" "}
          <span className="text-[var(--color-muted)]">({disputes.length})</span>
        </h2>
        <DataTable
          columns={disputeCols}
          rows={disputes}
          rowKey={(r, i) => `${r.repair_job_id ?? r.id ?? "x"}-${i}`}
          emptyMessage="No open disputes for this hospital."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          DPDP grievances from this hospital{" "}
          <span className="text-[var(--color-muted)]">({grievances.length})</span>
        </h2>
        <DataTable
          columns={grievanceCols}
          rows={grievances}
          rowKey={(r) => r.id}
          emptyMessage="No grievances on record."
        />
      </section>

      {pmForHospital.length > 0 && (
        <section>
          <h2 className="mb-2 text-sm font-semibold">
            Overdue preventive maintenance{" "}
            <span className="text-[var(--color-muted)]">({pmForHospital.length})</span>
          </h2>
          <DataTable
            columns={pmCols}
            rows={pmForHospital}
            rowKey={(r, i) => `${r.equipment_model ?? "x"}-${i}`}
            emptyMessage="No overdue PM tasks."
          />
        </section>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Audit log targeting this user_id{" "}
          <span className="text-[var(--color-muted)]">({audit.length})</span>
        </h2>
        <DataTable
          columns={auditCols}
          rows={audit}
          rowKey={(r) => r.id}
          emptyMessage="No founder actions targeting this hospital."
        />
      </section>
    </div>
  );
}
