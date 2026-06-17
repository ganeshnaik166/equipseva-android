import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrals by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { week_start: string; referrals: number; first_jobs: number; bounties_paid: number };

export default async function ReferralsByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrals_by_week");
  if (error) throw new Error(`founder_referrals_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs">{new Date(r.week_start).toLocaleDateString("en-IN", { day: "numeric", month: "short" })}</span> },
    { key: "r", header: "Referrals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.referrals)}</span> },
    { key: "f", header: "First jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.first_jobs)}</span> },
    { key: "b", header: "Bounties paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bounties_paid)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrals by week</h1>
        <span className="text-xs text-[var(--color-muted)]">last 13 weeks · IST</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No referral activity." />
    </div>
  );
}
