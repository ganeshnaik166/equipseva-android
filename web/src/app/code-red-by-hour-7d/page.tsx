import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Code Red by hour 7d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  hour_ist: number;
  total: number;
  resolved: number;
  timed_out: number;
};

export default async function CodeRedByHour7dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_by_hour_7d");
  if (error) throw new Error(`founder_code_red_by_hour_7d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "h", header: "Hour IST", render: (r) => <span className="text-xs tabular-nums font-medium">{String(r.hour_ist).padStart(2, "0")}:00</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total)}</span> },
    { key: "r", header: "Resolved", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.resolved)}</span> },
    { key: "to", header: "Timed out", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.timed_out)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red by hour (7d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          24-hour IST distribution · Code Red temporal pattern · informs staffing
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.hour_ist)} emptyMessage="No Code Red requests in last 7 days." />
    </div>
  );
}
