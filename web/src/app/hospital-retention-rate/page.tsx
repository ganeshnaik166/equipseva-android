import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital retention rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; hospitals: number; repeaters: number; retention_pct: number };

export default async function HospitalRetentionRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospital_retention_rate");
  if (error) throw new Error(`founder_hospital_retention_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "h", header: "Hospitals", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.hospitals)}</span> },
    { key: "r", header: "Repeaters (≥2 jobs)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.repeaters)}</span> },
    { key: "p", header: "Retention %",
      render: (r) => {
        const tone = r.retention_pct < 25 ? "text-[var(--color-danger)]"
          : r.retention_pct < 45 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.retention_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital retention rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% of active hospitals posting ≥2 jobs · 30/90/180d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No active hospitals." />
    </div>
  );
}
