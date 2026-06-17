import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrals cumulative — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; referrals: number; cum_referrals: number; first_jobs: number; cum_first_jobs: number };

export default async function ReferralsCumulativePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrals_cumulative");
  if (error) throw new Error(`founder_referrals_cumulative: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "r", header: "Referrals (m)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">+{formatNumber(r.referrals)}</span> },
    { key: "cr", header: "Cum referrals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_referrals)}</span> },
    { key: "f", header: "First jobs (m)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.first_jobs)}</span> },
    { key: "cf", header: "Cum first jobs", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.cum_first_jobs)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrals cumulative</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month cumulative referrals + first-jobs</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No referral activity." />
    </div>
  );
}
