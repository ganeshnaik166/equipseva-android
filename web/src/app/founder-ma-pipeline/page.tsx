import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder M&A pipeline — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_targets: number;
  identified_count: number;
  contacted_count: number;
  nda_signed_count: number;
  dd_count: number;
  loi_count: number;
  term_sheet_count: number;
  closed_count: number;
  passed_count: number;
  total_estimated_acquisition_rupees: number;
  total_closed_rupees: number;
  total_pipeline_value: number;
  top_priority_open_count: number;
  days_since_last_activity_median: number;
  active_integrations_count: number;
};

type TargetRow = {
  id: string;
  target_company_name: string;
  industry_segment: string;
  deal_status: string;
  deal_priority: string;
  target_revenue_rupees_annual: number | null;
  estimated_acquisition_rupees: number | null;
  target_hospital_count: number | null;
  target_engineer_count: number | null;
  integration_status: string;
  primary_contact_name: string | null;
  identified_at: string;
  closed_at: string | null;
  last_activity_at: string | null;
  activity_count: number;
};

const PRIORITY_TONE: Record<string, string> = {
  p0_critical: "text-[var(--color-danger)]",
  p1_high:     "text-[var(--color-warn)]",
  medium:      "text-[var(--color-info)]",
  p3_low:      "text-[var(--color-muted)]",
};

const STATUS_TONE: Record<string, string> = {
  identified:     "text-[var(--color-muted)]",
  contacted:      "text-[var(--color-info)]",
  nda_signed:     "text-[var(--color-info)]",
  dd_in_progress: "text-[var(--color-warn)]",
  loi_sent:       "text-[var(--color-warn)]",
  term_sheet:     "text-[var(--color-accent)]",
  closed:         "text-[var(--color-ok)]",
  passed:         "text-[var(--color-muted)]",
};

const INTEG_TONE: Record<string, string> = {
  not_started: "text-[var(--color-muted)]",
  planning:    "text-[var(--color-info)]",
  migrating:   "text-[var(--color-warn)]",
  live:        "text-[var(--color-ok)]",
  rolled_back: "text-[var(--color-danger)]",
};

function inr(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹" + formatNumber(Number(n));
}

function fmtDate(s: string | null): string {
  if (!s) return "—";
  return new Date(s).toISOString().slice(0, 10);
}

