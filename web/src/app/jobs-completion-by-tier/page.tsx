import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Jobs completion by tier — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { tier: string; accepted_90d: number; completed_90d: number; cancelled_90d: number; completion_pct: number };

export default async function JobsCompletionByTierPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_completion_by_tier");
  if (error) throw new Error(`founder_jobs_completion_by_tier: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Tier", render: (r) => <span className="text-xs font-semibold">{r.tier}</span> },
    { key: "a", header: "Accepted (90d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.accepted_90d)}</span> },
    { key: "c", header: "Completed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.completed_90d)}</span> },
    { key: "x", header: "Cancelled", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.cancelled_90d)}</span> },
    { key: "p", header: "Completion %",
      render: (r) => {
        const tone = r.completion_pct < 70 ? "text-[var(--color-danger)]"
          : r.completion_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.completion_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs completion by tier (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Engineer cert tier × accepted bid outcomes</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.tier} emptyMessage="No data." />
    </div>
  );
}
