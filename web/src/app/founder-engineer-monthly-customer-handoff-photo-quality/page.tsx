import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_engineers: number;
  avg_composite: number;
  avg_clarity: number;
  avg_completeness: number;
  avg_annotation: number;
  total_redos: number;
};

type LeaderRow = {
  engineer_code: string;
  engineer_name: string;
  composite_score: number;
  grade: string;
  jobs_completed: number;
  redo_count: number;
};

type GradeRow = { grade: string; engineer_count: number; avg_score: number };

type RedoRow = {
  job_ref: string;
  engineer_code: string;
  hospital_name: string;
  failure_reason: string;
  severity: string;
  redo_status: string;
  flagged_at: string;
};

type FailureRow = { failure_reason: string; count: number; critical_count: number };

type LowRow = {
  engineer_code: string;
  engineer_name: string;
  composite_score: number;
  redo_count: number;
  grade: string;
};

type VelocityRow = {
  total_resolved: number;
  total_pending: number;
  total_escalated: number;
  avg_resolution_hours: number;
};

type DimRow = {
  engineer_code: string;
  engineer_name: string;
  clarity_score: number;
  completeness_score: number;
  annotation_score: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, leaderRes, gradeRes, redoRes, failRes, lowRes, velRes, dimRes] = await Promise.all([
    supabase.rpc('r2746_kpi_summary'),
    supabase.rpc('r2746_engineer_leaderboard'),
    supabase.rpc('r2746_grade_distribution'),
    supabase.rpc('r2746_redo_actions_open'),
    supabase.rpc('r2746_failure_reason_breakdown'),
    supabase.rpc('r2746_low_score_engineers'),
    supabase.rpc('r2746_resolution_velocity'),
    supabase.rpc('r2746_quality_dimensions'),
  ]);

  const kpi: KpiRow = (kpiRes.data?.[0] as KpiRow) ?? {
    total_engineers: 0,
    avg_composite: 0,
    avg_clarity: 0,
    avg_completeness: 0,
    avg_annotation: 0,
    total_redos: 0,
  };
  const velocity: VelocityRow = (velRes.data?.[0] as VelocityRow) ?? {
    total_resolved: 0,
    total_pending: 0,
    total_escalated: 0,
    avg_resolution_hours: 0,
  };
  const leaderboard: LeaderRow[] = (leaderRes.data as LeaderRow[]) ?? [];
  const grades: GradeRow[] = (gradeRes.data as GradeRow[]) ?? [];
  const redos: RedoRow[] = (redoRes.data as RedoRow[]) ?? [];
  const failures: FailureRow[] = (failRes.data as FailureRow[]) ?? [];
  const lows: LowRow[] = (lowRes.data as LowRow[]) ?? [];
  const dims: DimRow[] = (dimRes.data as DimRow[]) ?? [];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Engineer Monthly Customer Handoff — Photo Quality
      </h1>
      <p style={{ color: '#666', marginBottom: '1.5rem' }}>
        Photo clarity, completeness, annotation &amp; redo-action surface for monthly handoff QA. Flags engineers scoring &lt; 7.0 composite and tracks open redo tickets.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <KpiCard label="Engineers" value={String(kpi.total_engineers)} />
        <KpiCard label="Avg Composite" value={`${kpi.avg_composite ?? 0} / 10`} />
        <KpiCard label="Avg Clarity" value={`${kpi.avg_clarity ?? 0}`} />
        <KpiCard label="Avg Completeness" value={`${kpi.avg_completeness ?? 0}`} />
        <KpiCard label="Avg Annotation" value={`${kpi.avg_annotation ?? 0}`} />
        <KpiCard label="Total Redos" value={String(kpi.total_redos)} />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <KpiCard label="Resolved" value={String(velocity.total_resolved)} />
        <KpiCard label="Pending" value={String(velocity.total_pending)} />
        <KpiCard label="Escalated" value={String(velocity.total_escalated)} />
        <KpiCard label="Avg Resolution (hrs)" value={`${velocity.avg_resolution_hours ?? 0}`} />
      </section>

      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: '1.5rem 0 0.75rem' }}>Engineer Leaderboard</h2>
      <DataTable
        rows={leaderboard}
        rowKey={(r, i) => String((r as LeaderRow).engineer_code ?? i)}
        emptyMessage="No data"
        columns={[
          { key: 'engineer_code', header: 'Engineer', render: (r: LeaderRow) => r.engineer_code },
          { key: 'engineer_name', header: 'Name', render: (r: LeaderRow) => r.engineer_name },
          { key: 'composite_score', header: 'Composite', render: (r: LeaderRow) => r.composite_score },
          { key: 'grade', header: 'Grade', render: (r: LeaderRow) => r.grade },
          { key: 'jobs_completed', header: 'Jobs', render: (r: LeaderRow) => r.jobs_completed },
          { key: 'redo_count', header: 'Redos', render: (r: LeaderRow) => r.redo_count },
        ]}
      />

      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: '1.5rem 0 0.75rem' }}>Quality Dimensions</h2>
      <DataTable
        rows={dims}
        rowKey={(r, i) => String((r as DimRow).engineer_code ?? i)}
        emptyMessage="No data"
        columns={[
          { key: 'engineer_code', header: 'Engineer', render: (r: DimRow) => r.engineer_code },
          { key: 'engineer_name', header: 'Name', render: (r: DimRow) => r.engineer_name },
          { key: 'clarity_score', header: 'Clarity', render: (r: DimRow) => r.clarity_score },
          { key: 'completeness_score', header: 'Completeness', render: (r: DimRow) => r.completeness_score },
          { key: 'annotation_score', header: 'Annotation', render: (r: DimRow) => r.annotation_score },
        ]}
      />

      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: '1.5rem 0 0.75rem' }}>Grade Distribution</h2>
      <DataTable
        rows={grades}
        rowKey={(r, i) => String((r as GradeRow).grade ?? i)}
        emptyMessage="No data"
        columns={[
          { key: 'grade', header: 'Grade', render: (r: GradeRow) => r.grade },
          { key: 'engineer_count', header: 'Engineers', render: (r: GradeRow) => r.engineer_count },
          { key: 'avg_score', header: 'Avg Score', render: (r: GradeRow) => r.avg_score },
        ]}
      />

      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: '1.5rem 0 0.75rem' }}>
        Engineers Below Threshold (composite &lt; 7.0)
      </h2>
      <DataTable
        rows={lows}
        rowKey={(r, i) => String((r as LowRow).engineer_code ?? i)}
        emptyMessage="No data"
        columns={[
          { key: 'engineer_code', header: 'Engineer', render: (r: LowRow) => r.engineer_code },
          { key: 'engineer_name', header: 'Name', render: (r: LowRow) => r.engineer_name },
          { key: 'composite_score', header: 'Composite', render: (r: LowRow) => r.composite_score },
          { key: 'redo_count', header: 'Redos', render: (r: LowRow) => r.redo_count },
          { key: 'grade', header: 'Grade', render: (r: LowRow) => r.grade },
        ]}
      />

      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: '1.5rem 0 0.75rem' }}>Open Redo Actions</h2>
      <DataTable
        rows={redos}
        rowKey={(r, i) => String((r as RedoRow).job_ref ?? i)}
        emptyMessage="No data"
        columns={[
          { key: 'job_ref', header: 'Job', render: (r: RedoRow) => r.job_ref },
          { key: 'engineer_code', header: 'Engineer', render: (r: RedoRow) => r.engineer_code },
          { key: 'hospital_name', header: 'Hospital', render: (r: RedoRow) => r.hospital_name },
          { key: 'failure_reason', header: 'Reason', render: (r: RedoRow) => r.failure_reason },
          { key: 'severity', header: 'Severity', render: (r: RedoRow) => r.severity },
          { key: 'redo_status', header: 'Status', render: (r: RedoRow) => r.redo_status },
          { key: 'flagged_at', header: 'Flagged At', render: (r: RedoRow) => new Date(r.flagged_at).toLocaleString() },
        ]}
      />

      <h2 style={{ fontSize: '1.25rem', fontWeight: 600, margin: '1.5rem 0 0.75rem' }}>Failure Reason Breakdown</h2>
      <DataTable
        rows={failures}
        rowKey={(r, i) => String((r as FailureRow).failure_reason ?? i)}
        emptyMessage="No data"
        columns={[
          { key: 'failure_reason', header: 'Reason', render: (r: FailureRow) => r.failure_reason },
          { key: 'count', header: 'Count', render: (r: FailureRow) => r.count },
          { key: 'critical_count', header: 'Critical', render: (r: FailureRow) => r.critical_count },
        ]}
      />
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: '1rem', background: '#fff' }}>
      <div style={{ fontSize: '0.75rem', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{label}</div>
      <div style={{ fontSize: '1.5rem', fontWeight: 700, marginTop: '0.25rem' }}>{value}</div>
    </div>
  );
}
