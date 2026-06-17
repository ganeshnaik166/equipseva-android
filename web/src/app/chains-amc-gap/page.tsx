import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Chains AMC gap — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { chain_id: string; name: string; member_count: number; members_with_amc: number; members_without_amc: number; amc_coverage_pct: number };

export default async function ChainsAmcGapPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chains_amc_gap");
  if (error) throw new Error(`founder_chains_amc_gap: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Chain", render: (r) => <span className="text-xs font-semibold">{r.name}</span> },
    { key: "m", header: "Members", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.member_count)}</span> },
    { key: "y", header: "With AMC", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.members_with_amc)}</span> },
    { key: "w", header: "Without AMC", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)] font-semibold">{formatNumber(r.members_without_amc)}</span> },
    { key: "p", header: "Coverage %",
      render: (r) => {
        const tone = r.amc_coverage_pct < 50 ? "text-[var(--color-danger)]"
          : r.amc_coverage_pct < 80 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.amc_coverage_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chains AMC gap</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 chains by members without AMC · sales-outreach queue</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.chain_id} emptyMessage="No chains." />
    </div>
  );
}
