import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "Referral bounty payouts by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  queued: number;
  paid: number;
  cancelled: number;
  paid_inr: number;
};

export default async function ReferralBountyPayoutsByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referral_bounty_payouts_by_month");
  if (error) throw new Error(`founder_referral_bounty_payouts_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalPaid = rows.reduce((a, r) => a + Number(r.paid_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.queued)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid)}</span> },
    { key: "c", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled)}</span> },
    { key: "i", header: "Paid INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.paid_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referral bounty payouts by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo cumulative paid: <span className="font-mono tabular-nums">{formatRupees(totalPaid)}</span> · growth-loop spend
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No referral bounty payouts in last 12 months." />
    </div>
  );
}
