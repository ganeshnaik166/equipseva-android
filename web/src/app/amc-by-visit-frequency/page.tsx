import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC by visit frequency — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  visit_frequency: string;
  total: number;
  active: number;
  paused: number;
  expired: number;
  total_mrr_inr: number;
  avg_mrr_inr: number;
};

export default async function AmcByVisitFrequencyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_by_visit_frequency");
  if (error) throw new Error(`founder_amc_by_visit_frequency: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "v", header: "Visit frequency", render: (r) => <span className="text-xs font-medium uppercase tracking-wide">{r.visit_frequency}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active)}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused)}</span> },
    { key: "x", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired)}</span> },
    { key: "m", header: "Total MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
    { key: "av", header: "Avg MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.avg_mrr_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC by visit frequency</h1>
        <span className="text-xs text-[var(--color-muted)]">
          AMCs grouped by visit cadence (weekly/biweekly/monthly/quarterly) · service-tier mix
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.visit_frequency} emptyMessage="No AMC contracts." />
    </div>
  );
}
