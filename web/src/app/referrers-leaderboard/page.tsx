import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrers leaderboard — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { referrer_user_id: string; display_name: string; referrals_total: number; first_jobs: number; bounties_paid: number };

export default async function ReferrersLeaderboardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrers_leaderboard");
  if (error) throw new Error(`founder_referrers_leaderboard: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Referrer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "r", header: "Referrals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.referrals_total)}</span> },
    { key: "f", header: "First jobs", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.first_jobs)}</span> },
    { key: "b", header: "Bounties paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bounties_paid)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrers leaderboard</h1>
        <span className="text-xs text-[var(--color-muted)]">top 50 referrers ranked by referee first-job conversions</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.referrer_user_id} emptyMessage="No referrers." />
    </div>
  );
}
