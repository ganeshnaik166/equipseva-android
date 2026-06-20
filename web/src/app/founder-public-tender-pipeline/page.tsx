import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Public tender pipeline — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_tenders: number;
  researching_count: number;
  preparing_bid_count: number;
  submitted_count: number;
  shortlisted_count: number;
  awarded_count: number;
  rejected_count: number;
  withdrawn_count: number;
  total_estimated_value_rupees: number;
  total_awarded_amount_rupees: number;
  win_rate_pct: number;
  deadlines_within_14d: number;
  overdue_no_submission: number;
  avg_days_research_to_submit: number;
  top_authority: string | null;
  generated_at: string;
};

type TenderRow = {
  id: string;
  tender_label: string;
  tender_kind: string;
  procuring_authority: string | null;
  estimated_value_rupees: number | null;
  bid_submission_deadline: string;
  our_bid_status: string;
  awarded_to: string | null;
  awarded_amount_rupees: number | null;
  awarded_at: string | null;
  days_to_deadline: number;
  created_at: string;
  updated_at: string;
};

type ActivityRow = {
  id: string;
  tender_id: string;
  tender_label: string;
  activity_kind: string;
  description: string | null;
  happened_at: string;
  created_by: string | null;
};

type DeadlineRow = {
  id: string;
  tender_label: string;
  procuring_authority: string | null;
  bid_submission_deadline: string;
  days_remaining: number;
  our_bid_status: string;
  estimated_value_rupees: number | null;
};

function Card({ title, val, sub, danger, ok, warn }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; warn?: boolean }) {
  const color = danger ? "text-[var(--color-danger)]" : warn ? "text-[var(--color-warn)]" : ok ? "text-[var(--color-ok)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${color}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function StatusBadge({ s }: { s: string }) {
  const cls =
    s === "awarded" ? "bg-green-100 text-[var(--color-ok)]"
      : s === "rejected" || s === "withdrawn" ? "bg-red-100 text-[var(--color-danger)]"
        : s === "submitted" || s === "shortlisted" ? "bg-blue-100 text-blue-700"
          : s === "preparing_bid" ? "bg-yellow-100 text-[var(--color-warn)]"
            : "bg-gray-100 text-[var(--color-muted)]";
  return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{s}</span>;
}

export default async function FounderPublicTenderPipelinePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, tRes, aRes, dRes] = await Promise.all([
    supabase.rpc("founder_public_tender_pipeline_summary"),
    supabase.rpc("founder_public_tenders_recent", { p_limit: 30 }),
    supabase.rpc("founder_public_tender_activities_recent", { p_limit: 50 }),
    supabase.rpc("founder_public_tenders_upcoming_deadlines"),
  ]);
  if (sumRes.error) throw new Error(`tender_summary: ${sumRes.error.message}`);
  if (tRes.error) throw new Error(`tenders_recent: ${tRes.error.message}`);
  if (aRes.error) throw new Error(`activities_recent: ${aRes.error.message}`);
  if (dRes.error) throw new Error(`upcoming_deadlines: ${dRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as SummaryRow | null;
  const tenders = (tRes.data ?? []) as TenderRow[];
  const activities = (aRes.data ?? []) as ActivityRow[];
  const deadlines = (dRes.data ?? []) as DeadlineRow[];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between gap-4">
        <h1 className="text-xl font-semibold">Public tender pipeline</h1>
        <span className="text-xs text-[var(--color-muted)]">
          16 KPIs · 14d deadline alert · 30-tender ledger · 50-activity feed · government / hospital tender tracking
        </span>
      </header>

      {deadlines.length > 0 ? (
        <section className="rounded-lg border border-[var(--color-warn)] bg-yellow-50 p-4">
          <h2 className="mb-2 text-sm font-semibold text-[var(--color-warn)]">
            Upcoming deadlines within 14 days ({deadlines.length})
          </h2>
          <div className="overflow-x-auto">
            <table className="min-w-full text-sm">
              <thead className="text-xs uppercase text-[var(--color-muted)]">
                <tr>
                  <th className="px-3 py-2 text-left">Tender</th>
                  <th className="px-3 py-2 text-left">Authority</th>
                  <th className="px-3 py-2 text-left">Deadline</th>
                  <th className="px-3 py-2 text-right">Days left</th>
                  <th className="px-3 py-2 text-left">Status</th>
                  <th className="px-3 py-2 text-right">Est value (INR)</th>
                </tr>
              </thead>
              <tbody>
                {deadlines.map((d) => (
                  <tr key={d.id} className="border-t border-[var(--color-border)]">
                    <td className="px-3 py-2">{d.tender_label}</td>
                    <td className="px-3 py-2">{d.procuring_authority ?? "—"}</td>
                    <td className="px-3 py-2 tabular-nums">{d.bid_submission_deadline}</td>
                    <td className={`px-3 py-2 text-right tabular-nums ${d.days_remaining <= 3 ? "text-[var(--color-danger)] font-semibold" : ""}`}>{d.days_remaining}</td>
                    <td className="px-3 py-2"><StatusBadge s={d.our_bid_status} /></td>
                    <td className="px-3 py-2 text-right tabular-nums">{d.estimated_value_rupees == null ? "—" : formatNumber(d.estimated_value_rupees)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ) : null}

      {s ? (
        <section>
          <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Pipeline summary</h2>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-4">
            <Card title="Total tenders" val={formatNumber(s.total_tenders)} />
            <Card title="Researching" val={formatNumber(s.researching_count)} />
            <Card title="Preparing bid" val={formatNumber(s.preparing_bid_count)} warn />
            <Card title="Submitted" val={formatNumber(s.submitted_count)} />
            <Card title="Shortlisted" val={formatNumber(s.shortlisted_count)} ok />
            <Card title="Awarded" val={formatNumber(s.awarded_count)} ok />
            <Card title="Rejected" val={formatNumber(s.rejected_count)} danger={s.rejected_count > 0} />
            <Card title="Withdrawn" val={formatNumber(s.withdrawn_count)} />
            <Card title="Total estimated value (INR)" val={formatNumber(s.total_estimated_value_rupees)} sub="across all open tenders" />
            <Card title="Total awarded (INR)" val={formatNumber(s.total_awarded_amount_rupees)} ok sub="wins only" />
            <Card title="Win rate" val={`${Number(s.win_rate_pct).toFixed(1)}%`}
                  ok={s.win_rate_pct >= 30} danger={s.win_rate_pct < 10 && (s.awarded_count + s.rejected_count) > 0} sub="awarded / decided" />
            <Card title="Deadlines within 14d" val={formatNumber(s.deadlines_within_14d)}
                  warn={s.deadlines_within_14d > 0} danger={s.deadlines_within_14d >= 5} />
            <Card title="Overdue no submission" val={formatNumber(s.overdue_no_submission)}
                  danger={s.overdue_no_submission > 0} sub="missed deadlines" />
            <Card title="Avg days research→submit" val={Number(s.avg_days_research_to_submit).toFixed(1)} sub="cycle time" />
            <Card title="Top authority" val={s.top_authority ?? "—"} sub="most tenders" />
            <Card title="Generated" val={formatRelativeTime(s.generated_at)} sub={s.generated_at} />
          </div>
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No summary data.</p>}

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Tender ledger (next 30 by deadline)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">Tender</th>
                <th className="px-3 py-2 text-left">Kind</th>
                <th className="px-3 py-2 text-left">Authority</th>
                <th className="px-3 py-2 text-right">Est value (INR)</th>
                <th className="px-3 py-2 text-left">Deadline</th>
                <th className="px-3 py-2 text-right">Days</th>
                <th className="px-3 py-2 text-left">Status</th>
                <th className="px-3 py-2 text-left">Awarded to</th>
                <th className="px-3 py-2 text-right">Award (INR)</th>
              </tr>
            </thead>
            <tbody>
              {tenders.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={9}>No tenders.</td></tr>
              ) : tenders.map((t) => (
                <tr key={t.id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{t.tender_label}</td>
                  <td className="px-3 py-2">{t.tender_kind}</td>
                  <td className="px-3 py-2">{t.procuring_authority ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{t.estimated_value_rupees == null ? "—" : formatNumber(t.estimated_value_rupees)}</td>
                  <td className="px-3 py-2 tabular-nums">{t.bid_submission_deadline}</td>
                  <td className={`px-3 py-2 text-right tabular-nums ${t.days_to_deadline < 0 ? "text-[var(--color-danger)]" : t.days_to_deadline <= 7 ? "text-[var(--color-warn)]" : ""}`}>{t.days_to_deadline}</td>
                  <td className="px-3 py-2"><StatusBadge s={t.our_bid_status} /></td>
                  <td className="px-3 py-2">{t.awarded_to ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{t.awarded_amount_rupees == null ? "—" : formatNumber(t.awarded_amount_rupees)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-sm font-medium text-[var(--color-muted)]">Activity feed (last 50)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
          <table className="min-w-full text-sm">
            <thead className="bg-[var(--color-surface)] text-xs uppercase text-[var(--color-muted)]">
              <tr>
                <th className="px-3 py-2 text-left">When</th>
                <th className="px-3 py-2 text-left">Tender</th>
                <th className="px-3 py-2 text-left">Activity</th>
                <th className="px-3 py-2 text-left">Description</th>
                <th className="px-3 py-2 text-left">Actor</th>
              </tr>
            </thead>
            <tbody>
              {activities.length === 0 ? (
                <tr><td className="px-3 py-3 text-[var(--color-muted)]" colSpan={5}>No activity.</td></tr>
              ) : activities.map((a) => (
                <tr key={a.id} className="border-t border-[var(--color-border)]">
                  <td className="px-3 py-2">{formatRelativeTime(a.happened_at)}</td>
                  <td className="px-3 py-2">{a.tender_label}</td>
                  <td className="px-3 py-2">{a.activity_kind}</td>
                  <td className="px-3 py-2">{a.description ?? "—"}</td>
                  <td className="px-3 py-2 tabular-nums">{a.created_by ? shortId(a.created_by) : "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
