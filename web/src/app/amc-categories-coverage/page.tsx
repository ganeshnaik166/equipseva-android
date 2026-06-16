import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC categories coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { category: string; contract_count: number; monthly_mrr: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcCategoriesCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_categories_coverage");
  if (error) throw new Error(`founder_amc_categories_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "Category", render: (r) => <span className="text-xs">{r.category}</span> },
    { key: "k", header: "Contracts", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.contract_count)}</span> },
    { key: "m", header: "MRR", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_mrr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC categories coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">active AMCs unrolled by equipment_categories[] · top 50</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.category} emptyMessage="No category data." />
    </div>
  );
}
