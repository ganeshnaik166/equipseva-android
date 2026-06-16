import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referral volume trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; referrals: number; first_jobs: number; bounties_paid: number };

export default async function ReferralVolumeTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referral_volume_trend");
  if (error) throw new Error(`founder_referral_volume_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalRef = rows.reduce((s, r) => s + r.referrals, 0);
  const totalFirst = rows.reduce((s, r) => s + r.first_jobs, 0);
  const totalBounty = rows.reduce((s, r) => s + r.bounties_paid, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "r", header: "Referrals", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.referrals)}</span> },
    { key: "f", header: "First jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.first_jobs)}</span> },
    { key: "b", header: "Bounties paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bounties_paid)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referral volume trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="14d referrals" value={formatNumber(totalRef)} />
          <StatCard label="14d first-jobs" value={formatNumber(totalFirst)} tone="ok" />
          <StatCard label="14d bounties" value={formatNumber(totalBounty)} tone="ok" />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No referral activity." />
    </div>
  );
}
