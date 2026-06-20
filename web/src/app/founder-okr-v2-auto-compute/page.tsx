import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder OKR v2 auto-compute — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_rules: number;
  active_count: number;
  inactive_count: number;
  hourly_count: number;
  daily_count: number;
  weekly_count: number;
  monthly_count: number;
  quarterly_count: number;
  on_demand_count: number;
  total_krs_with_auto: number;
  total_krs_without_auto: number;
  due_now_count: number;
  last_run_at: string | null;
  kr_avg_progress_pct_with_auto: number;
  kr_avg_progress_pct_without_auto: number;
  generated_at: string;
};

type RuleRow = {
  id: string;
  key_result_id: string;
  kr_title: string;
  objective_title: string;
  quarter_label: string;
  source_kind: string;
  source_descriptor: string;
  compute_frequency: string;
  is_active: boolean;
  last_computed_at: string | null;
  last_computed_value: number | null;
  current_value: number | null;
  target_value: number | null;
  progress_pct: number;
  is_due: boolean;
  updated_at: string;
};

type DueRow = {
  id: string;
  key_result_id: string;
  kr_title: string;
  objective_title: string;
  source_kind: string;
  source_descriptor: string;
  compute_frequency: string;
  last_computed_at: string | null;
  staleness: string;
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const FREQ_TONE: Record<string, string> = {
  hourly:    "text-[var(--color-danger)]",
  daily:     "text-[var(--color-warn)]",
  weekly:    "text-[var(--color-info)]",
  monthly:   "text-[var(--color-muted)]",
  quarterly: "text-[var(--color-muted)]",
  on_demand: "text-[var(--color-muted)]",
};

const KIND_BADGE: Record<string, string> = {
  rpc_call:    "border-[var(--color-info)]   text-[var(--color-info)]",
  count_query: "border-[var(--color-ok)]     text-[var(--color-ok)]",
  sum_query:   "border-[var(--color-ok)]     text-[var(--color-ok)]",
  formula:     "border-[var(--color-warn)]   text-[var(--color-warn)]",
  manual_only: "border-[var(--color-muted)]  text-[var(--color-muted)]",
};

function progressTone(pct: number): string {
  if (pct >= 100) return "text-[var(--color-ok)]";
  if (pct >= 70)  return "text-[var(--color-info)]";
  if (pct >= 40)  return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

function fmtAge(iso: string | null): string {
  if (!iso) return "never";
  const d = new Date(iso).getTime();
  const mins = Math.floor((Date.now() - d) / 60_000);
  if (mins < 60)   return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
}

export default async function FounderOkrV2AutoComputePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, rulesRes, dueRes] = await Promise.all([
    supabase.rpc("founder_okr_v2_auto_compute_summary"),
    supabase.rpc("founder_okr_v2_auto_compute_rules_recent", { p_limit: 80 }),
    supabase.rpc("founder_okr_v2_auto_compute_due_runs",     { p_limit: 50 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_okr_v2_auto_compute_summary: ${summaryRes.error.message}`);
  if (rulesRes.error)   throw new Error(`founder_okr_v2_auto_compute_rules_recent: ${rulesRes.error.message}`);
  if (dueRes.error)     throw new Error(`founder_okr_v2_auto_compute_due_runs: ${dueRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rules = (rulesRes.data ?? []) as RuleRow[];
  const due   = (dueRes.data   ?? []) as DueRow[];

  const dueTone   = s.due_now_count > 0 ? "border-[var(--color-warn)]" : "border-[var(--color-ok)]";
  const liftPct   = (s.kr_avg_progress_pct_with_auto ?? 0) - (s.kr_avg_progress_pct_without_auto ?? 0);
  const liftTone  = liftPct > 0
    ? "border-[var(--color-ok)]"
    : liftPct < 0 ? "border-[var(--color-warn)]" : "border-[var(--color-border)]";

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder OKR v2 — auto-compute ★★★★ r1416</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Auto-computed key results: pull <code className="font-mono">current_value</code> from live RPCs / queries on
          a schedule (hourly · daily · weekly · monthly · quarterly · on-demand). Extends{" "}
          <a className="text-[var(--color-accent)] hover:underline" href="/founder-quarterly-okrs">/founder-quarterly-okrs</a>{" "}
          (r1341 manual entry). Cron entrypoint:{" "}
          <code className="font-mono">founder_okr_v2_auto_compute_kickoff_due_runs()</code>.
        </p>
      </header>

      {s.due_now_count > 0 ? (
        <div className={`rounded-lg border ${dueTone} bg-[var(--color-surface)] p-4`}>
          <div className="text-[11px] uppercase tracking-wider text-[var(--color-warn)]">Due now</div>
          <div className="mt-1 text-sm">
            <span className="text-lg font-bold tabular-nums">{formatNumber(s.due_now_count)}</span>{" "}
            <span className="text-[var(--color-muted)]">
              active rules past their staleness threshold — kickoff cron not run or behind schedule.
            </span>
          </div>
        </div>
      ) : null}

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
        <Card label="Total rules"      value={formatNumber(s.total_rules ?? 0)} />
        <Card label="Active"           value={formatNumber(s.active_count ?? 0)} />
        <Card label="Inactive"         value={formatNumber(s.inactive_count ?? 0)} />
        <Card label="Due now"          value={formatNumber(s.due_now_count ?? 0)} tone={dueTone} />
        <Card label="Hourly"           value={formatNumber(s.hourly_count ?? 0)} />
        <Card label="Daily"            value={formatNumber(s.daily_count ?? 0)} />
        <Card label="Weekly"           value={formatNumber(s.weekly_count ?? 0)} />
        <Card label="Monthly"          value={formatNumber(s.monthly_count ?? 0)} />
        <Card label="Quarterly"        value={formatNumber(s.quarterly_count ?? 0)} />
        <Card label="On-demand"        value={formatNumber(s.on_demand_count ?? 0)} />
        <Card label="KRs · auto"       value={formatNumber(s.total_krs_with_auto ?? 0)} />
        <Card label="KRs · manual"     value={formatNumber(s.total_krs_without_auto ?? 0)} />
        <Card label="Avg progress · auto"   value={`${formatNumber(Math.round(s.kr_avg_progress_pct_with_auto ?? 0))}%`}    tone={liftTone} sub="weighted avg, KRs with auto-compute"/>
        <Card label="Avg progress · manual" value={`${formatNumber(Math.round(s.kr_avg_progress_pct_without_auto ?? 0))}%`} sub="weighted avg, KRs without auto-compute"/>
      </section>

      <section>
        <div className="mb-2 text-sm font-semibold">Due now · {due.length} rule{due.length === 1 ? "" : "s"}</div>
        {due.length === 0 ? (
          <p className="text-xs text-[var(--color-muted)]">All caught up · no rules past staleness threshold.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-[var(--color-muted)] uppercase tracking-wider text-[10px]">
                <tr className="text-left">
                  <th className="py-2 pr-3">KR</th>
                  <th className="py-2 pr-3">Objective</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Source</th>
                  <th className="py-2 pr-3">Freq</th>
                  <th className="py-2 pr-3">Last run</th>
                </tr>
              </thead>
              <tbody>
                {due.map((d) => (
                  <tr key={d.id} className="border-t border-[var(--color-border)] align-top">
                    <td className="py-2 pr-3 font-medium">{d.kr_title}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{d.objective_title}</td>
                    <td className="py-2 pr-3">
                      <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${KIND_BADGE[d.source_kind] ?? "border-[var(--color-border)]"}`}>
                        {d.source_kind}
                      </span>
                    </td>
                    <td className="py-2 pr-3 font-mono text-[11px]">{d.source_descriptor}</td>
                    <td className={`py-2 pr-3 ${FREQ_TONE[d.compute_frequency] ?? ""}`}>{d.compute_frequency}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{fmtAge(d.last_computed_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <div className="mb-2 text-sm font-semibold">Rules ledger · {rules.length}</div>
        {rules.length === 0 ? (
          <p className="text-xs text-[var(--color-muted)]">
            No auto-compute rules yet. Register one via{" "}
            <code className="font-mono">log_founder_okr_v2_register_rule(key_result_id, source_kind, source_descriptor, compute_frequency)</code>.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-[var(--color-muted)] uppercase tracking-wider text-[10px]">
                <tr className="text-left">
                  <th className="py-2 pr-3">KR</th>
                  <th className="py-2 pr-3">Objective · Qtr</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Source</th>
                  <th className="py-2 pr-3">Freq</th>
                  <th className="py-2 pr-3 text-right">Current</th>
                  <th className="py-2 pr-3 text-right">Target</th>
                  <th className="py-2 pr-3 text-right">Progress</th>
                  <th className="py-2 pr-3">Last run</th>
                  <th className="py-2 pr-3">Status</th>
                </tr>
              </thead>
              <tbody>
                {rules.map((r) => (
                  <tr key={r.id} className="border-t border-[var(--color-border)] align-top">
                    <td className="py-2 pr-3 font-medium">{r.kr_title}</td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">
                      {r.objective_title} · <code className="font-mono">{r.quarter_label}</code>
                    </td>
                    <td className="py-2 pr-3">
                      <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${KIND_BADGE[r.source_kind] ?? "border-[var(--color-border)]"}`}>
                        {r.source_kind}
                      </span>
                    </td>
                    <td className="py-2 pr-3 font-mono text-[11px] max-w-[28ch] truncate" title={r.source_descriptor}>
                      {r.source_descriptor}
                    </td>
                    <td className={`py-2 pr-3 ${FREQ_TONE[r.compute_frequency] ?? ""}`}>{r.compute_frequency}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">
                      {r.current_value != null ? formatNumber(Number(r.current_value)) : "—"}
                    </td>
                    <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-muted)]">
                      {r.target_value != null ? formatNumber(Number(r.target_value)) : "—"}
                    </td>
                    <td className={`py-2 pr-3 text-right tabular-nums font-semibold ${progressTone(Number(r.progress_pct ?? 0))}`}>
                      {formatNumber(Math.round(Number(r.progress_pct ?? 0)))}%
                    </td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{fmtAge(r.last_computed_at)}</td>
                    <td className="py-2 pr-3">
                      {!r.is_active ? (
                        <span className="text-[var(--color-muted)]">inactive</span>
                      ) : r.is_due ? (
                        <span className="text-[var(--color-warn)]">due</span>
                      ) : (
                        <span className="text-[var(--color-ok)]">fresh</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <footer className="text-[10px] text-[var(--color-muted)]">
        Generated {s.generated_at ? new Date(s.generated_at).toISOString() : "—"} · last cron run{" "}
        {s.last_run_at ? new Date(s.last_run_at).toISOString() : "never"} · founder-only · r1416
      </footer>
    </div>
  );
}
