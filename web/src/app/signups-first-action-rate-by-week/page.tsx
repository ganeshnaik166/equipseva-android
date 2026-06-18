import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Signups first-action rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  engineer_signups: number;
  engineers_with_bid_in_7d: number;
  hospital_signups: number;
  hospitals_with_job_in_7d: number;
};

function pctCell(num: number, denom: number) {
  if (denom === 0) return <span className="text-xs tabular-nums text-[var(--color-muted)]">—</span>;
  const v = (100 * num) / denom;
  const tone = v >= 50 ? "text-[var(--color-ok)]" : v >= 25 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
  return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
}

export default async function SignupsFirstActionRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_signups_first_action_rate_by_week");
  if (error) throw new Error(`founder_signups_first_action_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "e", header: "Eng signups", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.engineer_signups)}</span> },
    { key: "eb", header: "→ bid 7d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.engineers_with_bid_in_7d)}</span> },
    { key: "ep", header: "Eng %", render: (r) => pctCell(r.engineers_with_bid_in_7d, r.engineer_signups) },
    { key: "h", header: "Hosp signups", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospital_signups)}</span> },
    { key: "hj", header: "→ job 7d", render: (r) => <span className="text-xs tabular-nums text-[var(--color-info)]">{formatNumber(r.hospitals_with_job_in_7d)}</span> },
    { key: "hp", header: "Hosp %", render: (r) => pctCell(r.hospitals_with_job_in_7d, r.hospital_signups) },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Signups first-action rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          % of new signups taking first marketplace action within 7d (engineer bid · hospital job)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No signups in last 13 weeks." />
    </div>
  );
}
