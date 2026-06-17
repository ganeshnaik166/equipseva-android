import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow amount at risk — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; rupees_sum: number; oldest_days: number };

export default async function EscrowAmountAtRiskPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_amount_at_risk");
  if (error) throw new Error(`founder_escrow_amount_at_risk: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalAtRisk = rows.reduce((n, r) => n + (r.rupees_sum ?? 0), 0);
  const cols: Column<Row>[] = [
    { key: "b", header: "Age", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "r", header: "Sum (₹)",
      render: (r) => {
        const tone = r.bucket.includes("90") || r.bucket.includes("60") ? "text-[var(--color-danger)]"
          : r.bucket.includes("30") ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.rupees_sum)}</span>;
      }
    },
    { key: "o", header: "Oldest (days)", render: (r) => <span className="text-xs tabular-nums">{r.oldest_days}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow amount at risk</h1>
        <span className="text-xs text-[var(--color-muted)]">₹{formatNumber(totalAtRisk)} held across non-released escrow</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No held escrow." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Money in &gt;90d bucket = candidates for <a href="/escrow-stuck" className="underline">/escrow-stuck</a> drill-down and possible auto-release / refund per founder action.
      </section>
    </div>
  );
}
