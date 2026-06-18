import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC by equipment category — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  equipment_category: string;
  total: number;
  active: number;
  paused: number;
  expired: number;
  total_mrr_inr: number;
};

export default async function AmcByEquipmentCategoryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_by_equipment_category");
  if (error) throw new Error(`founder_amc_by_equipment_category: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandMrr = rows.reduce((a, r) => a + Number(r.total_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "e", header: "Equipment category", render: (r) => <span className="text-xs font-medium">{r.equipment_category}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active)}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused)}</span> },
    { key: "x", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired)}</span> },
    { key: "m", header: "Active MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC by equipment category</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 categories by active MRR · grand: <span className="font-mono tabular-nums">{formatRupees(grandMrr)}</span> · equipment-mix signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.equipment_category} emptyMessage="No AMC contracts with equipment categories." />
    </div>
  );
}
