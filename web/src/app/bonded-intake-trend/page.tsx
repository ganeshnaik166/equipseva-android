import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded intake trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; intake_rows: number; qty_received: number; total_cost: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function BondedIntakeTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_intake_trend");
  if (error) throw new Error(`founder_bonded_intake_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "r", header: "Intake rows", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.intake_rows)}</span> },
    { key: "q", header: "Qty received", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.qty_received)}</span> },
    { key: "c", header: "Total cost", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.total_cost))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bonded intake trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14d · IST · bonded_parts_intake</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No intake." />
    </div>
  );
}
