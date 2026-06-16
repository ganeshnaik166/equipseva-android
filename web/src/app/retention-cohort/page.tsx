import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Retention cohort — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { cohort_week_start: string; cohort_size: number; active_last_30d: number; retention_pct: number };

export default async function RetentionCohortPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_retention_cohort");
  if (error) throw new Error(`founder_retention_cohort: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Cohort week",
      render: (r) => <span className="text-xs">{new Date(r.cohort_week_start).toLocaleDateString("en-IN")}</span>
    },
    { key: "s", header: "Size", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cohort_size)}</span> },
    { key: "a", header: "Active (30d)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.active_last_30d)}</span> },
    { key: "r", header: "Retention",
      render: (r) => {
        const tone = r.retention_pct < 20 ? "text-[var(--color-danger)]"
          : r.retention_pct < 50 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.retention_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Retention cohort</h1>
        <span className="text-xs text-[var(--color-muted)]">last 12 engineer signup weeks · active in last 30 days</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.cohort_week_start} emptyMessage="No cohorts." />
    </div>
  );
}
