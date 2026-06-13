import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime } from "@/lib/format";
import { DpdpActions } from "./DpdpActions";

export const metadata = { title: "DPDP grievances — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type GrievanceRow = {
  id: string;
  grievance_type?: string | null;
  status: string | null;
  requester_email?: string | null;
  description?: string | null;
  deadline_at?: string | null;
  created_at: string;
};

export default async function DpdpPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dpdp_grievances_list", { p_limit: 100 });
  if (error) throw new Error(`founder_dpdp_grievances_list: ${error.message}`);
  const rows = (data ?? []) as GrievanceRow[];

  const cols: Column<GrievanceRow>[] = [
    {
      key: "created",
      header: "Filed",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    {
      key: "deadline",
      header: "Deadline",
      render: (r) => {
        const overdue = r.deadline_at != null && new Date(r.deadline_at).getTime() < Date.now();
        return (
          <span className={overdue ? "text-[var(--color-danger)]" : "text-[var(--color-warn)]"}>
            {formatRelativeTime(r.deadline_at ?? null)}
          </span>
        );
      },
    },
    { key: "kind", header: "Type", render: (r) => r.grievance_type ?? "—" },
    { key: "from", header: "From", render: (r) => r.requester_email ?? "—" },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const s = (r.status ?? "").toLowerCase();
        const cls =
          s === "open"
            ? "bg-yellow-100 text-[var(--color-warn)]"
            : s === "in_progress"
              ? "bg-blue-100"
              : s === "resolved"
                ? "bg-green-100 text-[var(--color-ok)]"
                : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status ?? "—"}</span>;
      },
    },
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
    {
      key: "act",
      header: "Action",
      render: (r) => <DpdpActions grievanceId={r.id} />,
    },
  ];

  return (
    <div className="space-y-4">
      <header>
        <h1 className="text-xl font-semibold">
          DPDP grievances <span className="text-[var(--color-muted)]">({rows.length})</span>
        </h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          DPDP Act 2023 grievance officer queue from r485. 30-day deadline on every request; overdue rows flagged red.
        </p>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No grievances filed." />
    </div>
  );
}
