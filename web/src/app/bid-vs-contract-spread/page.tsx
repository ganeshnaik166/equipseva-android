import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Bid vs contract spread — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { window_label: string; jobs_count: number; avg_bid: number; avg_contracted: number; avg_spread_pct: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function BidVsContractSpreadPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_bid_vs_contract_spread");
  if (error) throw new Error(`founder_bid_vs_contract_spread: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "w", header: "Window", render: (r) => <span className="text-xs font-semibold">{r.window_label}</span> },
    { key: "j", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_count)}</span> },
    { key: "b", header: "Avg bid", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.avg_bid))}</span> },
    { key: "c", header: "Avg final", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.avg_contracted))}</span> },
    { key: "s", header: "Spread",
      render: (r) => {
        const v = Number(r.avg_spread_pct);
        const tone = v > 20 ? "text-[var(--color-danger)]" : v > 10 ? "text-[var(--color-warn)]" : "";
        const sign = v > 0 ? "+" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{sign}{v}%</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Bid vs contract spread</h1>
        <span className="text-xs text-[var(--color-muted)]">how much winning bids stretch in negotiation · 7/30/90d</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.window_label} emptyMessage="No paired data." />
    </div>
  );
}
