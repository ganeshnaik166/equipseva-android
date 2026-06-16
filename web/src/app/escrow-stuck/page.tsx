import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Escrow stuck >30d — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { escrow_id: string; repair_job_id: string; status: string; amount_rupees: number; age_days: number; hospital_user_id: string | null; engineer_user_id: string | null };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function EscrowStuckPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_escrow_stuck_30d");
  if (error) throw new Error(`founder_escrow_stuck_30d: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const total = rows.reduce((s, r) => s + Number(r.amount_rupees), 0);
  const cols: Column<Row>[] = [
    { key: "j", header: "Job", render: (r) => <span className="text-xs font-mono">{r.repair_job_id.slice(0, 8)}</span> },
    { key: "s", header: "Status",
      render: (r) => {
        const tone = r.status === "in_dispute" ? "text-[var(--color-danger)]"
          : r.status === "held" ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs font-semibold ${tone}`}>{r.status}</span>;
      }
    },
    { key: "a", header: "Amount", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.amount_rupees))}</span> },
    { key: "d", header: "Age",
      render: (r) => {
        const tone = r.age_days > 90 ? "text-[var(--color-danger)]"
          : r.age_days > 60 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>{formatNumber(r.age_days)}d</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Escrow stuck &gt; 30d</h1>
        <span className="text-xs text-[var(--color-muted)]">cash held in escrow past 30 days · top 100 by age</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Stuck rows" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Total stuck" value={inr(total)} tone={total > 0 ? "warn" : "ok"} />
          <StatCard label="Oldest" value={`${formatNumber(Math.max(0, ...rows.map((r) => r.age_days)))}d`} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.escrow_id} emptyMessage="No stuck escrow." />
    </div>
  );
}
