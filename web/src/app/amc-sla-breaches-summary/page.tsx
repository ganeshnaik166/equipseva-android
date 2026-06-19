import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "AMC SLA breaches summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  metric: string;
  value_text: string;
  value_num: number;
  bucket: string;
};

const bucketLabel: Record<string, string> = {
  volume: "Volume",
  breach_type: "Breach type",
  rate: "Rate",
  risk: "Risk",
  money: "Money",
  ratio: "Ratio",
  pulse: "Pulse",
};

const bucketTone: Record<string, string> = {
  volume: "text-[var(--color-muted)]",
  breach_type: "text-[var(--color-muted)]",
  rate: "text-[var(--color-muted)]",
  risk: "text-[var(--color-danger)]",
  money: "text-[var(--color-ok)]",
  ratio: "text-[var(--color-muted)]",
  pulse: "text-[var(--color-muted)]",
};

function valueTone(r: Row): string {
  const v = Number(r.value_num);
  if (r.bucket === "risk" && v > 0) return "text-[var(--color-danger)] font-semibold";
  if (r.metric.startsWith("Resolved share") && v > 0) {
    return v >= 80 ? "text-[var(--color-ok)] font-semibold"
         : v >= 50 ? "text-[var(--color-warn)] font-semibold"
                   : "text-[var(--color-danger)] font-semibold";
  }
  if (r.metric.startsWith("Credit issued") && v > 0) return "text-[var(--color-danger)] font-semibold";
  if (r.metric.startsWith("Avg breach overshoot") && v > 0) return "text-[var(--color-warn)] font-semibold";
  return "text-[var(--color-fg)] font-semibold";
}

export default async function AmcSlaBreachesSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_sla_breaches_summary");
  if (error) throw new Error(`founder_amc_sla_breaches_summary: ${error.message}`);
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
        <h1 className="text-xl font-semibold">AMC SLA breaches summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Breach ledger pulse — volume / breach_type / rate / risk / money / ratio / pulse (response_time, no_show, quality)`}
        </span>
      </header>
      <DataTable
        columns={cols}
        rows={rows}
        rowKey={(r) => r.metric}
        emptyMessage="No SLA breaches logged yet."
      />
      <p className="text-[11px] text-[var(--color-muted)]">
        {`Source: public.amc_sla_breaches (v21 SLA tracking). Each breach can issue an amc_payment_pool credit (1:1 via source_breach_id). Repeat-offender = contracts with >= 3 breaches in 90d (retention risk). Stale open = unresolved > 7d. Top-tier/top-engineer derived from amc_contracts.amc_tier and repair_jobs.engineer_id -> engineers.user_id joins. All windows in IST.`}
      </p>
    </div>
  );
}
