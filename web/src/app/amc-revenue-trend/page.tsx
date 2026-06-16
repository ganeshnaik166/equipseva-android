import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC revenue trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; paid_orders: number; rupees_paid: number; failed_orders: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcRevenueTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_revenue_trend");
  if (error) throw new Error(`founder_amc_revenue_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalRupees = rows.reduce((s, r) => s + Number(r.rupees_paid), 0);
  const totalPaid = rows.reduce((s, r) => s + r.paid_orders, 0);
  const totalFailed = rows.reduce((s, r) => s + r.failed_orders, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "p", header: "Paid orders", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_orders)}</span> },
    { key: "r", header: "Rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.rupees_paid))}</span> },
    { key: "f", header: "Failed",
      render: (r) => {
        const tone = r.failed_orders > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{formatNumber(r.failed_orders)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC revenue trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · paid orders by updated_at</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="14d rupees" value={inr(totalRupees)} />
          <StatCard label="14d paid orders" value={formatNumber(totalPaid)} />
          <StatCard label="14d failed" value={formatNumber(totalFailed)} tone={totalFailed > 0 ? "danger" : "ok"} />
          <StatCard label="Daily avg rupees" value={inr(totalRupees / 14)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No AMC payments." />
    </div>
  );
}
