import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs by equipment type — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { equipment_type: string; jobs_count: number; gross_rupees: number; avg_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function JobsByEquipmentTypePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_by_equipment_type");
  if (error) throw new Error(`founder_jobs_by_equipment_type: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "e", header: "Equipment type", render: (r) => <span className="text-xs">{r.equipment_type}</span> },
    { key: "j", header: "Jobs", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.jobs_count)}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.gross_rupees))}</span> },
    { key: "a", header: "Avg / job", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{inr(Number(r.avg_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs by equipment type</h1>
        <span className="text-xs text-[var(--color-muted)]">90d completed jobs by equipment category</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.equipment_type} emptyMessage="No completed jobs." />
    </div>
  );
}
