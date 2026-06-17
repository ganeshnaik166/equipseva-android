import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital AMC coverage by city — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { city: string; hospitals_total: number; with_amc: number; without_amc: number; coverage_pct: number };

export default async function HospitalAmcCoverageByCityPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_amc_coverage_by_city");
  if (error) throw new Error(`founder_hospital_amc_coverage_by_city: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "c", header: "City", render: (r) => <span className="text-xs">{r.city}</span> },
    { key: "t", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospitals_total)}</span> },
    { key: "y", header: "With AMC", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.with_amc)}</span> },
    { key: "w", header: "Without", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.without_amc)}</span> },
    { key: "p", header: "Coverage %",
      render: (r) => {
        const tone = r.coverage_pct < 30 ? "text-[var(--color-danger)]"
          : r.coverage_pct < 60 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.coverage_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital AMC coverage by city</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 cities · AMC penetration % · sales prioritization signal</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.city} emptyMessage="No hospitals." />
    </div>
  );
}
