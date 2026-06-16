import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Dispute outcomes — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { outcome: string; cnt: number; share_pct: number; avg_money: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function DisputeOutcomesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dispute_outcomes");
  if (error) throw new Error(`founder_dispute_outcomes: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "o", header: "Outcome",
      render: (r) => {
        const tone = r.outcome === "accepted" ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.outcome}</span>;
      }
    },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "p", header: "Share", render: (r) => <span className="text-xs tabular-nums">{r.share_pct}%</span> },
    { key: "m", header: "Avg at stake", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.avg_money))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Dispute outcomes</h1>
        <span className="text-xs text-[var(--color-muted)]">all-time accepted vs rejected · avg money at stake</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.outcome} emptyMessage="No resolved disputes." />
    </div>
  );
}
