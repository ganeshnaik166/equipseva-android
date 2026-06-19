import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "AMC subscription charges summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  value_text: string;
  value_num: number;
  bucket: string;
};

const bucketLabel: Record<string, string> = {
  volume: "Volume",
  outcome: "Outcome",
  rate: "Rate",
  risk: "Risk",
  money: "Money",
  ratio: "Ratio",
  pulse: "Pulse",
};

const bucketTone: Record<string, string> = {
  volume: "text-[var(--color-muted)]",
  outcome: "text-[var(--color-muted)]",
  rate: "text-[var(--color-muted)]",
  risk: "text-[var(--color-danger)]",
  money: "text-[var(--color-ok)]",
  ratio: "text-[var(--color-muted)]",
  pulse: "text-[var(--color-muted)]",
};

function valueTone(r: Row): string {
  const v = Number(r.value_num);
  if (r.bucket === "risk" && v > 0) return "text-[var(--color-danger)] font-semibold";
  if (r.metric.startsWith("Success rate") && v > 0) {
    return v >= 80 ? "text-[var(--color-ok)] font-semibold"
         : v >= 50 ? "text-[var(--color-warn)] font-semibold"
                   : "text-[var(--color-danger)] font-semibold";
  }
  if (r.metric.startsWith("Failure rate") && v > 0) {
    return v <= 15 ? "text-[var(--color-ok)] font-semibold"
         : v <= 40 ? "text-[var(--color-warn)] font-semibold"
                   : "text-[var(--color-danger)] font-semibold";
  }
  if (r.metric.startsWith("Refund rate") && v > 0) {
    return v <= 2 ? "text-[var(--color-ok)] font-semibold"
         : v <= 8 ? "text-[var(--color-warn)] font-semibold"
                  : "text-[var(--color-danger)] font-semibold";
  }
  if (r.metric.startsWith("Revenue captured")) return "text-[var(--color-ok)] font-semibold";
  if (r.metric.startsWith("Revenue at-risk") && v > 0) return "text-[var(--color-danger)] font-semibold";
  if (r.metric.startsWith("Revenue refunded") && v > 0) return "text-[var(--color-warn)] font-semibold";
  return "text-[var(--color-fg)] font-semibold";
}

export default async function AmcSubscriptionChargesSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_subscription_charges_summary");
  if (error) throw new Error(`founder_amc_subscription_charges_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];

  const cols: Column<Row>[] = [
    {
      key: "b",
      header: "Bucket",
      render: (r) => (
        <span className={`text-[10px] uppercase tracking-wide ${bucketTone[r.bucket] ?? "text-[var(--color-muted)]"}`}>
          {bucketLabel[r.bucket] ?? r.bucket}
        </span>
      ),
    },
    {
      key: "m",
      header: "Metric",
      render: (r) => <span className="text-xs">{r.metric}</span>,
    },
    {
      key: "v",
      header: "Value",
      render: (r) => (
        <span className={`text-xs tabular-nums ${valueTone(r)}`}>{r.value_text}</span>
      ),
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC subscription charges summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Razorpay auto-debit ledger pulse — volume / outcome / rate / risk / money / ratio / pulse`}
        </span>
      </header>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.metric}
        emptyMessage="No subscription-charge activity yet."
      />
      <p className="text-[11px] text-[var(--color-muted)]">
        {`Source: public.amc_subscription_charges (r417 schema). Per-cycle auto-debit attempts on amc_subscriptions; succeeded rows link a pool_ledger_id into amc_payment_pool. Stuck attempted = status 'attempted' > 24h (worker should have settled). Repeat-fail = subscriptions with >= 2 failed charges. Pool-orphan = succeeded charge with no pool_ledger_id (credit not posted). All windows in IST.`}
      </p>
    </div>
  );
}
