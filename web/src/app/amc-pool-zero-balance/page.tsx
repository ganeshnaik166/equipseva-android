import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC pool zero balance — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  tier: string;
  total_active_amcs: number;
  zero_balance_cnt: number;
  zero_balance_pct: number;
  blocked_mrr_inr: number;
};

export default async function AmcPoolZeroBalancePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_zero_balance");
  if (error) throw new Error(`founder_amc_pool_zero_balance: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandZero = rows.reduce((a, r) => a + (r.zero_balance_cnt ?? 0), 0);
  const grandMRR = rows.reduce((a, r) => a + (r.blocked_mrr_inr ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-medium uppercase tracking-wide">{r.tier}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_active_amcs)}</span> },
    { key: "z", header: "Zero balance", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.zero_balance_cnt)}</span> },
    { key: "p", header: "%", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.zero_balance_pct) / 100)}</span> },
    { key: "m", header: "Blocked MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(r.blocked_mrr_inr)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool zero balance × tier</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Zero-balance AMCs: <span className="font-mono tabular-nums text-[var(--color-danger)]">{formatNumber(grandZero)}</span> · blocked MRR: <span className="font-mono tabular-nums">{formatRupees(grandMRR)}</span> · hospitals can't book free services
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No active AMCs." />
    </div>
  );
}
