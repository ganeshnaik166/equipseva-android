import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red by equipment — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { equipment_type: string; cnt_90d: number; resolved_90d: number; timed_out_90d: number; resolution_pct: number };

export default async function CodeRedByEquipmentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_equipment");
  if (error) throw new Error(`founder_code_red_by_equipment: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "e", header: "Equipment", render: (r) => <span className="text-xs">{r.equipment_type}</span> },
    { key: "c", header: "Code Red (90d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cnt_90d)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved_90d)}</span> },
    { key: "t", header: "Timed out", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.timed_out_90d)}</span> },
    { key: "p", header: "Resolution %",
      render: (r) => {
        const tone = r.resolution_pct < 60 ? "text-[var(--color-danger)]"
          : r.resolution_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.resolution_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by equipment (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 equipment types · resolution % per category</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.equipment_type} emptyMessage="No code red." />
    </div>
  );
}
