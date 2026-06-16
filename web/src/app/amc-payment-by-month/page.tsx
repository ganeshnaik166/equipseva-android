import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC payment by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; paid_count: number; paid_rupees: number; failed_count: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcPaymentByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_payment_by_month");
  if (error) throw new Error(`founder_amc_payment_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs">{new Date(r.month_ist).toLocaleDateString("en-IN", { month: "short", year: "numeric" })}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_count)}</span> },
    { key: "r", header: "Rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.paid_rupees))}</span> },
    { key: "f", header: "Failed", render: (r) => <span className={`text-xs tabular-nums ${r.failed_count > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatNumber(r.failed_count)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC payment by month</h1>
        <span className="text-xs text-[var(--color-muted)]">12-month AMC payment orders trend</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No AMC payments." />
    </div>
  );
}
