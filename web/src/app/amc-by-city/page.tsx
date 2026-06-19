import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  city: string;
  total_amcs: number;
  active: number;
  paused: number;
  expired: number;
  active_mrr_inr: number;
};

export default async function AmcByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_by_city");
  if (error) throw new Error(`founder_amc_by_city: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandMrr = rows.reduce((a, r) => a + Number(r.active_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs font-medium">{r.city}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_amcs)}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active)}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused)}</span> },
    { key: "x", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired)}</span> },
    { key: "m", header: "Active MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.active_mrr_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC by city (top 50)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Per city · AMC status breakdown + active MRR · sorted by MRR desc · grand: <span className="font-mono tabular-nums">{formatRupees(grandMrr)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No AMC contracts." />
    </div>
  );
}
