import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bonded inventory — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  oem_brand: string;
  part_number: string;
  intake_lots: number;
  units_in_stock: number;
  units_dispatched: number;
  oldest_intake_days: number;
};

export default async function BondedInventoryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bonded_inventory");
  if (error) throw new Error(`founder_bonded_inventory: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalStock = rows.reduce((s, r) => s + (r.units_in_stock ?? 0), 0);
  const totalDisp = rows.reduce((s, r) => s + (r.units_dispatched ?? 0), 0);
  const distinct = rows.length;
  const cols: Column<Row>[] = [
    { key: "b", header: "Brand", render: (r) => <span className="text-xs">{r.oem_brand}</span> },
    { key: "p", header: "Part #", render: (r) => <code className="text-xs">{r.part_number}</code> },
    { key: "l", header: "Lots", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.intake_lots)}</span> },
    { key: "s", header: "In stock", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-ok)]">{formatNumber(r.units_in_stock)}</span> },
    { key: "d", header: "Dispatched", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.units_dispatched)}</span> },
    { key: "a", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{r.oldest_intake_days}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bonded inventory</h1>
        <span className="text-xs text-[var(--color-muted)]">r500 bonded-parts ledger rollup</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Distinct SKUs" value={formatNumber(distinct)} />
          <StatCard label="Units in stock" value={formatNumber(totalStock)} tone="ok" />
          <StatCard label="Units dispatched" value={formatNumber(totalDisp)} />
          <StatCard label="Dispatch ratio" value={totalStock + totalDisp > 0 ? `${Math.round((totalDisp / (totalStock + totalDisp)) * 100)}%` : "—"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.oem_brand}:${r.part_number}`} emptyMessage="No bonded inventory recorded." />
    </div>
  );
}
