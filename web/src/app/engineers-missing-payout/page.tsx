import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineers missing payout method — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineer_user_id: string;
  display_name: string;
  jobs_completed_30d: number;
  gross_earned_30d: number;
  queued_payouts: number;
  oldest_queue_days: number;
};

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

export default async function EngineersMissingPayoutPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineers_missing_payout");
  if (error) throw new Error(`founder_engineers_missing_payout: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const totalEarned = rows.reduce((s, r) => s + Number(r.gross_earned_30d), 0);
  const totalQueued = rows.reduce((s, r) => s + r.queued_payouts, 0);
  const cols: Column<Row>[] = [
    { key: "n", header: "Engineer", render: (r) => <span className="text-xs">{r.display_name}</span> },
    { key: "j", header: "Jobs (30d)", render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.jobs_completed_30d)}</span> },
    { key: "g", header: "Earned (30d)", render: (r) => <span className="text-xs tabular-nums font-semibold">{inr(Number(r.gross_earned_30d))}</span> },
    { key: "q", header: "Queued payouts",
      render: (r) => {
        const tone = r.queued_payouts > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
        return <span className={`text-xs tabular-nums ${tone}`}>{formatNumber(r.queued_payouts)}</span>;
      }
    },
    { key: "a", header: "Oldest queue",
      render: (r) => {
        const tone = r.oldest_queue_days > 14 ? "text-[var(--color-danger)]"
          : r.oldest_queue_days > 7 ? "text-[var(--color-warn)]" : "";
        return <span className={`text-xs tabular-nums ${tone}`}>
          {r.oldest_queue_days > 0 ? `${formatNumber(r.oldest_queue_days)}d` : "—"}
        </span>;
      }
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineers missing payout method</h1>
        <span className="text-xs text-[var(--color-muted)]">earned in 30d but no verified VPA · outreach queue</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3">
          <StatCard label="Engineers blocked" value={formatNumber(rows.length)} tone={rows.length > 0 ? "warn" : "ok"} />
          <StatCard label="Unpaid earned (30d)" value={inr(totalEarned)} tone={totalEarned > 0 ? "warn" : "ok"} />
          <StatCard label="Queued no-method payouts" value={formatNumber(totalQueued)} tone={totalQueued > 0 ? "danger" : "ok"} />
        </div>
      </section>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.engineer_user_id} emptyMessage="All earning engineers have verified payout methods." />
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this surface.</strong> Engineers who completed jobs in last 30d but
        have NO verified row in engineer_payout_methods (VPA pending). Money sits in
        escrow waiting on their VPA. Direct nudge candidate — &quot;you have Rs.X waiting,
        verify your UPI&quot;. Ordered by gross earned DESC so biggest unpaid engineers
        come first.
      </section>
    </div>
  );
}
