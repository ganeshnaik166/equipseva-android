import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal by tenure — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tenure_bucket: string; attempted_90d: number; succeeded_90d: number; success_pct: number };

export default async function AmcRenewalByTenurePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_by_tenure");
  if (error) throw new Error(`founder_amc_renewal_by_tenure: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Contract tenure", render: (r) => <span className="text-xs font-semibold">{r.tenure_bucket}</span> },
    { key: "a", header: "Attempted", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.attempted_90d)}</span> },
    { key: "s", header: "Succeeded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.succeeded_90d)}</span> },
    { key: "p", header: "Success %",
      render: (r) => {
        const tone = r.success_pct < 70 ? "text-[var(--color-danger)]"
          : r.success_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.success_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal by tenure (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Renewal success % bucketed by contract age</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tenure_bucket} emptyMessage="No renewal attempts." />
    </div>
  );
}
