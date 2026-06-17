import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital retention cohort — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { cohort_week_start: string; cohort_size: number; active_last_30d: number; retention_pct: number };

export default async function HospitalRetentionCohortPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_retention_cohort");
  if (error) throw new Error(`founder_hospital_retention_cohort: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Cohort week", render: (r) => <span className="text-xs tabular-nums">{r.cohort_week_start}</span> },
    { key: "s", header: "Cohort size", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cohort_size)}</span> },
    { key: "a", header: "Active 30d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_last_30d)}</span> },
    { key: "p", header: "Retention %",
      render: (r) => {
        const tone = r.retention_pct < 25 ? "text-[var(--color-danger)]"
          : r.retention_pct < 50 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.retention_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital retention cohort</h1>
        <span className="text-xs text-[var(--color-muted)]">Signup week × posted job in last 30d (12wk window)</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.cohort_week_start} emptyMessage="No cohorts." />
    </div>
  );
}
