import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Audit success rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  total_ops: number;
  success_cnt: number;
  failed_cnt: number;
  success_pct: number;
};

export default async function AuditSuccessRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_success_rate_by_week");
  if (error) throw new Error(`founder_audit_success_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_ops)}</span> },
    { key: "s", header: "Success", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.success_cnt)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed_cnt)}</span> },
    { key: "p", header: "Success %", render: (r) => {
        const v = Number(r.success_pct);
        const tone = v >= 95 ? "text-[var(--color-ok)]" : v >= 80 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit success rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk weekly success/fail trend · target &gt;=95% · pair with /audit-failed-events-30d (r1021) for drill
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No founder actions yet." />
    </div>
  );
}
