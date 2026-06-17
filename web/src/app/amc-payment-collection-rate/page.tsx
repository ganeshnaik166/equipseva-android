import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC payment collection rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; total_orders: number; paid_orders: number; failed_orders: number; collection_pct: number };

export default async function AmcPaymentCollectionRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_payment_collection_rate");
  if (error) throw new Error(`founder_amc_payment_collection_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "t", header: "Orders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_orders)}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_orders)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_orders)}</span> },
    { key: "c", header: "Collection %",
      render: (r) => {
        const tone = r.collection_pct < 80 ? "text-[var(--color-danger)]"
          : r.collection_pct < 95 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.collection_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC payment collection rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of AMC payment orders that got paid · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No payment orders." />
    </div>
  );
}
