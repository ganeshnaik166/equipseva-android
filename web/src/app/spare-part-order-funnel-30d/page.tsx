import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRupees, formatPct } from "@/lib/format";

export const metadata = { title: "Spare part order funnel 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  stage: string;
  stage_order: number;
  cnt: number;
  total_inr: number;
  pct_of_orders: number;
};

export default async function SparePartOrderFunnel30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_part_order_funnel_30d");
  if (error) throw new Error(`founder_spare_part_order_funnel_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "s", header: "Stage", render: (r) => (
      <span className={`text-xs ${r.stage_order === 4 ? "text-[var(--color-ok)]" : r.stage_order >= 5 ? "text-[var(--color-danger)]" : ""}`}>{r.stage}</span>
    ) },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "t", header: "Total INR", render: (r) => <span className="text-xs tabular-nums">{formatRupees(Number(r.total_inr))}</span> },
    { key: "p", header: "% of created", render: (r) => <span className="text-xs tabular-nums">{formatPct(Number(r.pct_of_orders) / 100)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare part order funnel (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Created → paid → shipped → delivered (happy path) + cancelled/refunded tails
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => String(r.stage_order)} emptyMessage="No spare part orders in last 30d." />
    </div>
  );
}
