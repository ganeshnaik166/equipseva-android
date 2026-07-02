import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_jobs: number;
  active_engineers: number;
  avg_prep_score: number;
  on_time_rate: number;
  bench_pass_rate: number;
  blocked_jobs: number;
  kit_full_pct: number;
  avg_eta_hours: number;
};

type StageRow = {
  prep_stage: string;
  job_count: number;
  share_pct: number;
  avg_score: number;
};

type LeaderRow = {
  engineer_code: string;
  engineer_name: string;
  engineer_tier: string;
  job_count: number;
  avg_score: number;
  bench_pass_rate: number;
  on_time_rate: number;
};

type VerdictRow = {
  verdict: string;
  job_count: number;
  share_pct: number;
};

type BlockedRow = {
  job_code: string;
  engineer_name: string;
  hospital_name: string;
  equipment_category: string;
  prep_stage: string;
  parts_required: number;
  parts_received: number;
  kit_completeness_pct: number;
  blocker_note: string | null;
};

type EventRow = {
  job_code: string;
  engineer_name: string;
  from_stage: string;
  to_stage: string;
  duration_hours: number;
  bench_check_passed: boolean;
  bench_check_score: number | null;
  event_at: string;
  note: string | null;
};

type EtaRow = {
  engineer_code: string;
  engineer_name: string;
  closed_jobs: number;
  avg_eta: number;
  avg_actual: number;
  variance_pct: number;
};

