import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC near expiry — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { contract_id: string; hospital_user_id: string; display_name: string; end_date: string; days_left: number; monthly_fee: number; auto_renew: boolean; amc_tier: string };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcNearExpiryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_near_expiry");
  if (error) throw new Error(`founder_amc_near_expiry: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const manual = rows.filter((r) => !r.auto_renew);
  const totalMrr = rows.reduce((s, r) => s + Number(r.monthly_fee), 0);
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs capitalize">{r.amc_tier}</span> },
    { key: "e", header: "Expires", render: (r) => <span className="text-xs">{new Date(r.end_date).toLocaleDateString("en-IN")}</span> },
    { key: "d", header: "Days left",
      render: (r) => {
        const tone = r.days_left <= 7 ? "text-[var(--color-danger)]"
          : r.days_left <= 14 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.days_left)}</span>;
      }
    },
    { key: "f", header: "Monthly fee", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_fee))}</span> },
    { key: "a", header: "Auto-renew",
      render: (r) => <span className={`text-xs ${r.auto_renew ? "text-[var(--color-ok)]" : "text-[var(--color-warn)]"}`}>{r.auto_renew ? "Yes" : "Manual"}</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC near expiry</h1>
        <span className="text-xs text-[var(--color-muted)]">active AMCs expiring within 30 days</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Expiring 30d" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Manual (need outreach)" value={formatNumber(manual.length)} tone={manual.length > 0 ? "danger" : "ok"} />
          <StatCard label="Total MRR at risk" value={inr(totalMrr)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.contract_id} emptyMessage="No AMCs expiring soon." />
    </div>
  );
}
