import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC renewal failures aging — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { bucket: string; cnt: number; mrr_rupees: number; oldest_days: number };

export default async function AmcRenewalFailuresAgingPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_failures_aging");
  if (error) throw new Error(`founder_amc_renewal_failures_aging: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "b", header: "Age", render: (r) => <span className="text-xs font-semibold">{r.bucket}</span> },
    { key: "c", header: "Contracts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.cnt)}</span> },
    { key: "m", header: "Lost MRR (₹)", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.mrr_rupees)}</span> },
    { key: "o", header: "Oldest (days)",
      render: (r) => {
        const tone = r.oldest_days > 60 ? "text-[var(--color-danger)]"
          : r.oldest_days > 30 ? "text-[var(--color-warn)]" : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.oldest_days}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal failures aging</h1>
        <span className="text-xs text-[var(--color-muted)]">amc_contracts in 'renewal_failed' bucketed by days since end_date</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.bucket} emptyMessage="No renewal failures." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Contracts here have already cycled through the 3-retry budget. Founder outreach (or manual hospital-side card update) is the only recovery path.
      </section>
    </div>
  );
}
