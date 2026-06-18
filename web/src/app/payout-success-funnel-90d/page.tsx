import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatPct } from "@/lib/format";

export const metadata = { title: "Payout success funnel 90d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  stage: string;
  stage_order: number;
  payouts: number;
  total_inr: number;
  pct_of_queued: number;
};

export default async function PayoutSuccessFunnel90dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payout_success_funnel_90d");
  if (error) throw new Error(`founder_payout_success_funnel_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const q = rows.find(r => r.stage_order === 0);
  const proc = rows.find(r => r.stage_order === 2);
  const failed = rows.find(r => r.stage_order === 3);
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => (
      <span className={`text-xs ${r.stage_order === 2 ? "font-medium text-[var(--color-ok)]" : r.stage_order === 3 ? "font-medium text-[var(--color-danger)]" : ""}`}>{r.stage}</span>
    ) },
    { key: "c", header: "Payouts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.payouts)}</span> },
    { key: "t", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
    { key: "p", header: "% of queued", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_queued) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payout success funnel (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Queued: <span className="font-mono tabular-nums">{formatNumber(q?.payouts ?? 0)}</span> · Processed: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(proc?.payouts ?? 0)}</span> · Failed: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(failed?.payouts ?? 0)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.stage_order)} emptyMessage="No payouts in last 90d." />
    </div>
  );
}