export default async function FounderMaPipelinePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, listRes] = await Promise.all([
    supabase.rpc("founder_ma_pipeline_summary"),
    supabase.rpc("founder_ma_targets_recent", { p_limit: 50 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_ma_pipeline_summary: ${summaryRes.error.message}`);
  if (listRes.error) throw new Error(`founder_ma_targets_recent: ${listRes.error.message}`);
  const s = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const list = (listRes.data ?? []) as TargetRow[];

  const statusBreakdown: Array<{ label: string; count: number }> = s ? [
    { label: "identified",     count: s.identified_count },
    { label: "contacted",      count: s.contacted_count },
    { label: "nda_signed",     count: s.nda_signed_count },
    { label: "dd_in_progress", count: s.dd_count },
    { label: "loi_sent",       count: s.loi_count },
    { label: "term_sheet",     count: s.term_sheet_count },
    { label: "closed",         count: s.closed_count },
    { label: "passed",         count: s.passed_count },
  ] : [];

  const integ = list.reduce<Record<string, number>>((acc, r) => {
    acc[r.integration_status] = (acc[r.integration_status] ?? 0) + 1;
    return acc;
  }, {});

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder M&A pipeline ★ r1324</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Internal corp-dev tracker — acquisition targets, deal stage, integration status.
          M&A targets are NOT customer-facing — strictly internal corp-dev tracker.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total targets</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.total_targets)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Identified</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-muted)]">{formatNumber(s.identified_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Contacted</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-info)]">{formatNumber(s.contacted_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">NDA signed</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-info)]">{formatNumber(s.nda_signed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">DD in progress</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(s.dd_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">LOI sent</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(s.loi_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Term sheet</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{formatNumber(s.term_sheet_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Closed</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(s.closed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Passed</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-muted)]">{formatNumber(s.passed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Top-priority open</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-danger)]">{formatNumber(s.top_priority_open_count)}</div>
            <div className="text-xs text-[var(--color-muted)]">p0_critical + p1_high · not closed/passed</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Est. acquisition (all)</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{inr(s.total_estimated_acquisition_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Closed value</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{inr(s.total_closed_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Open pipeline value</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{inr(s.total_pipeline_value)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median days since activity</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(Math.round(Number(s.days_since_last_activity_median ?? 0)))}</div>
            <div className="text-xs text-[var(--color-muted)]">across open deals</div>
          </div>
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Active integrations</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(s.active_integrations_count)}</div>
            <div className="text-xs text-[var(--color-muted)]">planning + migrating</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Pipeline (sorted by priority, then recent activity)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr className="border-b border-[var(--color-border)]">
                <th className="text-left px-3 py-2">Target</th>
                <th className="text-left px-3 py-2">Segment</th>
                <th className="text-left px-3 py-2">Priority</th>
                <th className="text-left px-3 py-2">Status</th>
                <th className="text-right px-3 py-2">Revenue (annual)</th>
                <th className="text-right px-3 py-2">Est. price</th>
                <th className="text-right px-3 py-2">Hosp / Eng</th>
                <th className="text-left px-3 py-2">Integration</th>
                <th className="text-left px-3 py-2">Contact</th>
                <th className="text-left px-3 py-2">Last activity</th>
                <th className="text-right px-3 py-2">Acts</th>
              </tr>
            </thead>
            <tbody>
              {list.length === 0 ? (
                <tr><td colSpan={11} className="px-3 py-6 text-center text-[var(--color-muted)]">No M&A targets registered yet.</td></tr>
              ) : list.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]/40">
                  <td className="px-3 py-2 font-medium">{r.target_company_name}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.industry_segment}</td>
                  <td className={`px-3 py-2 font-medium ${PRIORITY_TONE[r.deal_priority] ?? ""}`}>{r.deal_priority}</td>
                  <td className={`px-3 py-2 ${STATUS_TONE[r.deal_status] ?? ""}`}>{r.deal_status}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(r.target_revenue_rupees_annual)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{inr(r.estimated_acquisition_rupees)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.target_hospital_count ?? 0)} / {formatNumber(r.target_engineer_count ?? 0)}</td>
                  <td className={`px-3 py-2 ${INTEG_TONE[r.integration_status] ?? ""}`}>{r.integration_status}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.primary_contact_name ?? "—"}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.last_activity_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.activity_count)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <div>
          <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Status distribution</h2>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
            <table className="min-w-full text-sm">
              <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <tr className="border-b border-[var(--color-border)]">
                  <th className="text-left px-3 py-2">Stage</th>
                  <th className="text-right px-3 py-2">Count</th>
                </tr>
              </thead>
              <tbody>
                {statusBreakdown.map((b) => (
                  <tr key={b.label} className="border-b border-[var(--color-border)]/40">
                    <td className={`px-3 py-2 ${STATUS_TONE[b.label] ?? ""}`}>{b.label}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(b.count)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
        <div>
          <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Integration status</h2>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
            <table className="min-w-full text-sm">
              <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <tr className="border-b border-[var(--color-border)]">
                  <th className="text-left px-3 py-2">Phase</th>
                  <th className="text-right px-3 py-2">Targets</th>
                </tr>
              </thead>
              <tbody>
                {["not_started","planning","migrating","live","rolled_back"].map((k) => (
                  <tr key={k} className="border-b border-[var(--color-border)]/40">
                    <td className={`px-3 py-2 ${INTEG_TONE[k] ?? ""}`}>{k}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{formatNumber(integ[k] ?? 0)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <footer className="text-xs text-[var(--color-muted)] border-t border-[var(--color-border)] pt-3">
        Internal corp-dev only. M&A targets do not appear in any customer-facing route, public investor share, or marketplace surface.
        Writers: log_founder_ma_register_target · log_founder_ma_status_change · log_founder_ma_activity.
      </footer>
    </div>
  );
}
