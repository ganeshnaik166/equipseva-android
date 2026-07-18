import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type MatrixRow = {
  id: string;
  engineer_user_id: string;
  skill_name: string;
  skill_category: string;
  proficiency_level: string;
  shadow_jobs_done: number;
  certified: boolean;
  certification_date: string | null;
  certification_authority: string | null;
  last_used_at: string | null;
  notes: string | null;
};

type CoverageRow = {
  id: string;
  skill_name: string;
  primary_engineer_user_id: string;
  backup_engineer_user_id: string | null;
  coverage_strength: string;
  gap_kind: string;
  action_required: boolean;
  action_owner_email: string | null;
  action_due_at: string | null;
  status: string;
  notes: string | null;
};

type RiskRow = {
  id: string;
  skill_name: string;
  primary_engineer_user_id: string;
  gap_kind: string;
  coverage_strength: string;
  action_due_at: string | null;
  status: string;
  notes: string | null;
};

type PipelineRow = {
  id: string;
  engineer_user_id: string;
  skill_name: string;
  skill_category: string;
  proficiency_level: string;
  shadow_jobs_done: number;
  cert_ready: boolean;
  notes: string | null;
};

type GapRow = {
  skill_name: string;
  certified_count: number;
  total_engineers: number;
  weak_coverage_count: number;
  no_backup_count: number;
};

type SummaryRow = {
  engineer_user_id: string;
  total_skills: number;
  certified_skills: number;
  expert_skills: number;
  beginner_skills: number;
  total_shadow_jobs: number;
};

