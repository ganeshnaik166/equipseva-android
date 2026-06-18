import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatRelativeTime } from "@/lib/format";

export const metadata = { title: "Referral bounty leaderboard — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  referrer_name: string;
  total_bounties: number;
  paid_cnt: number;
  queued_cnt: number;
  cancelled_cnt: number;
  total_paid_inr: number;
  last_bounty_at: string | null;
};

export default async function ReferralBountyLeaderboardPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referral_bounty_leaderboard");
  if (error) throw new Error(`founder_referral_bounty_leaderboard: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Referrer", render: (r) => <span className="text-xs font-medium">{r.referrer_name}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_bounties)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_cnt)}</span> },
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.queued_cnt)}</span> },
    { key: "c", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled_cnt)}</span> },
    { key: "i", header: "Paid INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_paid_inr))}</span> },
    { key: "l", header: "Last", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{r.last_bounty_at ? formatRelativeTime(r.last_bounty_at) : "—"}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referral bounty leaderboard</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Top 50 referrers (beneficiaries) by total bounties · paid/queued/cancelled split
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.referrer_name} emptyMessage="No referral bounties yet." />
    </div>
  );
}
