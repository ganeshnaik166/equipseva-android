import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referrals by month × status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; signups: number; first_jobs: number; eligible: number; paid: number };

export default async function ReferralsByMonthByStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrals_by_month_by_status");
  if (error) throw new Error(`founder_referrals_by_month_by_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "s", header: "Signups", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.signups)}</span> },
    { key: "f", header: "First job", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.first_jobs)}</span> },
    { key: "e", header: "Eligible", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.eligible)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrals by month × status (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Monthly referral cohort funnel: signup → first job → eligible → paid</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No referrals." />
    </div>
  );
}
