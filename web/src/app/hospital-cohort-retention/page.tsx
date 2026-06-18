import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Hospital cohort retention — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  signup_month: string;
  cohort_size: number;
  active_30d_pct: number;
  active_60d_pct: number;
  active_90d_pct: number;
  active_180d_pct: number;
};

function pctCell(v: number) {
  const tone = v >= 50 ? "text-[var(--color-ok)]" : v >= 25 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
  return <span className={`text-xs tabular-nums ${tone}`}>{formatPct(v / 100)}</span>;
}

export default async function HospitalCohortRetentionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_cohort_retention");
  if (error) throw new Error(`founder_hospital_cohort_retention: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Signup month", render: (r) => <span className="text-xs tabular-nums">{r.signup_month}</span> },
    { key: "s", header: "Cohort size", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cohort_size)}</span> },
    { key: "a30", header: "Posted 30d", render: (r) => pctCell(Number(r.active_30d_pct)) },
    { key: "a60", header: "Posted 60d", render: (r) => pctCell(Number(r.active_60d_pct)) },
    { key: "a90", header: "Posted 90d", render: (r) => pctCell(Number(r.active_90d_pct)) },
    { key: "a180", header: "Posted 180d", render: (r) => pctCell(Number(r.active_180d_pct)) },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital cohort retention</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo signup cohorts × % active (at least 1 posted job) at 30/60/90/180d windows from signup
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.signup_month} emptyMessage="No hospital signups in last 12 months." />
    </div>
  );
}