type TrendRow = {
  week_start: string;
  certifications_earned: number;
  cumulative_certifications: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [matrixRes, coverageRes, risksRes, pipelineRes, gapsRes, summaryRes, trendRes] = await Promise.all([
    sb.rpc('list_matrix_r2470'),
    sb.rpc('list_coverage_r2470'),
    sb.rpc('single_point_risks_r2470'),
    sb.rpc('certification_pipeline_r2470'),
    sb.rpc('top_skill_gaps_r2470'),
    sb.rpc('engineer_coverage_summary_r2470'),
    sb.rpc('weekly_certification_trend_r2470'),
  ]);

  const matrix: MatrixRow[] = (matrixRes.data as MatrixRow[] | null) ?? [];
  const coverage: CoverageRow[] = (coverageRes.data as CoverageRow[] | null) ?? [];
  const risks: RiskRow[] = (risksRes.data as RiskRow[] | null) ?? [];
  const pipeline: PipelineRow[] = (pipelineRes.data as PipelineRow[] | null) ?? [];
  const gaps: GapRow[] = (gapsRes.data as GapRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const trend: TrendRow[] = (trendRes.data as TrendRow[] | null) ?? [];

  const matrixCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category },
    { key: 'proficiency_level', header: 'Proficiency', render: (r: any) => r.proficiency_level },
    { key: 'shadow_jobs_done', header: 'Shadow jobs', render: (r: any) => r.shadow_jobs_done },
    { key: 'certified', header: 'Certified', render: (r: any) => (r.certified ? 'yes' : 'no') },
    { key: 'certification_authority', header: 'Authority', render: (r: any) => r.certification_authority ?? '—' },
    { key: 'last_used_at', header: 'Last used', render: (r: any) => (r.last_used_at ? String(r.last_used_at).slice(0, 10) : '—') },
  ];

  const coverageCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'primary_engineer_user_id', header: 'Primary', render: (r: any) => String(r.primary_engineer_user_id).slice(0, 8) },
    { key: 'backup_engineer_user_id', header: 'Backup', render: (r: any) => (r.backup_engineer_user_id ? String(r.backup_engineer_user_id).slice(0, 8) : '—') },
    { key: 'coverage_strength', header: 'Strength', render: (r: any) => r.coverage_strength },
    { key: 'gap_kind', header: 'Gap', render: (r: any) => r.gap_kind },
    { key: 'action_required', header: 'Action?', render: (r: any) => (r.action_required ? 'yes' : 'no') },
    { key: 'action_due_at', header: 'Due', render: (r: any) => (r.action_due_at ? String(r.action_due_at).slice(0, 10) : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const riskCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'primary_engineer_user_id', header: 'Primary', render: (r: any) => String(r.primary_engineer_user_id).slice(0, 8) },
    { key: 'gap_kind', header: 'Gap kind', render: (r: any) => r.gap_kind },
    { key: 'coverage_strength', header: 'Strength', render: (r: any) => r.coverage_strength },
    { key: 'action_due_at', header: 'Due', render: (r: any) => (r.action_due_at ? String(r.action_due_at).slice(0, 10) : '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'skill_category', header: 'Category', render: (r: any) => r.skill_category },
    { key: 'proficiency_level', header: 'Proficiency', render: (r: any) => r.proficiency_level },
    { key: 'shadow_jobs_done', header: 'Shadow jobs', render: (r: any) => r.shadow_jobs_done },
    { key: 'cert_ready', header: 'Cert ready?', render: (r: any) => (r.cert_ready ? 'yes' : 'no') },
  ];

  const gapsCols: Column<any>[] = [
    { key: 'skill_name', header: 'Skill', render: (r: any) => r.skill_name },
    { key: 'certified_count', header: 'Certified', render: (r: any) => r.certified_count },
    { key: 'total_engineers', header: 'Total', render: (r: any) => r.total_engineers },
    { key: 'weak_coverage_count', header: 'Weak coverage', render: (r: any) => r.weak_coverage_count },
    { key: 'no_backup_count', header: 'No backup', render: (r: any) => r.no_backup_count },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id).slice(0, 8) },
    { key: 'total_skills', header: 'Total skills', render: (r: any) => r.total_skills },
    { key: 'certified_skills', header: 'Certified', render: (r: any) => r.certified_skills },
    { key: 'expert_skills', header: 'Expert', render: (r: any) => r.expert_skills },
    { key: 'beginner_skills', header: 'Beginner', render: (r: any) => r.beginner_skills },
    { key: 'total_shadow_jobs', header: 'Shadow jobs', render: (r: any) => r.total_shadow_jobs },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => String(r.week_start).slice(0, 10) },
    { key: 'certifications_earned', header: 'Earned', render: (r: any) => r.certifications_earned },
    { key: 'cumulative_certifications', header: 'Cumulative', render: (r: any) => r.cumulative_certifications },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Cross-Training Matrix</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Skill × engineer × proficiency level × shadow-jobs done × certified, plus backup-engineer coverage and single-point-of-failure risks.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Skill matrix ({matrix.length})</h2>
        <DataTable
          rows={matrix}
          columns={matrixCols}
          emptyMessage="No skill rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Backup coverage ({coverage.length})</h2>
        <DataTable
          rows={coverage}
          columns={coverageCols}
          emptyMessage="No coverage rows yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Single-point risks ({risks.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Open or in-progress gaps where gap_kind is no_backup, single_point, or weak_backup.
        </p>
        <DataTable
          rows={risks}
          columns={riskCols}
          emptyMessage="No open risks."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Certification pipeline ({pipeline.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Engineers not-yet-certified on a skill. cert_ready = yes when shadow_jobs &gt;= 5 and proficiency &gt;= intermediate.
        </p>
        <DataTable
          rows={pipeline}
          columns={pipelineCols}
          emptyMessage="Nothing in pipeline."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top skill gaps ({gaps.length})</h2>
        <DataTable
          rows={gaps}
          columns={gapsCols}
          emptyMessage="No skills yet."
          rowKey={(r: any, i: number) => String(r.skill_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Engineer summary ({summary.length})</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          emptyMessage="No engineers yet."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Weekly certification trend ({trend.length})</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No certifications recorded."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>
    </div>
  );
}
