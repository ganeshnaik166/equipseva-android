import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Payouts success rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  queued: number;
  processed: number;
  failed: number;
  success_pct: number;
};

export default async function PayoutsSuccessRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_success_rate_by_week");
  if (error) throw new Error(`founder_payouts_success_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "q", header: "Queued", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.queued)}</span> },
    { key: "p", header: "Processed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.processed)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "pct", header: "Success %", render: (r) => {
        const v = Number(r.success_pct);
        const tone = v >= 95 ? "text-[var(--color-ok)]" : v >= 80 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts success rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk · processed / queued. Target &gt;=95% · pair with /failed-payouts-by-reason (r1033) for diagnostics
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No payouts in last 13 weeks." />
    </div>
  );
}
