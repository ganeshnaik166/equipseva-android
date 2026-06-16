import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber, shortId } from "@/lib/format";

export const metadata = { title: "Chains health — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  chain_id: string;
  chain_name: string;
  member_count: number;
  amc_active_count: number;
  amc_pct: number;
  jobs_completed_30d: number;
};

export default async function ChainsHealthPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chains_health");
  if (error) throw new Error(`founder_chains_health: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalMembers = rows.reduce((s, r) => s + (r.member_count ?? 0), 0);
  const totalAmc = rows.reduce((s, r) => s + (r.amc_active_count ?? 0), 0);
  const totalJobs = rows.reduce((s, r) => s + (r.jobs_completed_30d ?? 0), 0);
  const lowAmc = rows.filter((r) => r.member_count > 0 && r.amc_pct < 30).length;
  const cols: Column<Row>[] = [
    {
      key: "name", header: "Chain",
      render: (r) => (
        <Link href={`/chains/${r.chain_id}`} className="text-[var(--color-accent)] hover:underline">
          {r.chain_name || shortId(r.chain_id)}
        </Link>
      ),
    },
    { key: "m", header: "Members", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.member_count)}</span> },
    { key: "a", header: "AMC active", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.amc_active_count)}</span> },
    {
      key: "p", header: "AMC %",
      render: (r) => {
        const tone = r.amc_pct >= 60 ? "text-[var(--color-ok)]"
          : r.amc_pct >= 30 ? "text-[var(--color-warn)]" : "text-[var(--color-danger)]";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{r.amc_pct}%</span>;
      }
    },
    { key: "j", header: "Jobs 30d", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed_30d)}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chains health</h1>
        <span className="text-xs text-[var(--color-muted)]">per-chain AMC penetration + 30d job volume</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Chains" value={formatNumber(rows.length)} />
          <StatCard label="Total member hospitals" value={formatNumber(totalMembers)} />
          <StatCard label="Active AMCs" value={formatNumber(totalAmc)} subtext={totalMembers > 0 ? `${Math.round((totalAmc / totalMembers) * 100)}% penetration` : undefined} />
          <StatCard label="Low-AMC chains" value={formatNumber(lowAmc)} subtext="<30% penetration" tone={lowAmc > 0 ? "warn" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.chain_id} emptyMessage="No registered chains." />
      <p className="text-xs text-[var(--color-muted)]">30d jobs = completed jobs across all member hospitals.</p>
    </div>
  );
}
