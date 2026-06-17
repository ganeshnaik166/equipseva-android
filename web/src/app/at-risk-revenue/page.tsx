import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "At-risk revenue — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { category: string; count_v: number; rupees_v: number; ord: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AtRiskRevenuePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_at_risk_revenue");
  if (error) throw new Error(`founder_at_risk_revenue: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandTotal = rows.reduce((s, r) => s + Number(r.rupees_v), 0);
  const grandCount = rows.reduce((s, r) => s + r.count_v, 0);
  const cols: Column<Row>[] = [
    { key: "c", header: "Category", render: (r) => <span className="text-xs font-semibold">{r.category}</span> },
    { key: "n", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.count_v)}</span> },
    { key: "r", header: "Rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.rupees_v))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">At-risk revenue</h1>
        <span className="text-xs text-[var(--color-muted)]">consolidated view across 6 leak categories</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Total at-risk rupees" value={inr(grandTotal)} tone={grandTotal > 0 ? "warn" : "ok"} />
          <StatCard label="Total at-risk items" value={formatNumber(grandCount)} tone={grandCount > 0 ? "warn" : "ok"} />
          <StatCard label="Categories tracked" value={formatNumber(rows.length)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.category} emptyMessage="Clean state — no at-risk revenue tracked." />
    </div>
  );
}
