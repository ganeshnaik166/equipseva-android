import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Chains AMC leaderboard — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  chain_name: string;
  member_hospitals: number;
  active_amcs: number;
  total_mrr_inr: number;
  paused_amcs: number;
  expired_amcs: number;
};

export default async function ChainsAmcLeaderboardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chains_amc_leaderboard");
  if (error) throw new Error(`founder_chains_amc_leaderboard: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrr = rows.reduce((a, r) => a + Number(r.total_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "n", header: "Chain", render: (r) => <span className="text-xs font-medium">{r.chain_name}</span> },
    { key: "m", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.member_hospitals)}</span> },
    { key: "a", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_amcs)}</span> },
    { key: "mrr", header: "MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused_amcs)}</span> },
    { key: "e", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired_amcs)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chains AMC leaderboard</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 chains by aggregated active MRR · grand total: <span className="font-mono tabular-nums">{formatRupees(totalMrr)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.chain_name} emptyMessage="No hospital chains." />
    </div>
  );
}
