import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC payment orders status — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; order_count: number; total_rupees: number; oldest_days: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcPaymentOrdersStatusPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_payment_orders_status");
  if (error) throw new Error(`founder_amc_payment_orders_status: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "paid" ? "text-[var(--color-ok)]"
          : r.status === "failed" ? "text-[var(--color-danger)]"
          : r.status === "pending" ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.order_count)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.total_rupees))}</span> },
    { key: "o", header: "Oldest", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.oldest_days)}d</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC payment orders status</h1>
        <span className="text-xs text-[var(--color-muted)]">distribution across pending/paid/failed/refunded</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No payment orders." />
    </div>
  );
}
