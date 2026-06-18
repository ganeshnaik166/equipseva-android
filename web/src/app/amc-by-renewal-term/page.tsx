import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees } from "@/lib/format";

export const metadata = { title: "AMC by renewal term — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  renewal_term_months: number;
  total: number;
  active: number;
  paused: number;
  expired: number;
  total_mrr_inr: number;
};

export default async function AmcByRenewalTermPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_by_renewal_term");
  if (error) throw new Error(`founder_amc_by_renewal_term: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Term (months)", render: (r) => <span className="text-xs font-medium tabular-nums">{r.renewal_term_months}</span> },
    { key: "tot", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "a", header: "Active", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active)}</span> },
    { key: "p", header: "Paused", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.paused)}</span> },
    { key: "x", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired)}</span> },
    { key: "m", header: "Total MRR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_mrr_inr))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC by renewal term</h1>
        <span className="text-xs text-[var(--color-muted)]">
          AMCs grouped by contract length (months) · long-term commitment mix
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.renewal_term_months)} emptyMessage="No AMC contracts." />
    </div>
  );
}
