import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts by mode — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { mode: string; processed_90d: number; failed_90d: number; paid_rupees: number; fail_pct: number };

export default async function PayoutsByModePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_mode");
  if (error) throw new Error(`founder_payouts_by_mode: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Mode", render: (r) => <span className="text-xs font-semibold">{r.mode}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed_90d)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_90d)}</span> },
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
        <h1 className="text-xl font-semibold">Payouts by mode (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">UPI / IMPS / NEFT / RTGS · processed vs failed</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.mode} emptyMessage="No payouts." />
    </div>
  );
}
