import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Code Red resolution funnel 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  stage: string;
  stage_order: number;
  cnt: number;
  pct_of_total: number;
};

export default async function CodeRedResolutionFunnel30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_code_red_resolution_funnel_30d");
  if (error) throw new Error(`founder_code_red_resolution_funnel_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => (
      <span className={`text-xs ${r.stage_order === 3 ? "text-[var(--color-ok)] font-medium" : r.stage_order === 4 ? "text-[var(--color-danger)] font-medium" : ""}`}>{r.stage}</span>
    ) },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "% of created", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_total) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red resolution funnel (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Created → accepted → resolved (happy path) + timed_out/cancelled/still-open tails
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.stage_order)} emptyMessage="No Code Red requests in last 30d." />
    </div>
  );
}
