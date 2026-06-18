import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "AMC renewal rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  due_cnt: number;
  renewed_cnt: number;
  expired_cnt: number;
  renewal_pct: number;
};

export default async function AmcRenewalRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_rate_by_week");
  if (error) throw new Error(`founder_amc_renewal_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "d", header: "Due", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.due_cnt)}</span> },
    { key: "r", header: "Renewed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.renewed_cnt)}</span> },
    { key: "e", header: "Expired", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.expired_cnt)}</span> },
    { key: "pct", header: "Renewal %", render: (r) => {
        const v = Number(r.renewal_pct);
        const tone = v >= 70 ? "text-[var(--color-ok)]" : v >= 40 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Weekly companion to r1054 monthly. Renewed (active) / due (end_date in week) × 100
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No AMC renewals due in last 13 weeks." />
    </div>
  );
}
