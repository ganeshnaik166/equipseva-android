import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Referral payout conversion — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; signed_up: number; completed_first: number; bounty_paid: number; signup_to_paid_pct: number };

export default async function ReferralPayoutConversionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referral_payout_conversion");
  if (error) throw new Error(`founder_referral_payout_conversion: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "s", header: "Signed up", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.signed_up)}</span> },
    { key: "f", header: "First job done", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed_first)}</span> },
    { key: "p", header: "Bounty paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.bounty_paid)}</span> },
    { key: "x", header: "Signup → Paid %",
      render: (r) => <span className="text-xs tabular-nums font-semibold">{r.signup_to_paid_pct}%</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referral signup → paid conversion</h1>
        <span className="text-xs text-[var(--color-muted)]">% of referees that signed up → first job → bounty paid</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No referrals." />
    </div>
  );
}
