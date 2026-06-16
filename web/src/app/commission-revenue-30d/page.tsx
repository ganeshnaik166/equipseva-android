import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Commission revenue (30d) — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { day_ist: string; completed_jobs: number; gross_rupees: number; commission_est_rupees: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function CommissionRevenue30dPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_commission_revenue_30d");
  if (error) throw new Error(`founder_commission_revenue_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total30d = rows.reduce((s, r) => s + Number(r.commission_est_rupees), 0);
  const totalGross = rows.reduce((s, r) => s + Number(r.gross_rupees), 0);
  const cols: Column<Row>[] = [
    { key: "d", header: "Date (IST)", render: (r) => <span className="text-xs">{new Date(r.day_ist).toLocaleDateString("en-IN", { weekday: "short", day: "numeric", month: "short" })}</span> },
    { key: "j", header: "Jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.completed_jobs)}</span> },
    { key: "g", header: "Gross", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.gross_rupees))}</span> },
    { key: "c", header: "Commission (est)", render: (r) => <span className="text-xs tabular-nums font-semibold text-[var(--color-ok)]">{inr(Number(r.commission_est_rupees))}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Commission revenue (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">platform take · 15% of completed-job gross · IST</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="30d gross GMV" value={inr(totalGross)} />
          <StatCard label="30d commission (est)" value={inr(total30d)} tone="ok" />
          <StatCard label="Daily avg commission" value={inr(total30d / 30)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.day_ist} emptyMessage="No completed jobs." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Estimate uses 7% take (per r305 repair-job split, confirmed live: ₹20 job → ₹18.60 engineer payout). AMC-funded visits split at 15% so blended take is slightly higher. Actual commission is residual (gross − engineer_payout). Use as rough indicator only.
      </section>
    </div>
  );
}
