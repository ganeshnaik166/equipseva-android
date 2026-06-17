import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrers by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; referrers_cnt: number; referrals_90d: number; paid_bounties_90d: number };

export default async function ReferrersByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrers_by_tier");
  if (error) throw new Error(`founder_referrers_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Referrer tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "u", header: "Referrers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.referrers_cnt)}</span> },
    { key: "r", header: "Referrals (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.referrals_90d)}</span> },
    { key: "p", header: "Paid bounties (90d)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_bounties_90d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrers by tier (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Referral activity grouped by referrer&apos;s own cert tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No referrers." />
    </div>
  );
}
