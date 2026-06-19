import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Supervision outcome rate by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  total_requested: number;
  successful: number;
  failed: number;
  success_pct: number;
};

export default async function SupervisionOutcomeRateByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_supervision_outcome_rate_by_month");
  if (error) throw new Error(`founder_supervision_outcome_rate_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Requested", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_requested)}</span> },
    { key: "s", header: "Successful", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.successful)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "pct", header: "Success %", render: (r) => {
        const v = Number(r.success_pct);
        const tone = v >= 70 ? "text-[var(--color-ok)]" : v >= 40 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Supervision outcome rate by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          12mo · successful/requested % per month · training program effectiveness
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No supervised assignments in last 12 months." />
    </div>
  );
}
