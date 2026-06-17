import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier progression rate — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; active_engineers: number; promoted: number; demoted: number; net_promoted: number; promotion_pct: number };

export default async function TierProgressionRatePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_progression_rate");
  if (error) throw new Error(`founder_tier_progression_rate: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "e", header: "Engineers", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.active_engineers)}</span> },
    { key: "p", header: "Promoted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.promoted)}</span> },
    { key: "d", header: "Demoted", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.demoted)}</span> },
    { key: "n", header: "Net", render: (r) => <span className={`text-xs tabular-nums font-semibold ${r.net_promoted >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>{formatNumber(r.net_promoted)}</span> },
    { key: "x", header: "Promotion %", render: (r) => <span className="text-xs tabular-nums font-semibold">{r.promotion_pct}%</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier progression rate</h1>
        <span className="text-xs text-[var(--color-muted)]">Engineer cert tier promotions vs demotions · 30/90/365d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No tier events." />
    </div>
  );
}
