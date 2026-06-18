import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "AMC renewal attempts by month — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  month_ist: string;
  total_attempts: number;
  succeeded: number;
  failed: number;
  abandoned: number;
  pending: number;
  success_pct: number;
};

export default async function AmcRenewalAttemptsByMonthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_renewal_attempts_by_month");
  if (error) throw new Error(`founder_amc_renewal_attempts_by_month: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "m", header: "Month", render: (r) => <span className="text-xs tabular-nums">{r.month_ist}</span> },
    { key: "t", header: "Attempts", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_attempts)}</span> },
    { key: "s", header: "Succeeded", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.succeeded)}</span> },
    { key: "f", header: "Failed", render: (r) => <span className="text-xs tabular-nums text-[var(--color-danger)]">{formatNumber(r.failed)}</span> },
    { key: "a", header: "Abandoned", render: (r) => <span className="text-xs tabular-nums text-[var(--color-warn)]">{formatNumber(r.abandoned)}</span> },
    { key: "p", header: "Pending", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.pending)}</span> },
    { key: "pct", header: "Success %", render: (r) => {
        const v = Number(r.success_pct);
        const tone = v >= 70 ? "text-[var(--color-ok)]" : v >= 40 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatPct(v / 100)}</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC renewal attempts by month (12mo)</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Per month: total attempts + succeeded/failed/abandoned/pending + success % · Razorpay outcome quality signal
        </span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.month_ist} emptyMessage="No renewal attempts in last 12 months." />
    </div>
  );
}
