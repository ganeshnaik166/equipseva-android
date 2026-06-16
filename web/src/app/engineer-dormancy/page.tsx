import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer dormancy — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_user_id: string;
  display_name: string;
  total_jobs: number;
  last_completed_at: string;
  days_dormant: number;
};

export default async function EngineerDormancyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_dormancy");
  if (error) throw new Error(`founder_engineer_dormancy: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "t", header: "Total jobs", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_jobs)}</span> },
    { key: "l", header: "Last job", render: (r) => <span className="text-xs text-[var(--color-muted)]">{new Date(r.last_completed_at).toLocaleDateString("en-IN")}</span> },
    { key: "d", header: "Dormant",
      render: (r) => {
        const tone = r.days_dormant > 180 ? "text-[var(--color-danger)]"
          : r.days_dormant > 90 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.days_dormant)}d</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer dormancy</h1>
        <span className="text-xs text-[var(--color-muted)]">past completers idle &gt; 30d · top 100 by recency</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Dormant count" value={formatNumber(rows.length)} tone={rows.length > 50 ? "warn" : "ok"} />
          <StatCard label="Lapsed >180d" value={formatNumber(rows.filter((r) => r.days_dormant > 180).length)} tone="danger" />
          <StatCard label="At-risk 91-180d" value={formatNumber(rows.filter((r) => r.days_dormant > 90 && r.days_dormant <= 180).length)} tone="warn" />
          <StatCard label="Cooling 31-90d" value={formatNumber(rows.filter((r) => r.days_dormant <= 90).length)} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No dormant engineers." />
    </div>
  );
}
