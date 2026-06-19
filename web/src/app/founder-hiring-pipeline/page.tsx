import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder hiring pipeline — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_candidates: number;
  sourced_count: number;
  applied_count: number;
  screened_count: number;
  interviewed_count: number;
  offered_count: number;
  onboarding_count: number;
  active_count: number;
  rejected_count: number;
  withdrawn_count: number;
  conversion_pct_sourced_to_active: number;
  conversion_pct_applied_to_active: number;
  median_days_sourced_to_active: number;
  top_source: string;
  top_source_count: number;
};

type CandidateRow = {
  id: string;
  candidate_name: string;
  candidate_phone: string | null;
  candidate_city: string | null;
  role: string;
  source: string | null;
  funnel_stage: string;
  sourced_at: string;
  applied_at: string | null;
  offered_at: string | null;
  active_at: string | null;
  rejected_at: string | null;
  rejected_reason: string | null;
  expected_tier: string | null;
  days_in_funnel: number;
};

type BySourceRow = {
  source: string;
  candidates: number;
  active: number;
  rejected: number;
  in_pipeline: number;
  conversion_pct: number;
};

const STAGE_TONE: Record<string, string> = {
  sourced:     "text-[var(--color-muted)]",
  applied:     "text-[var(--color-info)]",
  screened:    "text-[var(--color-info)]",
  interview_1: "text-[var(--color-warn)]",
  interview_2: "text-[var(--color-warn)]",
  offered:     "text-[var(--color-accent)]",
  onboarding:  "text-[var(--color-accent)]",
  active:      "text-[var(--color-ok)]",
  rejected:    "text-[var(--color-danger)]",
  withdrawn:   "text-[var(--color-muted)]",
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  return new Date(s).toISOString().slice(0, 10);
}

