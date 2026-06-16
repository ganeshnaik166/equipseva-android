import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC cancellations 30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { contract_id: string; hospital_user_id: string; display_name: string; amc_tier: string; monthly_fee: number; status: string; updated_at: string };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcCancellationsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_cancellations_30d");
  if (error) throw new Error(`founder_amc_cancellations_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const mrrLost = rows.reduce((s, r) => s + Number(r.monthly_fee), 0);
  const cancelled = rows.filter((r) => r.status === "cancelled").length;
  const renewalFailed = rows.filter((r) => r.status === "renewal_failed").length;
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs capitalize">{r.amc_tier}</span> },
    { key: "f", header: "MRR lost", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_fee))}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "cancelled" ? "text-[var(--color-danger)]"
          : r.status === "renewal_failed" ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "u", header: "When", render: (r) => <span className="text-xs">{new Date(r.updated_at).toLocaleDateString("en-IN")}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC cancellations (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">cancelled / renewal_failed / expired in last 30 days</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="30d MRR lost" value={inr(mrrLost)} tone={mrrLost > 0 ? "danger" : "ok"} />
          <StatCard label="Cancelled" value={formatNumber(cancelled)} tone={cancelled > 0 ? "danger" : "ok"} />
          <StatCard label="Renewal failed" value={formatNumber(renewalFailed)} tone={renewalFailed > 0 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.contract_id} emptyMessage="No cancellations." />
    </div>
  );
}
