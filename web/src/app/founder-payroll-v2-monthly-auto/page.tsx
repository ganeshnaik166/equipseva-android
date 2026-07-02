import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  active_schedules: number;
  paused_schedules: number;
  monthly_schedules: number;
  weekly_schedules: number;
  biweekly_schedules: number;
  quarterly_schedules: number;
  custom_schedules: number;
  next_run_within_24h: number;
  next_run_within_7d: number;
  last_30d_success_runs: number;
  last_30d_failed_runs: number;
  last_30d_partial_runs: number;
  last_30d_total_disbursed: number;
  last_30d_total_batches: number;
};

type ScheduleRow = {
  id: string;
  schedule_label: string;
  frequency: string;
  day_of_period: number;
  next_run_at: string | null;
  last_run_at: string | null;
  last_run_outcome: string | null;
  last_run_batch_count: number | null;
  last_run_amount_rupees: number | null;
  is_active: boolean;
  notes: string | null;
  created_at: string;
};

type NextRun = {
  schedule_label: string;
  frequency: string;
  next_run_at: string;
  hours_until_run: number;
  is_active: boolean;
};

function fmtDate(iso: string | null) {
  if (!iso) return "—";
  try { return new Date(iso).toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" }); }
  catch { return iso; }
}

function outcomeColor(o: string | null) {
  if (o === "success")  return "bg-emerald-50 text-emerald-700 border-emerald-200";
  if (o === "failed")   return "bg-rose-50 text-rose-700 border-rose-200";
  if (o === "partial")  return "bg-amber-50 text-amber-700 border-amber-200";
  if (o === "running")  return "bg-sky-50 text-sky-700 border-sky-200";
  if (o === "pending")  return "bg-slate-50 text-slate-700 border-slate-200";
  if (o === "skipped")  return "bg-zinc-50 text-zinc-600 border-zinc-200";
  return "bg-white text-slate-500 border-slate-200";
}

function freqColor(f: string) {
  if (f === "monthly")   return "bg-indigo-50 text-indigo-700 border-indigo-200";
  if (f === "weekly")    return "bg-sky-50 text-sky-700 border-sky-200";
  if (f === "biweekly")  return "bg-cyan-50 text-cyan-700 border-cyan-200";
  if (f === "quarterly") return "bg-violet-50 text-violet-700 border-violet-200";
  return "bg-slate-50 text-slate-700 border-slate-200";
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: sumRows }, { data: schedRows }, { data: nextRows }] = await Promise.all([
    supabase.rpc("founder_payroll_v2_monthly_summary"),
    supabase.rpc("founder_payroll_v2_schedules_recent"),
    supabase.rpc("founder_payroll_v2_next_runs"),
  ]);

  const s: Summary = (sumRows?.[0] ?? {}) as Summary;
  const schedules: ScheduleRow[] = (schedRows ?? []) as ScheduleRow[];
  const upcoming: NextRun[] = (nextRows ?? []) as NextRun[];

  const cards: { label: string; value: string; tone: string }[] = [
    { label: "Active schedules",         value: formatNumber(s.active_schedules ?? 0),                   tone: "text-emerald-700" },
    { label: "Paused schedules",         value: formatNumber(s.paused_schedules ?? 0),                   tone: "text-zinc-600" },
    { label: "Monthly cadence",          value: formatNumber(s.monthly_schedules ?? 0),                  tone: "text-indigo-700" },
    { label: "Weekly cadence",           value: formatNumber(s.weekly_schedules ?? 0),                   tone: "text-sky-700" },
    { label: "Biweekly cadence",         value: formatNumber(s.biweekly_schedules ?? 0),                 tone: "text-cyan-700" },
    { label: "Quarterly cadence",        value: formatNumber(s.quarterly_schedules ?? 0),                tone: "text-violet-700" },
    { label: "Custom cadence",           value: formatNumber(s.custom_schedules ?? 0),                   tone: "text-slate-700" },
    { label: "Runs due in 24h",          value: formatNumber(s.next_run_within_24h ?? 0),                tone: "text-amber-700" },
    { label: "Runs due in 7d",           value: formatNumber(s.next_run_within_7d ?? 0),                 tone: "text-orange-700" },
    { label: "30d success runs",         value: formatNumber(s.last_30d_success_runs ?? 0),              tone: "text-emerald-700" },
    { label: "30d failed runs",          value: formatNumber(s.last_30d_failed_runs ?? 0),               tone: "text-rose-700" },
    { label: "30d partial runs",         value: formatNumber(s.last_30d_partial_runs ?? 0),              tone: "text-amber-700" },
    { label: "30d total disbursed",      value: "Rs " + formatNumber(Number(s.last_30d_total_disbursed ?? 0)), tone: "text-emerald-800" },
    { label: "30d total batches",        value: formatNumber(s.last_30d_total_batches ?? 0),             tone: "text-indigo-700" },
  ];

  return (
    <main className="p-6 space-y-6 max-w-[1280px] mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Founder Payroll v2 — Monthly Auto-Disburse</h1>
        <p className="text-sm text-slate-500">
          Cron-driven payroll scheduler. Extends r1325 batches with per-engineer cadence
          (weekly / biweekly / monthly / quarterly / custom). pg_cron hits
          <code className="mx-1 px-1 bg-slate-100 rounded">payroll_v2_kickoff_scheduled_run()</code>
          which fires due schedules and forecasts the next run.
        </p>
      </header>

      {/* Next-N runs banner */}
      <section className="rounded-xl border border-amber-200 bg-amber-50/40 p-4">
        <div className="flex items-baseline justify-between mb-2">
          <h2 className="text-sm font-semibold text-amber-900">Upcoming runs (next 10)</h2>
          <span className="text-xs text-amber-700">{upcoming.length} scheduled</span>
        </div>
        {upcoming.length === 0 ? (
          <p className="text-sm text-amber-800/70 italic">No upcoming runs scheduled.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-amber-900/70">
                <tr className="text-left">
                  <th className="py-1 pr-3 font-medium">Label</th>
                  <th className="py-1 pr-3 font-medium">Cadence</th>
                  <th className="py-1 pr-3 font-medium">Next run</th>
                  <th className="py-1 pr-3 font-medium text-right">Hrs until</th>
                </tr>
              </thead>
              <tbody>
                {upcoming.map((r, i) => (
                  <tr key={i} className="border-t border-amber-100">
                    <td className="py-1.5 pr-3 font-medium text-amber-950">{r.schedule_label}</td>
                    <td className="py-1.5 pr-3">
                      <span className={`inline-flex px-2 py-0.5 rounded border text-[10px] ${freqColor(r.frequency)}`}>
                        {r.frequency}
                      </span>
                    </td>
                    <td className="py-1.5 pr-3 text-amber-900">{fmtDate(r.next_run_at)}</td>
                    <td className="py-1.5 pr-3 text-right tabular-nums text-amber-900">{r.hours_until_run}h</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {/* 14 KPI cards */}
      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-7 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-slate-200 bg-white p-3">
            <div className="text-[11px] uppercase tracking-wide text-slate-500">{c.label}</div>
            <div className={`mt-1 text-lg font-semibold tabular-nums ${c.tone}`}>{c.value}</div>
          </div>
        ))}
      </section>

      {/* 20-row schedule ledger */}
      <section className="rounded-xl border border-slate-200 bg-white">
        <div className="flex items-baseline justify-between px-4 py-3 border-b border-slate-200">
          <h2 className="text-sm font-semibold text-slate-900">Schedule ledger (last 20)</h2>
          <span className="text-xs text-slate-500">{schedules.length} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="bg-slate-50 text-slate-600">
              <tr className="text-left">
                <th className="px-3 py-2 font-medium">Label</th>
                <th className="px-3 py-2 font-medium">Cadence</th>
                <th className="px-3 py-2 font-medium text-right">Day</th>
                <th className="px-3 py-2 font-medium">Next run</th>
                <th className="px-3 py-2 font-medium">Last run</th>
                <th className="px-3 py-2 font-medium">Outcome</th>
                <th className="px-3 py-2 font-medium text-right">Batches</th>
                <th className="px-3 py-2 font-medium text-right">Amount (Rs)</th>
                <th className="px-3 py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {schedules.length === 0 ? (
                <tr><td colSpan={9} className="px-3 py-6 text-center text-slate-400 italic">No schedules registered yet.</td></tr>
              ) : schedules.map((r) => (
                <tr key={r.id} className="border-t border-slate-100 hover:bg-slate-50/60">
                  <td className="px-3 py-2 font-medium text-slate-900">{r.schedule_label}</td>
                  <td className="px-3 py-2">
                    <span className={`inline-flex px-2 py-0.5 rounded border text-[10px] ${freqColor(r.frequency)}`}>
                      {r.frequency}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-700">{r.day_of_period}</td>
                  <td className="px-3 py-2 text-slate-700">{fmtDate(r.next_run_at)}</td>
                  <td className="px-3 py-2 text-slate-500">{fmtDate(r.last_run_at)}</td>
                  <td className="px-3 py-2">
                    <span className={`inline-flex px-2 py-0.5 rounded border text-[10px] ${outcomeColor(r.last_run_outcome)}`}>
                      {r.last_run_outcome ?? "—"}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-slate-700">
                    {r.last_run_batch_count != null ? formatNumber(r.last_run_batch_count) : "—"}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums text-emerald-800">
                    {r.last_run_amount_rupees != null ? formatNumber(Number(r.last_run_amount_rupees)) : "—"}
                  </td>
                  <td className="px-3 py-2">
                    {r.is_active
                      ? <span className="inline-flex px-2 py-0.5 rounded border text-[10px] bg-emerald-50 text-emerald-700 border-emerald-200">active</span>
                      : <span className="inline-flex px-2 py-0.5 rounded border text-[10px] bg-zinc-100 text-zinc-600 border-zinc-200">paused</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <footer className="text-[11px] text-slate-400 pt-2 border-t border-slate-100">
        r1409 · founder-only · cron kickoff via <code>payroll_v2_kickoff_scheduled_run()</code> ·
        extends r1325 batches with per-engineer cadence
      </footer>
    </main>
  );
}
