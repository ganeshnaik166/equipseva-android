import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Commission vs payout — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; gmv: number; commission_est: number; payouts_paid: number; net_take: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function CommissionVsPayoutPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_commission_vs_payout");
  if (error) throw new Error(`founder_commission_vs_payout: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "g", header: "GMV", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.gmv))}</span> },
    { key: "c", header: "Commission (est)", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.commission_est))}</span> },
    { key: "p", header: "Engineer paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{inr(Number(r.payouts_paid))}</span> },
    { key: "n", header: "Net (GMV − paid)", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.net_take))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Commission vs payout</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month GMV vs engineer payout · net take</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No data." />
    </div>
  );
}
