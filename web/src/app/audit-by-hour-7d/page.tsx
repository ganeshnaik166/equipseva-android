import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Audit by hour 7d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hour_ist: number;
  cnt: number;
  pct_of_total: number;
};

export default async function AuditByHour7dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_audit_by_hour_7d");
  if (error) throw new Error(`founder_audit_by_hour_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((a, r) => a + (r.cnt ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour IST", render: (r) => <span className="text-xs tabular-nums font-medium">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "% of total", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_total) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Audit by hour (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total 7d ops: <span className="font-mono tabular-nums">{formatNumber(total)}</span> · time-of-day pattern (IST hours)
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No founder actions in last 7 days." />
    </div>
  );
}
