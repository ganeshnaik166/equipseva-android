import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Repair jobs recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  hospital_name: string;
  equipment_type: string;
  status: string;
  contract_amount: number;
  created_at: string;
  completed_at: string | null;
};

export default async function RepairJobsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_repair_jobs_recent");
  if (error) throw new Error(`founder_repair_jobs_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs font-semibold">{r.hospital_name}</span> },
    { key: "e", header: "Equipment", render: (r) => <span className="text-xs">{r.equipment_type}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "completed" ? "text-[var(--color-ok)]"
          : r.status === "cancelled" ? "text-[var(--color-danger)]"
          : "text-[var(--color-warn)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "a", header: "Contract (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.contract_amount)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.completed_at ? new Date(r.completed_at).toLocaleString() : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Repair jobs recent (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 jobs created · live raw view</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No jobs." />
    </div>
  );
}
