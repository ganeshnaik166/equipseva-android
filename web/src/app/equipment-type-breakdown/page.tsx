import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Equipment type breakdown — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  equipment_type: string;
  total_jobs: number;
  completed_jobs: number;
  open_jobs: number;
  avg_completion_h: number | null;
};

export default async function EquipmentTypeBreakdownPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_equipment_type_breakdown");
  if (error) throw new Error(`founder_equipment_type_breakdown: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalJobs = rows.reduce((a, r) => a + (r.total_jobs ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "e", header: "Equipment type", render: (r) => <span className="text-xs font-medium">{r.equipment_type}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_jobs)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed_jobs)}</span> },
    { key: "o", header: "Open", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.open_jobs)}</span> },
    { key: "h", header: "Avg hrs to complete", render: (r) => <span className="text-xs tabular-nums">{r.avg_completion_h != null ? Number(r.avg_completion_h).toFixed(1) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Equipment type breakdown (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total jobs: <span className="font-mono tabular-nums">{formatNumber(totalJobs)}</span> · top 50 equipment types by volume
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.equipment_type} emptyMessage="No jobs in last 90 days." />
    </div>
  );
}
