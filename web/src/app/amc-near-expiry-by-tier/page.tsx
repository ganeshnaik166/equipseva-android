import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC near expiry by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; expiring_30d: number; expiring_60d: number; expiring_90d: number; mrr_at_risk: number };

export default async function AmcNearExpiryByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_near_expiry_by_tier");
  if (error) throw new Error(`founder_amc_near_expiry_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "a", header: "Expiring 30d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expiring_30d)}</span> },
    { key: "b", header: "Expiring 60d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.expiring_60d)}</span> },
    { key: "c", header: "Expiring 90d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.expiring_90d)}</span> },
    { key: "m", header: "MRR at risk (30d, ₹)", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.mrr_at_risk)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC near expiry by tier</h1>
        <span className="text-xs text-[var(--color-muted)]">Active contracts expiring in 30/60/90d, per tier</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No tiers." />
    </div>
  );
}