type JobRow = {
  job_code: string;
  engineer_name: string;
  engineer_tier: string;
  hospital_name: string;
  equipment_category: string;
  prep_stage: string;
  parts_required: number;
  parts_received: number;
  kit_completeness_pct: number;
  bench_test_passed: boolean;
  eta_hours: number;
  actual_hours: number | null;
  completion_verdict: string | null;
  prep_score: number;
};

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}%`;
}

function fmtNum(n: number | null | undefined, d = 2) {
  if (n === null || n === undefined) return '—';
  return Number(n).toFixed(d);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, stageRes, leaderRes, verdictRes, blockedRes, eventsRes, etaRes, jobsRes] = await Promise.all([
    supabase.rpc('founder_r2826_kpi_summary'),
    supabase.rpc('founder_r2826_stage_funnel'),
    supabase.rpc('founder_r2826_engineer_leaderboard'),
    supabase.rpc('founder_r2826_verdict_mix'),
    supabase.rpc('founder_r2826_blocked_jobs'),
    supabase.rpc('founder_r2826_recent_bench_events'),
    supabase.rpc('founder_r2826_eta_variance'),
    supabase.rpc('founder_r2826_job_list'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data as KpiRow[] | null)?.[0] ?? null;
  const stages: StageRow[] = (stageRes.data as StageRow[] | null) ?? [];
  const leaders: LeaderRow[] = (leaderRes.data as LeaderRow[] | null) ?? [];
  const verdicts: VerdictRow[] = (verdictRes.data as VerdictRow[] | null) ?? [];
  const blocked: BlockedRow[] = (blockedRes.data as BlockedRow[] | null) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[] | null) ?? [];
  const etas: EtaRow[] = (etaRes.data as EtaRow[] | null) ?? [];
  const jobs: JobRow[] = (jobsRes.data as JobRow[] | null) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Monthly Job Prep & Bench Stage</h1>
        <p className="text-sm text-gray-600">
          Engineer x job x prep stage x parts x kit x ETA x completion verdict. Round r2826.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total Jobs</div>
          <div className="text-2xl font-semibold">{kpi?.total_jobs ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Active Engineers</div>
          <div className="text-2xl font-semibold">{kpi?.active_engineers ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg Prep Score</div>
          <div className="text-2xl font-semibold">{fmtNum(kpi?.avg_prep_score)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">On-Time Rate</div>
          <div className="text-2xl font-semibold">{fmtPct(kpi?.on_time_rate)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Bench Pass Rate</div>
          <div className="text-2xl font-semibold">{fmtPct(kpi?.bench_pass_rate)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Blocked Jobs</div>
          <div className="text-2xl font-semibold">{kpi?.blocked_jobs ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Kit Full (kit &gt;= 100%)</div>
          <div className="text-2xl font-semibold">{fmtPct(kpi?.kit_full_pct)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Avg ETA (hours)</div>
          <div className="text-2xl font-semibold">{fmtNum(kpi?.avg_eta_hours)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Stage Funnel</h2>
        <DataTable
          rows={stages}
          rowKey={(r, i) => String((r as StageRow).prep_stage ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'prep_stage', header: 'Stage', render: (r: StageRow) => r.prep_stage },
            { key: 'job_count', header: 'Jobs', render: (r: StageRow) => r.job_count },
            { key: 'share_pct', header: 'Share', render: (r: StageRow) => fmtPct(r.share_pct) },
            { key: 'avg_score', header: 'Avg Score', render: (r: StageRow) => fmtNum(r.avg_score) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Engineer Leaderboard</h2>
        <DataTable
          rows={leaders}
          rowKey={(r, i) => String((r as LeaderRow).engineer_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: LeaderRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: LeaderRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: LeaderRow) => r.engineer_tier },
            { key: 'job_count', header: 'Jobs', render: (r: LeaderRow) => r.job_count },
            { key: 'avg_score', header: 'Avg Score', render: (r: LeaderRow) => fmtNum(r.avg_score) },
            { key: 'bench_pass_rate', header: 'Bench Pass', render: (r: LeaderRow) => fmtPct(r.bench_pass_rate) },
            { key: 'on_time_rate', header: 'On-Time', render: (r: LeaderRow) => fmtPct(r.on_time_rate) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Verdict Mix</h2>
        <DataTable
          rows={verdicts}
          rowKey={(r, i) => String((r as VerdictRow).verdict ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'verdict', header: 'Verdict', render: (r: VerdictRow) => r.verdict },
            { key: 'job_count', header: 'Jobs', render: (r: VerdictRow) => r.job_count },
            { key: 'share_pct', header: 'Share', render: (r: VerdictRow) => fmtPct(r.share_pct) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Blocked Jobs (kit &lt; 100% or has blocker)</h2>
        <DataTable
          rows={blocked}
          rowKey={(r, i) => String((r as BlockedRow).job_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_code', header: 'Job', render: (r: BlockedRow) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: BlockedRow) => r.engineer_name },
            { key: 'hospital_name', header: 'Hospital', render: (r: BlockedRow) => r.hospital_name },
            { key: 'equipment_category', header: 'Equipment', render: (r: BlockedRow) => r.equipment_category },
            { key: 'prep_stage', header: 'Stage', render: (r: BlockedRow) => r.prep_stage },
            { key: 'parts', header: 'Parts (recv/req)', render: (r: BlockedRow) => `${r.parts_received}/${r.parts_required}` },
            { key: 'kit_completeness_pct', header: 'Kit %', render: (r: BlockedRow) => fmtPct(r.kit_completeness_pct) },
            { key: 'blocker_note', header: 'Blocker', render: (r: BlockedRow) => r.blocker_note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">ETA vs Actual Variance</h2>
        <DataTable
          rows={etas}
          rowKey={(r, i) => String((r as EtaRow).engineer_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: EtaRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: EtaRow) => r.engineer_name },
            { key: 'closed_jobs', header: 'Closed Jobs', render: (r: EtaRow) => r.closed_jobs },
            { key: 'avg_eta', header: 'Avg ETA (h)', render: (r: EtaRow) => fmtNum(r.avg_eta) },
            { key: 'avg_actual', header: 'Avg Actual (h)', render: (r: EtaRow) => fmtNum(r.avg_actual) },
            { key: 'variance_pct', header: 'Variance', render: (r: EtaRow) => fmtPct(r.variance_pct) },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent Bench Stage Events</h2>
        <DataTable
          rows={events}
          rowKey={(r, i) => String(i)}
          emptyMessage="No data"
          columns={[
            { key: 'event_at', header: 'When', render: (r: EventRow) => new Date(r.event_at).toLocaleString() },
            { key: 'job_code', header: 'Job', render: (r: EventRow) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: EventRow) => r.engineer_name },
            { key: 'transition', header: 'Transition', render: (r: EventRow) => `${r.from_stage} => ${r.to_stage}` },
            { key: 'duration_hours', header: 'Hours', render: (r: EventRow) => fmtNum(r.duration_hours) },
            { key: 'bench_check_passed', header: 'Bench OK', render: (r: EventRow) => (r.bench_check_passed ? 'yes' : 'no') },
            { key: 'bench_check_score', header: 'Bench Score', render: (r: EventRow) => fmtNum(r.bench_check_score) },
            { key: 'note', header: 'Note', render: (r: EventRow) => r.note ?? '—' },
          ]}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">All Jobs (ranked by prep score)</h2>
        <DataTable
          rows={jobs}
          rowKey={(r, i) => String((r as JobRow).job_code ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'job_code', header: 'Job', render: (r: JobRow) => r.job_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: JobRow) => r.engineer_name },
            { key: 'engineer_tier', header: 'Tier', render: (r: JobRow) => r.engineer_tier },
            { key: 'hospital_name', header: 'Hospital', render: (r: JobRow) => r.hospital_name },
            { key: 'equipment_category', header: 'Equipment', render: (r: JobRow) => r.equipment_category },
            { key: 'prep_stage', header: 'Stage', render: (r: JobRow) => r.prep_stage },
            { key: 'parts', header: 'Parts (recv/req)', render: (r: JobRow) => `${r.parts_received}/${r.parts_required}` },
            { key: 'kit_completeness_pct', header: 'Kit %', render: (r: JobRow) => fmtPct(r.kit_completeness_pct) },
            { key: 'bench_test_passed', header: 'Bench OK', render: (r: JobRow) => (r.bench_test_passed ? 'yes' : 'no') },
            { key: 'eta_hours', header: 'ETA (h)', render: (r: JobRow) => fmtNum(r.eta_hours) },
            { key: 'actual_hours', header: 'Actual (h)', render: (r: JobRow) => fmtNum(r.actual_hours) },
            { key: 'completion_verdict', header: 'Verdict', render: (r: JobRow) => r.completion_verdict ?? 'pending' },
            { key: 'prep_score', header: 'Score', render: (r: JobRow) => fmtNum(r.prep_score) },
          ]}
        />
      </section>
    </div>
  );
}
