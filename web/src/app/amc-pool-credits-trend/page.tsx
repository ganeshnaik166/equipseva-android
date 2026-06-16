import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool credits trend — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; credit_rupees: number; debit_rupees: number; refund_rupees: number; events: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcPoolCreditsTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_credits_trend");
  if (error) throw new Error(`founder_amc_pool_credits_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "c", header: "Credit", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{inr(Number(r.credit_rupees))}</span> },
    { key: "b", header: "Debit", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{inr(Number(r.debit_rupees))}</span> },
    { key: "r", header: "Refund", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{inr(Number(r.refund_rupees))}</span> },
    { key: "e", header: "Events", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{formatNumber(r.events)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool credits trend</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14d · IST · ledger movements</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No pool activity." />
    </div>
  );
}
