import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Spare parts delivery rate by week — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  week_start: string;
  paid: number;
  delivered: number;
  delivery_pct: number;
};

export default async function SparePartsDeliveryRateByWeekPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spare_parts_delivery_rate_by_week");
  if (error) throw new Error(`founder_spare_parts_delivery_rate_by_week: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Week", render: (r) => <span className="text-xs tabular-nums">{r.week_start}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.paid)}</span> },
    { key: "d", header: "Delivered", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.delivered)}</span> },
    { key: "pct", header: "Delivery %", render: (r) => {
        const v = Number(r.delivery_pct);
        const tone = v >= 80 ? "text-[var(--color-ok)]" : v >= 50 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts delivery rate by week (13wk)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          13wk · delivered / paid %. Fulfillment health. Target ≥80%
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.week_start} emptyMessage="No paid orders in last 13 weeks." />
    </div>
  );
}
