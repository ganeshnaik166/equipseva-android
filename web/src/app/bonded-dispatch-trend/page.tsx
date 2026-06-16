import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded dispatch trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; dispatches: number; total_qty: number; installed_total: number };

export default async function BondedDispatchTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_dispatch_trend");
  if (error) throw new Error(`founder_bonded_dispatch_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "p", header: "Dispatches", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.dispatches)}</span> },
    { key: "q", header: "Total qty", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_qty)}</span> },
    { key: "i", header: "Installed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.installed_total)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bonded dispatch trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14d · bonded_parts_dispatch</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No dispatches." />
    </div>
  );
}
