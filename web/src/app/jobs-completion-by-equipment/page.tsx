import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs completion hours by equipment — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { equipment_type: string; jobs_90d: number; p50_hours: number; p90_hours: number; avg_hours: number };

export default async function JobsCompletionByEquipmentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_completion_by_equipment");
  if (error) throw new Error(`founder_jobs_completion_by_equipment: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "e", header: "Equipment", render: (r) => <span className="text-xs">{r.equipment_type}</span> },
    { key: "j", header: "Jobs (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_90d)}</span> },
    { key: "p", header: "p50 hours", render: (r) => <span className="text-xs tabular-nums">{r.p50_hours}</span> },
    { key: "x", header: "p90 hours", render: (r) => <span className="text-xs tabular-nums">{r.p90_hours}</span> },
    { key: "a", header: "Avg hours", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.avg_hours}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs completion hours by equipment (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 equipment types · p50/p90/avg posted → completed</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.equipment_type} emptyMessage="No completed jobs." />
    </div>
  );
}
