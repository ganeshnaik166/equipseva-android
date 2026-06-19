import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = { title: "Founder Weekly Board Pack" };
export const dynamic = "force-dynamic";

type Pack = {
  week_end: string;
  week_start: string;
  weekly_gmv_rupees: number;
  weekly_payouts_rupees: number;
  weekly_take_rate_pct: number;
  mrr_eop: number;
  mrr_eop_4wk_ago: number;
  mrr_delta_pct_4wk: number | null;
  amc_active_count_eop: number;
  amc_signed_this_week: number;
  amc_churned_this_week: number;
  amc_net_new: number;
  engineers_active_count_eop: number;
  engineers_added_this_week: number;
  engineers_churned_this_week: number;
  engineer_jobs_completed_week: number;
  hospitals_active_count_eop: number;
  hospitals_added_this_week: number;
  top_state_by_jobs: string;
  top_state_jobs_count: number;
  jobs_completed_this_week: number;
  jobs_initiated_this_week: number;
  average_completion_hours: number;
  code_red_count_this_week: number;
  dispute_count_this_week: number;
  dpdp_grievance_count_this_week: number;
  spot_audit_rating_avg_week: number;
  spot_audit_invites_sent_week: number;
  spot_audit_invites_responded_week: number;
  cash_collected_this_week: number;
  refunds_issued_this_week: number;
  open_payouts_count: number;
  open_disputes_count: number;
  open_incidents_count: number;
  open_grievances_count: number;
  shared_with_board?: boolean;
  shared_at?: string | null;
};

type HistoryRow = {
  week_end: string;
  weekly_gmv_rupees: number;
  weekly_payouts_rupees: number;
  mrr_eop: number;
  amc_active_count_eop: number;
  amc_net_new: number;
  engineers_active_count_eop: number;
  hospitals_active_count_eop: number;
  jobs_completed_this_week: number;
  code_red_count_this_week: number;
  spot_audit_rating_avg_week: number;
};

function lastSaturday(d = new Date()): string {
  const day = d.getDay();
  const diff = (day + 1) % 7;
  const sat = new Date(d);
  sat.setDate(d.getDate() - diff);
  return sat.toISOString().slice(0, 10);
}

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" | "info" }) {
  const toneClass =
    tone === "ok" ? "text-[var(--color-ok)]"
    : tone === "warn" ? "text-[var(--color-warn)]"
    : tone === "danger" ? "text-[var(--color-danger)]"
    : tone === "info" ? "text-[var(--color-info)]"
    : "text-[var(--color-fg)]";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)] uppercase tracking-wide">{label}</div>
      <div className={`mt-1 text-2xl font-semibold ${toneClass}`}>{value}</div>
      {sub ? <div className="mt-1 text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mt-6">
      <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">{title}</h2>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">{children}</div>
    </section>
  );
}

