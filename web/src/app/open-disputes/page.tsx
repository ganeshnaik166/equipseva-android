import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Open disputes — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { pack_id: string; filed_by_user_id: string; filer_role: string; repair_job_escrow_id: string; evidence_count: number; amount_at_stake: number; submitted_at: string; days_open: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function OpenDisputesPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_open_disputes_list");
  if (error) throw new Error(`founder_open_disputes_list: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalStake = rows.reduce((s, r) => s + Number(r.amount_at_stake), 0);
  const cols: Column<Row>[] = [
    { key: "p", header: "Pack #", render: (r) => <span className="text-xs font-mono">{r.pack_id.slice(0, 8)}</span> },
    { key: "r", header: "Filer", render: (r) => <span className="text-xs capitalize">{r.filer_role}</span> },
    { key: "e", header: "Evidence", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.evidence_count)}</span> },
    { key: "a", header: "At stake", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.amount_at_stake))}</span> },
    { key: "s", header: "Submitted", render: (r) => <span className="text-xs">{new Date(r.submitted_at).toLocaleDateString("en-IN")}</span> },
    { key: "d", header: "Days open",
      render: (r) => {
        const tone = r.days_open > 7 ? "text-[var(--color-danger)]"
          : r.days_open > 3 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums font-semibold ${tone}`}>{formatNumber(r.days_open)}d</span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Open disputes</h1>
        <span className="text-xs text-[var(--color-muted)]">submitted evidence packs awaiting mediator decision</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Open count" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Total at stake" value={inr(totalStake)} />
          <StatCard label="Oldest" value={`${formatNumber(Math.max(0, ...rows.map((r) => r.days_open)))}d`} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.pack_id} emptyMessage="No open disputes." />
    </div>
  );
}
