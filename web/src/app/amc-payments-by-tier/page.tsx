import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC payments by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; paid_orders_90d: number; paid_rupees_90d: number; active_contracts: number };

export default async function AmcPaymentsByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_payments_by_tier");
  if (error) throw new Error(`founder_amc_payments_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "o", header: "Paid orders 90d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paid_orders_90d)}</span> },
    { key: "r", header: "Paid 90d (₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.paid_rupees_90d)}</span> },
    { key: "a", header: "Active contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_contracts)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC payments by tier (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">90d paid order rupees rolled up by AMC tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No tiers." />
    </div>
  );
}
