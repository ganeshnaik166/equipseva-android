import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audit pass rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; responses: number; high_4plus: number; low_2less: number; pass_pct: number; avg_rating: number };

export default async function SpotAuditPassRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audit_pass_rate");
  if (error) throw new Error(`founder_spot_audit_pass_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "r", header: "Responses", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.responses)}</span> },
    { key: "h", header: "4★+", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.high_4plus)}</span> },
    { key: "l", header: "≤2★", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.low_2less)}</span> },
    { key: "p", header: "Pass %",
      render: (r) => {
        const tone = r.pass_pct < 70 ? "text-[var(--color-danger)]"
          : r.pass_pct < 85 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.pass_pct}%</span>;
      }
    },
    { key: "a", header: "Avg ★",
      render: (r) => <span className="text-xs tabular-nums font-semibold">{r.avg_rating}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audit pass rate</h1>
        <span className="text-xs text-[var(--color-muted)]">% hospital spot audit responses rated ≥4★ · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No spot audit responses." />
    </div>
  );
}
