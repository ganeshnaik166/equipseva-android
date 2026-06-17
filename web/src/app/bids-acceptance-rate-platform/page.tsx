import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bids acceptance rate (platform) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; placed: number; accepted: number; rejected: number; acceptance_pct: number };

export default async function BidsAcceptanceRatePlatformPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bids_acceptance_rate_platform");
  if (error) throw new Error(`founder_bids_acceptance_rate_platform: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "p", header: "Placed", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.placed)}</span> },
    { key: "a", header: "Accepted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.accepted)}</span> },
    { key: "r", header: "Rejected", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected)}</span> },
    { key: "x", header: "Acceptance %",
      render: (r) => {
        const tone = r.acceptance_pct < 8 ? "text-[var(--color-danger)]"
          : r.acceptance_pct < 15 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.acceptance_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bids acceptance rate (platform)</h1>
        <span className="text-xs text-[var(--color-muted)]">% of all bids that hospitals accepted · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No bids." />
    </div>
  );
}
