import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC pool low balance — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  contract_id: string;
  hospital_user_id: string;
  display_name: string;
  amc_tier: string;
  monthly_fee: number;
  pool_balance: number;
  buffer_months: number;
  end_date: string;
};

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcPoolLowBalancePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_pool_low_balance");
  if (error) throw new Error(`founder_amc_pool_low_balance: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrrAtRisk = rows.reduce((s, r) => s + Number(r.monthly_fee), 0);
  const critical = rows.filter((r) => Number(r.buffer_months) < 0.5).length;
  const negative = rows.filter((r) => Number(r.pool_balance) < 0).length;
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs capitalize">{r.amc_tier}</span> },
    { key: "f", header: "Monthly fee", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_fee))}</span> },
    { key: "b", header: "Pool balance",
      render: (r) => {
        const v = Number(r.pool_balance);
        const tone = v < 0 ? "text-[var(--color-danger)]"
          : v === 0 ? "text-[var(--color-warn)]"
          : "text-[var(--color-fg)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{inr(v)}</span>;
      }
    },
    { key: "m", header: "Buffer",
      render: (r) => {
        const m = Number(r.buffer_months);
        const tone = m < 0 ? "text-[var(--color-danger)]"
          : m < 0.5 ? "text-[var(--color-danger)]"
          : m < 1 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{m.toFixed(2)} mo</span>;
      }
    },
    { key: "e", header: "Ends", render: (r) => <span className="text-xs text-[var(--color-muted)]">{new Date(r.end_date).toLocaleDateString("en-IN")}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC pool low balance</h1>
        <span className="text-xs text-[var(--color-muted)]">active AMCs with pool &lt; 2× monthly fee · outreach queue</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="At-risk count" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Buffer < 2 weeks" value={formatNumber(critical)} tone={critical > 0 ? "danger" : "ok"} />
          <StatCard label="Already negative" value={formatNumber(negative)} tone={negative > 0 ? "danger" : "ok"} />
          <StatCard label="MRR at risk" value={inr(totalMrrAtRisk)} tone={totalMrrAtRisk > 0 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.contract_id} emptyMessage="All AMCs have healthy pool buffers." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this surface.</strong> When an AMC payment pool runs negative, the
        contract auto-suspends (per r501 cash_auto_suspend). This list catches contracts
        BEFORE they hit zero — sorted by lowest balance first. Buffer = balance ÷ monthly
        fee. Negative = already overdrawn. &lt;0.5mo = critical outreach. Companion view
        to <a href="/amc-pool-health" className="underline">/amc-pool-health</a> (buckets dist).
      </section>
    </div>
  );
}
