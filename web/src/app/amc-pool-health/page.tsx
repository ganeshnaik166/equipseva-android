import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool health — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; contract_count: number; total_balance: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcPoolHealthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_health");
  if (error) throw new Error(`founder_amc_pool_health: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Bucket",
      render: (r) => {
        const tone = r.bucket.startsWith("Negative") ? "text-[var(--color-danger)]"
          : r.bucket.startsWith("Empty") ? "text-[var(--color-warn)]"
          : r.bucket.startsWith("Low") ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.bucket}</span>;
      }
    },
    { key: "c", header: "Contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.contract_count)}</span> },
    { key: "t", header: "Total balance", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.total_balance))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool health</h1>
        <span className="text-xs text-[var(--color-muted)]">balance distribution from latest amc_payment_pool ledger entry</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No pool data." />
    </div>
  );
}
