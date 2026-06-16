import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payout volume 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { status: string; payout_count: number; total_rupees: number; avg_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function PayoutVolume30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payout_volume_30d");
  if (error) throw new Error(`founder_payout_volume_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const grandTotal = rows.reduce((s, r) => s + Number(r.total_rupees), 0);
  const paid = rows.find((r) => r.status === "paid");
  const failed = rows.find((r) => r.status === "failed");
  const cols: Column<Row>[] = [
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "paid" ? "text-[var(--color-ok)]"
          : r.status === "failed" ? "text-[var(--color-danger)]"
          : r.status === "queued" || r.status === "queued_payment" ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.payout_count)}</span> },
    { key: "t", header: "Total", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.total_rupees))}</span> },
    { key: "a", header: "Avg", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{inr(Number(r.avg_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payout volume (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">last-30d engineer payouts by status</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Grand total (30d)" value={inr(grandTotal)} />
          <StatCard label="Paid" value={inr(Number(paid?.total_rupees ?? 0))} subtext={`${formatNumber(paid?.payout_count ?? 0)} payouts`} tone="ok" />
          <StatCard label="Failed" value={inr(Number(failed?.total_rupees ?? 0))} subtext={`${formatNumber(failed?.payout_count ?? 0)} payouts`} tone={(failed?.payout_count ?? 0) > 0 ? "danger" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.status} emptyMessage="No payouts." />
    </div>
  );
}
