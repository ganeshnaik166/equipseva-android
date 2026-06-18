import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC renewal window 90d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  tier: string;
  total: number;
  active: number;
  paused: number;
  expired: number;
  total_mrr_inr: number;
};

export default async function AmcRenewalWindow90dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_window_90d");
  if (error) throw new Error(`founder_amc_renewal_window_90d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandMRR = rows.reduce((a, r) => a + (r.total_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-medium uppercase tracking-wide">{r.tier}</span> },
    { key: "tot", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active)}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused)}</span> },
    { key: "e", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired)}</span> },
    { key: "m", header: "MRR at risk", render: (r) => <span className="text-xs tabular-nums">{formatRupees(r.total_mrr_inr)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal window 90d</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Renewing in next 90d · grand MRR at risk: <span className="font-mono tabular-nums text-[var(--color-warn)]">{formatRupees(grandMRR)}</span> · long pipeline view
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No AMC contracts renewing in next 90 days." />
    </div>
  );
}
