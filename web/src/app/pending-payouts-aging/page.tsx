import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Pending payouts aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; rupees_sum: number; oldest_hours: number };

export default async function PendingPayoutsAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_pending_payouts_aging");
  if (error) throw new Error(`founder_pending_payouts_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Age bucket", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Count", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "r", header: "Sum (₹)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.rupees_sum)}</span> },
    { key: "o", header: "Oldest (h)",
      render: (r) => {
        const tone = r.oldest_hours > 72 ? "text-[var(--color-danger)]"
          : r.oldest_hours > 24 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.oldest_hours.toFixed(1)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Pending payouts aging</h1>
        <span className="text-xs text-[var(--color-muted)]">engineer_payouts.status='pending' age distribution</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No pending payouts." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Pending &gt;24h = worker stalled or RazorpayX queue backed up. Check <a href="/payout-fail-reasons" className="underline">/payout-fail-reasons</a> + cron.
      </section>
    </div>
  );
}
