import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts by bank — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bank_name: string; processed: number; failed: number; paid_rupees: number; fail_pct: number };

export default async function PayoutsByBankPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_bank");
  if (error) throw new Error(`founder_payouts_by_bank: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Bank", render: (r) => <span className="text-xs">{r.bank_name}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "r", header: "Paid (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paid_rupees)}</span> },
    { key: "x", header: "Fail %",
      render: (r) => {
        const tone = r.fail_pct > 10 ? "text-[var(--color-danger)]"
          : r.fail_pct > 3 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.fail_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by bank (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Top 50 destination banks · processed vs failed</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bank_name} emptyMessage="No payouts." />
    </div>
  );
}