export default async function FounderWeeklyBoardPackPage({ searchParams }: { searchParams: Promise<{ week_end?: string }> }) {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const params = await searchParams;
  const weekEnd = params.week_end || lastSaturday();

  const { data: packData, error: packErr } = await sb.rpc("founder_weekly_board_pack", { p_week_end: weekEnd });
  const { data: historyData, error: histErr } = await sb.rpc("founder_weekly_board_pack_history", { p_weeks: 13 });

  if (packErr) {
    return (
      <main className="mx-auto max-w-7xl p-6">
        <h1 className="text-2xl font-semibold">Founder Weekly Board Pack</h1>
        <div className="mt-4 rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4 text-[var(--color-danger)]">
          Error loading board pack: {packErr.message}
        </div>
      </main>
    );
  }

  const pack = packData as Pack;
  const history = (historyData || []) as HistoryRow[];

  const mrrTone = pack.mrr_delta_pct_4wk !== null && pack.mrr_delta_pct_4wk >= 0 ? "ok" : "danger";
  const churnTone = pack.amc_net_new >= 0 ? "ok" : "danger";
  const codeRedTone = pack.code_red_count_this_week > 0 ? "danger" : "ok";
  const responseRate = pack.spot_audit_invites_sent_week > 0
    ? Math.round((pack.spot_audit_invites_responded_week / pack.spot_audit_invites_sent_week) * 100)
    : 0;

  return (
    <main className="mx-auto max-w-7xl p-6">
      <div className="flex flex-wrap items-baseline justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Founder Weekly Board Pack</h1>
          <p className="mt-1 text-sm text-[var(--color-muted)]">
            Week of {pack.week_start} to {pack.week_end}
            {pack.shared_with_board ? (
              <span className="ml-2 rounded bg-[var(--color-ok)]/10 px-2 py-0.5 text-xs text-[var(--color-ok)]">
                Shared with board {pack.shared_at ? `on ${pack.shared_at.slice(0, 10)}` : ""}
              </span>
            ) : null}
          </p>
        </div>
        <form className="flex items-center gap-2" method="get">
          <label htmlFor="week_end" className="text-xs text-[var(--color-muted)]">Week ending</label>
          <input
            type="date"
            id="week_end"
            name="week_end"
            defaultValue={weekEnd}
            className="rounded border border-[var(--color-border)] bg-[var(--color-surface)] px-2 py-1 text-sm"
          />
          <button type="submit" className="rounded bg-[var(--color-accent)] px-3 py-1 text-sm text-white">Load</button>
        </form>
      </div>

      <Section title="Revenue">
        <Card label="Weekly GMV" value={`₹${formatNumber(pack.weekly_gmv_rupees)}`} />
        <Card label="Weekly Payouts" value={`₹${formatNumber(pack.weekly_payouts_rupees)}`} />
        <Card label="Take Rate" value={`${pack.weekly_take_rate_pct}%`} tone="info" />
        <Card
          label="MRR (end of period)"
          value={`₹${formatNumber(pack.mrr_eop)}`}
          sub={pack.mrr_delta_pct_4wk !== null ? `${pack.mrr_delta_pct_4wk >= 0 ? "+" : ""}${pack.mrr_delta_pct_4wk}% vs 4wk ago` : "no baseline"}
          tone={mrrTone}
        />
      </Section>

      <Section title="AMC">
        <Card label="Active Contracts (EOP)" value={formatNumber(pack.amc_active_count_eop)} />
        <Card label="Signed This Week" value={formatNumber(pack.amc_signed_this_week)} tone="ok" />
        <Card label="Churned This Week" value={formatNumber(pack.amc_churned_this_week)} tone="danger" />
        <Card label="Net New" value={`${pack.amc_net_new >= 0 ? "+" : ""}${pack.amc_net_new}`} tone={churnTone} />
      </Section>

      <Section title="Engineers">
        <Card label="Active (EOP)" value={formatNumber(pack.engineers_active_count_eop)} />
        <Card label="Added This Week" value={formatNumber(pack.engineers_added_this_week)} tone="ok" />
        <Card label="Churned This Week" value={formatNumber(pack.engineers_churned_this_week)} tone="warn" />
        <Card label="Jobs Completed (eng)" value={formatNumber(pack.engineer_jobs_completed_week)} />
      </Section>

      <Section title="Hospitals">
        <Card label="Active Hospitals (EOP)" value={formatNumber(pack.hospitals_active_count_eop)} />
        <Card label="Added This Week" value={formatNumber(pack.hospitals_added_this_week)} tone="ok" />
        <Card label="Top State by Jobs" value={pack.top_state_by_jobs} sub={`${formatNumber(pack.top_state_jobs_count)} jobs`} tone="info" />
        <Card label="Cash Collected" value={`₹${formatNumber(pack.cash_collected_this_week)}`} />
      </Section>

      <Section title="Operations">
        <Card label="Jobs Completed" value={formatNumber(pack.jobs_completed_this_week)} />
        <Card label="Jobs Initiated" value={formatNumber(pack.jobs_initiated_this_week)} />
        <Card label="Avg Completion (hrs)" value={`${pack.average_completion_hours}`} tone="info" />
        <Card label="Code Red Count" value={formatNumber(pack.code_red_count_this_week)} tone={codeRedTone} />
      </Section>

      <Section title="Quality & Risk">
        <Card label="Spot Audit Avg Rating" value={`${pack.spot_audit_rating_avg_week} / 5`} tone="info" />
        <Card label="Audit Invites Sent" value={formatNumber(pack.spot_audit_invites_sent_week)} sub={`${responseRate}% responded`} />
        <Card label="Disputes This Week" value={formatNumber(pack.dispute_count_this_week)} tone={pack.dispute_count_this_week > 0 ? "warn" : "ok"} />
        <Card label="DPDP Grievances" value={formatNumber(pack.dpdp_grievance_count_this_week)} tone={pack.dpdp_grievance_count_this_week > 0 ? "warn" : "ok"} />
      </Section>

      <Section title="Open Health">
        <Card label="Open Payouts" value={formatNumber(pack.open_payouts_count)} tone={pack.open_payouts_count > 10 ? "warn" : "ok"} />
        <Card label="Open Disputes" value={formatNumber(pack.open_disputes_count)} tone={pack.open_disputes_count > 0 ? "warn" : "ok"} />
        <Card label="Open Incidents" value={formatNumber(pack.open_incidents_count)} tone={pack.open_incidents_count > 0 ? "danger" : "ok"} />
        <Card label="Open Grievances" value={formatNumber(pack.open_grievances_count)} tone={pack.open_grievances_count > 0 ? "warn" : "ok"} />
      </Section>

      <section className="mt-8">
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">13-Week Trend</h2>
        {histErr ? (
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-3 text-sm text-[var(--color-warn)]">
            History unavailable: {histErr.message}
          </div>
        ) : history.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3 text-sm text-[var(--color-muted)]">
            No prior weeks logged yet. Run this page across past Saturdays to build the trend.
          </div>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
            <table className="w-full min-w-[900px] text-sm">
              <thead className="border-b border-[var(--color-border)] text-xs uppercase tracking-wide text-[var(--color-muted)]">
                <tr>
                  <th className="px-3 py-2 text-left">Week End</th>
                  <th className="px-3 py-2 text-right">GMV</th>
                  <th className="px-3 py-2 text-right">Payouts</th>
                  <th className="px-3 py-2 text-right">MRR</th>
                  <th className="px-3 py-2 text-right">AMC Active</th>
                  <th className="px-3 py-2 text-right">AMC Net</th>
                  <th className="px-3 py-2 text-right">Engineers</th>
                  <th className="px-3 py-2 text-right">Hospitals</th>
                  <th className="px-3 py-2 text-right">Jobs</th>
                  <th className="px-3 py-2 text-right">Code Red</th>
                  <th className="px-3 py-2 text-right">Audit Avg</th>
                </tr>
              </thead>
              <tbody>
                {history.map((row) => (
                  <tr key={row.week_end} className="border-b border-[var(--color-border)] last:border-b-0">
                    <td className="px-3 py-2 font-mono text-xs">{row.week_end}</td>
                    <td className="px-3 py-2 text-right">₹{formatNumber(row.weekly_gmv_rupees)}</td>
                    <td className="px-3 py-2 text-right">₹{formatNumber(row.weekly_payouts_rupees)}</td>
                    <td className="px-3 py-2 text-right">₹{formatNumber(row.mrr_eop)}</td>
                    <td className="px-3 py-2 text-right">{formatNumber(row.amc_active_count_eop)}</td>
                    <td className={`px-3 py-2 text-right ${row.amc_net_new >= 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]"}`}>
                      {row.amc_net_new >= 0 ? "+" : ""}{row.amc_net_new}
                    </td>
                    <td className="px-3 py-2 text-right">{formatNumber(row.engineers_active_count_eop)}</td>
                    <td className="px-3 py-2 text-right">{formatNumber(row.hospitals_active_count_eop)}</td>
                    <td className="px-3 py-2 text-right">{formatNumber(row.jobs_completed_this_week)}</td>
                    <td className={`px-3 py-2 text-right ${row.code_red_count_this_week > 0 ? "text-[var(--color-danger)]" : ""}`}>
                      {formatNumber(row.code_red_count_this_week)}
                    </td>
                    <td className="px-3 py-2 text-right">{row.spot_audit_rating_avg_week}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <div className="mt-8 flex flex-wrap gap-3">
        {!pack.shared_with_board ? (
          <Link
            href={`/founder-weekly-board-pack/mark-shared?week_end=${pack.week_end}`}
            className="rounded-lg bg-[var(--color-accent)] px-4 py-2 text-sm font-semibold text-white"
          >
            Mark as shared with board
          </Link>
        ) : (
          <span className="rounded-lg border border-[var(--color-ok)] px-4 py-2 text-sm text-[var(--color-ok)]">
            Already shared with board
          </span>
        )}
        <Link
          href="/ops-index"
          className="rounded-lg border border-[var(--color-border)] px-4 py-2 text-sm text-[var(--color-muted)]"
        >
          Back to Ops Index
        </Link>
      </div>
    </main>
  );
}