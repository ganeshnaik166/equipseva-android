import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatPct } from "@/lib/format";

export const metadata = { title: "AMC renewal funnel 90d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  stage: string;
  stage_order: number;
  contracts: number;
  total_mrr_inr: number;
  pct_of_due: number;
};

export default async function AmcRenewalFunnel90dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_funnel_90d");
  if (error) throw new Error(`founder_amc_renewal_funnel_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const due = rows.find(r => r.stage_order === 0);
  const renewed = rows.find(r => r.stage_order === 4);
  const expired = rows.find(r => r.stage_order === 5);
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => (
      <span className={`text-xs ${r.stage_order === 4 ? "font-medium text-[var(--color-ok)]" : r.stage_order === 5 ? "font-medium text-[var(--color-danger)]" : ""}`}>{r.stage}</span>
    ) },
    { key: "c", header: "Contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.contracts)}</span> },
    { key: "m", header: "Total MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
    { key: "p", header: "% of due", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_due) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal funnel (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Due: <span className="font-mono tabular-nums">{formatNumber(due?.contracts ?? 0)}</span> · Renewed: <span className="font-mono tabular-nums text-[var(--color-ok)]">{formatNumber(renewed?.contracts ?? 0)}</span> · Expired: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(expired?.contracts ?? 0)}</span>
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.stage_order)} emptyMessage="No renewal-due contracts in last 90d." />
    </div>
  );
}
