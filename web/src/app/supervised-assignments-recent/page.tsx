import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Supervised assignments recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  trainee_name: string;
  supervisor_name: string;
  status: string;
  requested_at: string;
  completed_at: string | null;
};

export default async function SupervisedAssignmentsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervised_assignments_recent");
  if (error) throw new Error(`founder_supervised_assignments_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "r", header: "Requested", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.requested_at).toLocaleString()}</span> },
    { key: "t", header: "Trainee", render: (r) => <span className="text-xs font-semibold">{r.trainee_name}</span> },
    { key: "s", header: "Supervisor", render: (r) => <span className="text-xs">{r.supervisor_name}</span> },
    { key: "st", header: "Status",
      render: (r) => {
        const tone = r.status === "completed_successful" ? "text-[var(--color-ok)]"
          : r.status === "completed_failed" || r.status === "declined" ? "text-[var(--color-danger)]"
          : "text-[var(--color-warn)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.completed_at ? new Date(r.completed_at).toLocaleString() : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervised assignments recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 trainee/supervisor pairs</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No supervised assignments." />
    </div>
  );
}
