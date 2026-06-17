import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC by day of week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { dow_num: number; dow_label: string; new_amcs: number; new_mrr: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcByDayOfWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_by_day_of_week");
  if (error) throw new Error(`founder_amc_by_day_of_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Day", render: (r) => <span className="text-xs font-semibold">{r.dow_label}</span> },
    { key: "n", header: "New AMCs (180d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.new_amcs)}</span> },
    { key: "m", header: "New MRR", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{inr(Number(r.new_mrr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC by day of week</h1>
        <span className="text-xs text-[var(--color-muted)]">180d distribution by signup weekday</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.dow_label} emptyMessage="No AMCs." />
    </div>
  );
}
