import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SessionRow = {
  id: string;
  chain_code: string;
  chain_name: string;
  session_month: string;
  session_title: string;
  modality: string;
  clinicians_invited: number;
  clinicians_attended: number;
  clinicians_certified: number;
  attendance_pct: number;
  certification_pct: number;
  outcome_score: number;
  outcome_status: string;
};

type OutcomeRow = {
  outcome_id: string;
  chain_code: string;
  outcome_metric: string;
  baseline_value: number;
  post_training_value: number;
  delta_percent: number;
  improvement_grade: string;
  follow_up_required: boolean;
};

type ModalityRow = {
  modality: string;
  sessions_count: number;
  avg_attendance_pct: number;
  avg_certification_pct: number;
  avg_outcome_score: number;
};

type FollowupRow = {
  chain_code: string;
  chain_name: string;
  outcome_metric: string;
  improvement_grade: string;
  delta_percent: number;
  outcome_status: string;
};

type TopRow = {
  chain_code: string;
  chain_name: string;
  session_title: string;
  attendance_pct: number;
  certification_pct: number;
  outcome_score: number;
};

type GradeRow = {
  improvement_grade: string;
  outcomes_count: number;
  avg_delta_percent: number;
};

type Kpis = {
  total_chains: number;
  total_invited: number;
  total_attended: number;
  total_certified: number;
  avg_attendance_pct: number;
  avg_certification_pct: number;
  avg_outcome_score: number;
  critical_chains: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [sessions, kpis, outcomes, modality, followups, top, grades] = await Promise.all([
    supabase.rpc('founder_chain_training_sessions_r2763'),
    supabase.rpc('founder_chain_training_kpis_r2763'),
    supabase.rpc('founder_chain_training_outcomes_r2763'),
    supabase.rpc('founder_chain_training_modality_breakdown_r2763'),
    supabase.rpc('founder_chain_training_critical_followups_r2763'),
    supabase.rpc('founder_chain_training_top_performers_r2763'),
    supabase.rpc('founder_chain_training_grade_distribution_r2763'),
  ]);

  const sessionRows: SessionRow[] = (sessions.data as SessionRow[]) ?? [];
  const outcomeRows: OutcomeRow[] = (outcomes.data as OutcomeRow[]) ?? [];
  const modalityRows: ModalityRow[] = (modality.data as ModalityRow[]) ?? [];
  const followupRows: FollowupRow[] = (followups.data as FollowupRow[]) ?? [];
  const topRows: TopRow[] = (top.data as TopRow[]) ?? [];
  const gradeRows: GradeRow[] = (grades.data as GradeRow[]) ?? [];
  const kpi: Kpis | null = ((kpis.data as Kpis[]) ?? [])[0] ?? null;

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Monthly Clinician Training Attendance</h1>
        <p className="text-sm text-gray-500">
          Chain × session × clinicians invited &amp; attended &amp; certified &amp; outcome.
          Targets: attendance &gt;= 80%, certification &gt;= 75%, outcome score &gt;= 80.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <KpiCard label="Total Chains" value={kpi?.total_chains ?? 0} />
        <KpiCard label="Clinicians Invited" value={kpi?.total_invited ?? 0} />
        <KpiCard label="Clinicians Attended" value={kpi?.total_attended ?? 0} />
        <KpiCard label="Clinicians Certified" value={kpi?.total_certified ?? 0} />
        <KpiCard label="Avg Attendance %" value={kpi?.avg_attendance_pct ?? 0} />
        <KpiCard label="Avg Certification %" value={kpi?.avg_certification_pct ?? 0} />
        <KpiCard label="Avg Outcome Score" value={kpi?.avg_outcome_score ?? 0} />
        <KpiCard label="Critical Chains" value={kpi?.critical_chains ?? 0} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Training Sessions by Chain</h2>
        <DataTable
          rows={sessionRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: SessionRow) => r.chain_name },
            { key: 'session_month', header: 'Month', render: (r: SessionRow) => r.session_month },
            { key: 'session_title', header: 'Session', render: (r: SessionRow) => r.session_title },
            { key: 'modality', header: 'Modality', render: (r: SessionRow) => r.modality },
            { key: 'clinicians_invited', header: 'Invited', render: (r: SessionRow) => r.clinicians_invited },
            { key: 'clinicians_attended', header: 'Attended', render: (r: SessionRow) => r.clinicians_attended },
            { key: 'clinicians_certified', header: 'Certified', render: (r: SessionRow) => r.clinicians_certified },
            { key: 'attendance_pct', header: 'Attend %', render: (r: SessionRow) => `${r.attendance_pct}%` },
            { key: 'certification_pct', header: 'Cert %', render: (r: SessionRow) => `${r.certification_pct}%` },
            { key: 'outcome_score', header: 'Outcome', render: (r: SessionRow) => r.outcome_score },
            { key: 'outcome_status', header: 'Status', render: (r: SessionRow) => r.outcome_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: SessionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Training Outcomes (Baseline vs Post-Training)</h2>
        <DataTable
          rows={outcomeRows}
          columns={[
            { key: 'chain_code', header: 'Chain', render: (r: OutcomeRow) => r.chain_code },
            { key: 'outcome_metric', header: 'Metric', render: (r: OutcomeRow) => r.outcome_metric },
            { key: 'baseline_value', header: 'Baseline', render: (r: OutcomeRow) => r.baseline_value },
            { key: 'post_training_value', header: 'Post', render: (r: OutcomeRow) => r.post_training_value },
            { key: 'delta_percent', header: 'Delta %', render: (r: OutcomeRow) => `${r.delta_percent}%` },
            { key: 'improvement_grade', header: 'Grade', render: (r: OutcomeRow) => r.improvement_grade },
            { key: 'follow_up_required', header: 'Follow-up', render: (r: OutcomeRow) => (r.follow_up_required ? 'Yes' : 'No') },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Modality Breakdown</h2>
        <DataTable
          rows={modalityRows}
          columns={[
            { key: 'modality', header: 'Modality', render: (r: ModalityRow) => r.modality },
            { key: 'sessions_count', header: 'Sessions', render: (r: ModalityRow) => r.sessions_count },
            { key: 'avg_attendance_pct', header: 'Avg Attend %', render: (r: ModalityRow) => `${r.avg_attendance_pct}%` },
            { key: 'avg_certification_pct', header: 'Avg Cert %', render: (r: ModalityRow) => `${r.avg_certification_pct}%` },
            { key: 'avg_outcome_score', header: 'Avg Outcome', render: (r: ModalityRow) => r.avg_outcome_score },
          ]}
          emptyMessage="No data"
          rowKey={(r: ModalityRow, i: number) => String(r.modality ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Follow-ups</h2>
        <DataTable
          rows={followupRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: FollowupRow) => r.chain_name },
            { key: 'outcome_metric', header: 'Metric', render: (r: FollowupRow) => r.outcome_metric },
            { key: 'improvement_grade', header: 'Grade', render: (r: FollowupRow) => r.improvement_grade },
            { key: 'delta_percent', header: 'Delta %', render: (r: FollowupRow) => `${r.delta_percent}%` },
            { key: 'outcome_status', header: 'Status', render: (r: FollowupRow) => r.outcome_status },
          ]}
          emptyMessage="No data"
          rowKey={(r: FollowupRow, i: number) => String(`${r.chain_code}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Performing Sessions</h2>
        <DataTable
          rows={topRows}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: TopRow) => r.chain_name },
            { key: 'session_title', header: 'Session', render: (r: TopRow) => r.session_title },
            { key: 'attendance_pct', header: 'Attend %', render: (r: TopRow) => `${r.attendance_pct}%` },
            { key: 'certification_pct', header: 'Cert %', render: (r: TopRow) => `${r.certification_pct}%` },
            { key: 'outcome_score', header: 'Outcome', render: (r: TopRow) => r.outcome_score },
          ]}
          emptyMessage="No data"
          rowKey={(r: TopRow, i: number) => String(`${r.chain_code}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Improvement Grade Distribution</h2>
        <DataTable
          rows={gradeRows}
          columns={[
            { key: 'improvement_grade', header: 'Grade', render: (r: GradeRow) => r.improvement_grade },
            { key: 'outcomes_count', header: 'Count', render: (r: GradeRow) => r.outcomes_count },
            { key: 'avg_delta_percent', header: 'Avg Delta %', render: (r: GradeRow) => `${r.avg_delta_percent}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: GradeRow, i: number) => String(r.improvement_grade ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: number | string }) {
  return (
    <div className="rounded-lg border border-gray-200 p-4 bg-white">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="text-2xl font-semibold mt-1">{value}</div>
    </div>
  );
}
