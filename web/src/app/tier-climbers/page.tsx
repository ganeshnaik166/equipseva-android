import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Tier climbers — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { engineer_user_id: string; display_name: string; current_tier: string; jobs_completed: number; dispute_rate_pct: number; last_computed_at: string };

export default async function TierClimbersPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_tier_climbers");
  if (error) throw new Error(`founder_tier_climbers: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "t", header: "Current tier",
      render: (r) => {
        const tone = r.current_tier === "silver" ? "text-[var(--color-warn)]"
          : r.current_tier === "bronze" ? "" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold capitalize ${tone}`}>{r.current_tier}</span>;
      }
    },
    { key: "j", header: "Jobs done", render: (r) => <span className="text-xs tabular-nums font-semibold">{formatNumber(r.jobs_completed)}</span> },
    { key: "d", header: "Dispute %",
      render: (r) => {
        const d = Number(r.dispute_rate_pct ?? 0);
        const tone = d > 10 ? "text-[var(--color-danger)]" : d > 5 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{d.toFixed(1)}%</span>;
      }
    },
    { key: "l", header: "Last computed", render: (r) => <span className="text-xs text-[var(--color-muted)]">{new Date(r.last_computed_at).toLocaleDateString("en-IN")}</span> },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Tier climbers</h1>
        <span className="text-xs text-[var(--color-muted)]">non-gold engineers ranked by jobs completed · top 50</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="No engineers." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Engineers with high job counts but not yet gold = candidates for next promotion cycle. Watch the dispute rate gate — high dispute % can block tier-up.
      </section>
    </div>
  );
}
