import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Chains leaderboard — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { chain_id: string; name: string; member_count: number; active_amcs: number; jobs_30d: number };

export default async function ChainsLeaderboardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chains_leaderboard");
  if (error) throw new Error(`founder_chains_leaderboard: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Chain", render: (r) => <span className="text-xs">{r.name}</span> },
    { key: "m", header: "Members", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.member_count)}</span> },
    { key: "a", header: "Active AMCs", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_amcs)}</span> },
    { key: "j", header: "Jobs 30d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_30d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chains leaderboard</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 hospital chains by member count</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.chain_id} emptyMessage="No chains." />
    </div>
  );
}
