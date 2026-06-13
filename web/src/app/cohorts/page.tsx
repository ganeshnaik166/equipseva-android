import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Cohorts — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type CohortRow = {
  cohort_month: string;
  cohort_size: number | null;
  retained_30d: number | null;
  retained_60d: number | null;
  retained_90d: number | null;
  retained_180d: number | null;
  retention_pct?: number | null;
};

export default async function CohortsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_cohort_retention", {
    p_months: 12,
  });
  if (error) throw new Error(`founder_hospital_cohort_retention: ${error.message}`);
  const rows = (data ?? []) as CohortRow[];

  const pctOf = (a: number | null | undefined, b: number | null | undefined) => {
    if (a == null || b == null || b === 0) return null;
    return (a / b) * 100;
  };

  const cols: Column<CohortRow>[] = [
    { key: "month", header: "Cohort month", render: (r) => r.cohort_month },
    { key: "size", header: "Size", render: (r) => formatNumber(r.cohort_size) },
    {
      key: "30d",
      header: "30d",
      render: (r) => (
        <span title={formatNumber(r.retained_30d) ?? undefined}>
          {formatPct(pctOf(r.retained_30d, r.cohort_size))}
        </span>
      ),
    },
    {
      key: "60d",
      header: "60d",
      render: (r) => <span>{formatPct(pctOf(r.retained_60d, r.cohort_size))}</span>,
    },
    {
      key: "90d",
      header: "90d",
      render: (r) => <span>{formatPct(pctOf(r.retained_90d, r.cohort_size))}</span>,
    },
    {
      key: "180d",
      header: "180d",
      render: (r) => <span>{formatPct(pctOf(r.retained_180d, r.cohort_size))}</span>,
    },
  ];

  return (
    <div className="space-y-4">
      <header>
        <h1 className="text-xl font-semibold">Hospital cohort retention</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Hospital signup-month cohorts from r499. Retention = % of cohort that completed at least one job in the
          trailing N-day window.
        </p>
      </header>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.cohort_month}
        emptyMessage="No cohorts yet."
      />
    </div>
  );
}
