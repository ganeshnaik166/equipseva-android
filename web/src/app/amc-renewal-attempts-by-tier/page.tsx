import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Renewal attempts by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; attempts: number; succeeded: number; failed: number; abandoned: number };

export default async function AmcRenewalAttemptsByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_attempts_by_tier");
  if (error) throw new Error(`founder_amc_renewal_attempts_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "a", header: "Attempts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.attempts)}</span> },
    { key: "s", header: "Succeeded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.succeeded)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "x", header: "Abandoned", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.abandoned)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Renewal attempts by tier (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Per-tier renewal attempt outcome counts</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No tiers." />
    </div>
  );
}
