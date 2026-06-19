import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Week in review — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  week_start_date: string; week_end_date: string;
  amcs_signed_count: number; amcs_churned_count: number; amc_net_new: number;
  total_mrr_added_rupees: number;
  jobs_completed_count: number; jobs_initiated_count: number;
  payments_captured_count: number; payments_captured_rupees: number;
  payouts_processed_count: number; payouts_processed_rupees: number;
  code_red_count: number;
  open_incidents_count: number;
  new_postmortems_count: number;
  founder_actions_logged: number;
  engineers_added_count: number;
  hospitals_added_count: number;
  spare_parts_orders_count: number;
  spare_parts_orders_rupees: number;
  refunds_issued_rupees: number;
  net_cash_position_change_rupees: number;
  generated_at: string;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)] tabular-nums">{sub}</div> : null}
    </div>
  );
}
function rup(n: number): string { return `₹${formatNumber(Math.round(n))}`; }

export default async function FounderWeekInReviewPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const { data, error } = await sb.rpc("founder_week_in_review_summary");
  if (error) throw new Error(`week_in_review: ${error.message}`);
  const s = (data?.[0] ?? null) as Summary | null;
  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Week in review ★ rolling 7-day cockpit</h1>
        {s ? (
          <p className="mt-1 text-sm text-[var(--color-muted)]">
            {s.week_start_date} → {s.week_end_date} · auto-generated 22-KPI weekly snapshot across AMCs, jobs, payments, payouts, code reds, incidents, postmortems, founder actions, hires, hospitals, spares, refunds, cash.
          </p>
        ) : null}
      </header>

      {s ? (
        <>
          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Revenue & AMC</h2>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <Card label="AMCs signed" value={formatNumber(s.amcs_signed_count)} tone="ok" />
              <Card label="AMCs churned" value={formatNumber(s.amcs_churned_count)} tone={s.amcs_churned_count > 0 ? "danger" : undefined} />
              <Card label="Net new AMCs" value={(s.amc_net_new >= 0 ? "+" : "") + formatNumber(s.amc_net_new)} tone={s.amc_net_new >= 0 ? "ok" : "danger"} />
              <Card label="MRR added" value={rup(s.total_mrr_added_rupees)} />
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Operations</h2>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <Card label="Jobs completed" value={formatNumber(s.jobs_completed_count)} />
              <Card label="Jobs initiated" value={formatNumber(s.jobs_initiated_count)} />
              <Card label="Code Red events" value={formatNumber(s.code_red_count)} tone={s.code_red_count > 0 ? "warn" : undefined} />
              <Card label="Open incidents" value={formatNumber(s.open_incidents_count)} tone={s.open_incidents_count > 0 ? "danger" : "ok"} />
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Cash & payouts</h2>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <Card label="Payments captured" value={formatNumber(s.payments_captured_count)} sub={rup(s.payments_captured_rupees)} />
              <Card label="Payouts processed" value={formatNumber(s.payouts_processed_count)} sub={rup(s.payouts_processed_rupees)} />
              <Card label="Refunds issued" value={rup(s.refunds_issued_rupees)} tone={s.refunds_issued_rupees > 0 ? "warn" : undefined} />
              <Card label="Cash position Δ" value={rup(s.net_cash_position_change_rupees)} tone={s.net_cash_position_change_rupees >= 0 ? "ok" : "danger"} />
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Supply & onboarding</h2>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
              <Card label="Engineers added" value={formatNumber(s.engineers_added_count)} tone={s.engineers_added_count > 0 ? "ok" : undefined} />
              <Card label="Hospitals added" value={formatNumber(s.hospitals_added_count)} tone={s.hospitals_added_count > 0 ? "ok" : undefined} />
              <Card label="Spare orders" value={formatNumber(s.spare_parts_orders_count)} sub={rup(s.spare_parts_orders_rupees)} />
              <Card label="New postmortems" value={formatNumber(s.new_postmortems_count)} />
            </div>
          </section>

          <section className="grid grid-cols-2 gap-3 md:grid-cols-3">
            <Card label="Founder actions logged" value={formatNumber(s.founder_actions_logged)} sub="ACK/RESOLVE/ESCALATE/IGNORE" />
            <Card label="Week start" value={s.week_start_date} />
            <Card label="Week end" value={s.week_end_date} />
          </section>
        </>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}

      <p className="text-xs text-[var(--color-muted)]">
        Pair with /founder-weekly-board-pack (r1317) for the 25-KPI investor view. This page is the FOUNDER&apos;s weekly heartbeat, not the BOARD pack.
      </p>
    </div>
  );
}