export default async function FounderHiringPipelinePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, listRes, sourceRes] = await Promise.all([
    supabase.rpc("founder_hiring_pipeline_summary"),
    supabase.rpc("founder_hiring_pipeline_candidates", { p_limit: 100 }),
    supabase.rpc("founder_hiring_pipeline_by_source"),
  ]);
  if (summaryRes.error) throw new Error(`founder_hiring_pipeline_summary: ${summaryRes.error.message}`);
  if (listRes.error) throw new Error(`founder_hiring_pipeline_candidates: ${listRes.error.message}`);
  if (sourceRes.error) throw new Error(`founder_hiring_pipeline_by_source: ${sourceRes.error.message}`);

  const s = (summaryRes.data?.[0] ?? null) as SummaryRow | null;
  const list = (listRes.data ?? []) as CandidateRow[];
  const sources = (sourceRes.data ?? []) as BySourceRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder hiring pipeline ★★ r1340</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Engineer + ops recruitment funnel. Sourced → applied → screened → interview → offered → onboarding → active.
          Strictly internal. Not customer-facing.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-5">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total candidates</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(s.total_candidates)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Sourced</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-muted)]">{formatNumber(s.sourced_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Applied</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-info)]">{formatNumber(s.applied_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Screened</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-info)]">{formatNumber(s.screened_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Interviewing</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(s.interviewed_count)}</div>
            <div className="text-xs text-[var(--color-muted)]">interview_1 + interview_2</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Offered</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{formatNumber(s.offered_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Onboarding</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{formatNumber(s.onboarding_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Active</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(s.active_count)}</div>
            <div className="text-xs text-[var(--color-muted)]">hired + ramped</div>
          </div>
          <div className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Rejected</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-danger)]">{formatNumber(s.rejected_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Withdrawn</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-muted)]">{formatNumber(s.withdrawn_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Sourced → active</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{Number(s.conversion_pct_sourced_to_active ?? 0).toFixed(2)}%</div>
            <div className="text-xs text-[var(--color-muted)]">overall hire rate</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Applied → active</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{Number(s.conversion_pct_applied_to_active ?? 0).toFixed(2)}%</div>
            <div className="text-xs text-[var(--color-muted)]">post-application hire rate</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median sourced→active</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{Number(s.median_days_sourced_to_active ?? 0).toFixed(1)}d</div>
            <div className="text-xs text-[var(--color-muted)]">cycle time</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Top source</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{s.top_source ?? "n/a"}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Top source count</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-accent)]">{formatNumber(s.top_source_count)}</div>
          </div>
        </section>
      ) : null}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Candidate ledger (sorted by stage urgency)</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr className="border-b border-[var(--color-border)]">
                <th className="text-left px-3 py-2">Name</th>
                <th className="text-left px-3 py-2">City</th>
                <th className="text-left px-3 py-2">Role</th>
                <th className="text-left px-3 py-2">Source</th>
                <th className="text-left px-3 py-2">Stage</th>
                <th className="text-left px-3 py-2">Sourced</th>
                <th className="text-left px-3 py-2">Applied</th>
                <th className="text-left px-3 py-2">Offered</th>
                <th className="text-left px-3 py-2">Active</th>
                <th className="text-right px-3 py-2">Days in funnel</th>
                <th className="text-left px-3 py-2">Reject reason</th>
              </tr>
            </thead>
            <tbody>
              {list.length === 0 ? (
                <tr><td colSpan={11} className="px-3 py-6 text-center text-[var(--color-muted)]">No candidates registered yet.</td></tr>
              ) : list.map((r) => (
                <tr key={r.id} className="border-b border-[var(--color-border)]/40">
                  <td className="px-3 py-2 font-medium">{r.candidate_name}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.candidate_city ?? "—"}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.role}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.source ?? "—"}</td>
                  <td className={`px-3 py-2 font-medium ${STAGE_TONE[r.funnel_stage] ?? ""}`}>{r.funnel_stage}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.sourced_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.applied_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.offered_at)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{fmtDate(r.active_at)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(r.days_in_funnel ?? 0).toFixed(1)}</td>
                  <td className="px-3 py-2 text-[var(--color-muted)]">{r.rejected_reason ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Source breakdown</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-xs uppercase tracking-wider text-[var(--color-muted)]">
              <tr className="border-b border-[var(--color-border)]">
                <th className="text-left px-3 py-2">Source</th>
                <th className="text-right px-3 py-2">Candidates</th>
                <th className="text-right px-3 py-2">Active</th>
                <th className="text-right px-3 py-2">Rejected</th>
                <th className="text-right px-3 py-2">In pipeline</th>
                <th className="text-right px-3 py-2">Conversion %</th>
              </tr>
            </thead>
            <tbody>
              {sources.length === 0 ? (
                <tr><td colSpan={6} className="px-3 py-6 text-center text-[var(--color-muted)]">No source data yet.</td></tr>
              ) : sources.map((r) => (
                <tr key={r.source} className="border-b border-[var(--color-border)]/40">
                  <td className="px-3 py-2 font-medium">{r.source}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.candidates)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-ok)]">{formatNumber(r.active)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-danger)]">{formatNumber(r.rejected)}</td>
                  <td className="px-3 py-2 text-right tabular-nums text-[var(--color-info)]">{formatNumber(r.in_pipeline)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{Number(r.conversion_pct ?? 0).toFixed(2)}%</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-xs text-[var(--color-muted)] border-t border-[var(--color-border)] pt-3 space-y-1">
        <div>
          Benchmark expectations · sourced→active 2–5% across all channels · applied→active 15–25% post-screen · referral 3–4× the conversion of cold sources · median cycle 21–45 days field-eng / 45–90 days ops-lead.
        </div>
        <div>
          Writers: log_founder_hiring_register · log_founder_hiring_advance · log_founder_hiring_reject. Internal only — no exposure on public investor share, marketplace, or hospital-facing surfaces.
        </div>
      </footer>
    </div>
  );
}
