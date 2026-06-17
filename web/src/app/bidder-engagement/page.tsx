import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bidder engagement — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; verified_total: number; active_bidders: number; engagement_pct: number };

export default async function BidderEngagementPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bidder_engagement");
  if (error) throw new Error(`founder_bidder_engagement: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "t", header: "Verified", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.verified_total)}</span> },
    { key: "a", header: "Active bidders", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_bidders)}</span> },
    { key: "p", header: "Engagement %",
      render: (r) => {
        const tone = r.engagement_pct < 30 ? "text-[var(--color-danger)]"
          : r.engagement_pct < 55 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.engagement_pct}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bidder engagement</h1>
        <span className="text-xs text-[var(--color-muted)]">% of verified engineers placing ≥1 bid · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No bid activity." />
    </div>
  );
}
