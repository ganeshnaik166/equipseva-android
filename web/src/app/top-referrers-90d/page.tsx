import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Top referrers (90d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { referrer_user_id: string; display_name: string; referrals_90d: number; paid_bounties_90d: number; total_bounty_rupees: number };

export default async function TopReferrers90dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_top_referrers_90d");
  if (error) throw new Error(`founder_top_referrers_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Referrer", render: (r) => <span className="text-xs font-semibold">{r.display_name}</span> },
    { key: "r", header: "Referrals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.referrals_90d)}</span> },
    { key: "p", header: "Paid bounties", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_bounties_90d)}</span> },
    { key: "b", header: "Total bounty (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.total_bounty_rupees)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Top referrers (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 by paid bounty volume</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.referrer_user_id} emptyMessage="No referrers." />
    </div>
  );
}
