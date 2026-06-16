import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC paused — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { contract_id: string; hospital_user_id: string; display_name: string; amc_tier: string; monthly_fee: number; paused_age_days: number; end_date: string };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function AmcPausedPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_paused_list");
  if (error) throw new Error(`founder_amc_paused_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMrrLost = rows.reduce((s, r) => s + Number(r.monthly_fee), 0);
  const cols: Column<Row>[] = [
    { key: "n", header: "Hospital", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "t", header: "Tier", render: (r) => <span className="text-xs capitalize">{r.amc_tier}</span> },
    { key: "f", header: "MRR", render: (r) => <span className="text-xs tabular-nums">{inr(Number(r.monthly_fee))}</span> },
    { key: "a", header: "Paused",
      render: (r) => {
        const tone = r.paused_age_days > 30 ? "text-[var(--color-danger)]"
          : r.paused_age_days > 7 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.paused_age_days)}d</span>;
      }
    },
    { key: "e", header: "Ends", render: (r) => <span className="text-xs">{new Date(r.end_date).toLocaleDateString("en-IN")}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC paused</h1>
        <span className="text-xs text-[var(--color-muted)]">contracts with status=&apos;paused&apos; · likely pool-balance shortfall</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Paused count" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="MRR frozen" value={inr(totalMrrLost)} tone={totalMrrLost > 0 ? "warn" : "ok"} />
          <StatCard label="Aged >30d" value={formatNumber(rows.filter((r) => r.paused_age_days > 30).length)} tone="danger" />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.contract_id} emptyMessage="No paused AMCs." />
    </div>
  );
}
