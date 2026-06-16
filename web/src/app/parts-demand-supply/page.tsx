import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Parts demand vs supply — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { brand: string; part_number: string; demand_signals: number; in_stock: number; gap: number };

export default async function PartsDemandSupplyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_parts_demand_supply");
  if (error) throw new Error(`founder_parts_demand_supply: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Brand", render: (r) => <span className="text-xs">{r.brand}</span> },
    { key: "p", header: "Part #", render: (r) => <span className="text-xs">{r.part_number}</span> },
    { key: "d", header: "Demand (90d)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.demand_signals)}</span> },
    { key: "s", header: "In stock", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.in_stock)}</span> },
    { key: "g", header: "Gap",
      render: (r) => {
        const tone = r.gap > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-ok)]";
        const sign = r.gap > 0 ? "+" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{sign}{formatNumber(r.gap)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Parts demand vs supply</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 SKUs by gap (demand − bonded stock)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => `${r.brand}|${r.part_number}`} emptyMessage="No demand signals." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Gap &gt; 0 = demand outstrips bonded supply — sourcing priority. Demand window = 90 days; stock = bonded_parts_intake.status=&apos;in_stock&apos;.
      </section>
    </div>
  );
}
