import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audits summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; invitations: number; responses: number; response_pct: number; avg_rating: number };

export default async function SpotAuditsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audits_summary");
  if (error) throw new Error(`founder_spot_audits_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "i", header: "Invitations", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.invitations)}</span> },
    { key: "r", header: "Responses", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.responses)}</span> },
    { key: "p", header: "Response %",
      render: (r) => {
        const tone = r.response_pct < 30 ? "text-[var(--color-danger)]"
          : r.response_pct < 60 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.response_pct}%</span>;
      }
    },
    { key: "a", header: "Avg rating",
      render: (r) => {
        const a = Number(r.avg_rating);
        const tone = a < 3 ? "text-[var(--color-danger)]" : a < 4 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{a.toFixed(2)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spot audits summary</h1>
        <span className="text-xs text-[var(--color-muted)]">invitations · responses · avg rating across 7d/30d/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No spot audits." />
    </div>
  );
}
