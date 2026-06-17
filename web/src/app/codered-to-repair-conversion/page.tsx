import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red → repair conversion — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; code_red_total: number; spawned_repair: number; completed: number; conversion_pct: number };

export default async function CoderedToRepairConversionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_codered_to_repair_conversion");
  if (error) throw new Error(`founder_codered_to_repair_conversion: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "t", header: "Code Red opened", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.code_red_total)}</span> },
    { key: "s", header: "Spawned repair", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.spawned_repair)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed)}</span> },
    { key: "p", header: "Conversion %", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.conversion_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red → repair job conversion</h1>
        <span className="text-xs text-[var(--color-muted)]">% emergency requests that spawned a real repair_jobs row</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No code red." />
    </div>
  );
}
