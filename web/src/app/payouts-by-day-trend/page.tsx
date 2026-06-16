import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Payouts by day — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; paid_count: number; paid_rupees: number; failed_count: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function PayoutsByDayTrendPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_payouts_by_day_trend");
  if (error) throw new Error(`founder_payouts_by_day_trend: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalRupees = rows.reduce((s, r) => s + Number(r.paid_rupees), 0);
  const totalFailed = rows.reduce((s, r) => s + r.failed_count, 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "p", header: "Paid", render: (r) => <span className="text-xs tabular-nums text-[var(--color-ok)]">{formatNumber(r.paid_count)}</span> },
    { key: "r", header: "Rupees", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.paid_rupees))}</span> },
    { key: "f", header: "Failed",
      render: (r) => <span className={`text-xs tabular-nums ${r.failed_count > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatNumber(r.failed_count)}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts by day</h1>
        <span className="text-xs text-[var(--color-muted)]">last 14 days · IST · grouped by queued_at</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="14d rupees" value={inr(totalRupees)} />
          <StatCard label="14d failed" value={formatNumber(totalFailed)} tone={totalFailed > 0 ? "danger" : "ok"} />
          <StatCard label="Daily avg rupees" value={inr(totalRupees / 14)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No payouts." />
    </div>
  );
}
