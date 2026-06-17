import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool credits source — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { month_ist: string; credit_rupees: number; debit_rupees: number; refund_rupees: number; net_rupees: number };

export default async function AmcPoolCreditsSourcePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_credits_source");
  if (error) throw new Error(`founder_amc_pool_credits_source: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "c", header: "Credit (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.credit_rupees)}</span> },
    { key: "d", header: "Debit (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.debit_rupees)}</span> },
    { key: "r", header: "Refund (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.refund_rupees)}</span> },
    { key: "n", header: "Net (₹)",
      render: (r) => {
        const tone = r.net_rupees < 0 ? "text-[var(--color-danger)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.net_rupees)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool credits source (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">Credit / debit / refund / net per month</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No pool activity." />
    </div>
  );
}
