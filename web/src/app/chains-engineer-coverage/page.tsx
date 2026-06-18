import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Chains engineer coverage — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  chain_name: string;
  member_hospitals: number;
  distinct_cities: number;
  engineers_in_those_cities: number;
  verified_engineers: number;
  coverage_pct: number;
};

export default async function ChainsEngineerCoveragePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chains_engineer_coverage");
  if (error) throw new Error(`founder_chains_engineer_coverage: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Chain", render: (r) => <span className="text-xs font-medium">{r.chain_name}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.member_hospitals)}</span> },
    { key: "c", header: "Cities", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.distinct_cities)}</span> },
    { key: "e", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineers_in_those_cities)}</span> },
    { key: "v", header: "Verified", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.verified_engineers)}</span> },
    { key: "p", header: "Verified %", render: (r) => {
        const v = Number(r.coverage_pct);
        const tone = v >= 60 ? "text-[var(--color-ok)]" : v >= 30 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chains engineer coverage</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Per chain: member hospitals + distinct cities + engineer supply in those cities + verified % · supply-readiness signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.chain_name} emptyMessage="No hospital chains." />
    </div>
  );
}
