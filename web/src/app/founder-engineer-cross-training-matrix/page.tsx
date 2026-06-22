import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [matrix, coverage, gaps, expiring, performers, pipeline, kpis] = await Promise.all([
    sb.rpc('get_engineer_cross_training_matrix_r2250'),
    sb.rpc('get_modality_coverage_summary_r2250'),
    sb.rpc('get_training_demand_gaps_r2250'),
    sb.rpc('get_expiring_certifications_r2250'),
    sb.rpc('get_high_performers_r2250'),
    sb.rpc('get_in_progress_pipeline_r2250'),
    sb.rpc('get_cross_training_kpis_r2250'),
  ]);

  const matrixRows = (matrix.data ?? []) as any[];
  const coverageRows = (coverage.data ?? []) as any[];
  const gapRows = (gaps.data ?? []) as any[];
  const expiringRows = (expiring.data ?? []) as any[];
  const performerRows = (performers.data ?? []) as any[];
  const pipelineRows = (pipeline.data ?? []) as any[];
  const kpi = (kpis.data?.[0] ?? {}) as any;

  const matrixCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'certified_count', header: 'Certified', render: (r: any) => r.certified_count },
    { key: 'in_progress_count', header: 'In progress', render: (r: any) => r.in_progress_count },
    { key: 'none_count', header: 'None', render: (r: any) => r.none_count },
    { key: 'coverage_pct', header: 'Coverage %', render: (r: any) => r.coverage_pct != null ? `${r.coverage_pct}%` : '-' },
    { key: 'avg_proficiency', header: 'Avg proficiency', render: (r: any) => r.avg_proficiency ?? '-' },
    { key: 'total_training_hours', header: 'Train hrs', render: (r: any) => r.total_training_hours ?? 0 },
  ];

  const coverageCols: Column<any>[] = [
    { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
    { key: 'certified_engineers', header: 'Certified', render: (r: any) => r.certified_engineers },
    { key: 'in_progress_engineers', header: 'In progress', render: (r: any) => r.in_progress_engineers },
    { key: 'total_engineers', header: 'Total', render: (r: any) => r.total_engineers },
    { key: 'avg_jobs_30d', header: 'Avg jobs 30d', render: (r: any) => r.avg_jobs_30d ?? 0 },
    { key: 'avg_proficiency', header: 'Avg proficiency', render: (r: any) => r.avg_proficiency ?? '-' },
    { key: 'expiring_within_90d', header: 'Expiring 90d', render: (r: any) => r.expiring_within_90d },
  ];

  const gapCols: Column<any>[] = [
    { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
    { key: 'region', header: 'Region', render: (r: any) => r.region },
    { key: 'open_jobs_30d', header: 'Open jobs 30d', render: (r: any) => r.open_jobs_30d },
    { key: 'certified_engineers_count', header: 'Certified eng', render: (r: any) => r.certified_engineers_count },
    { key: 'demand_supply_ratio', header: 'Demand/supply', render: (r: any) => r.demand_supply_ratio },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'recommended_action', header: 'Action', render: (r: any) => r.recommended_action ?? '-' },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
    { key: 'days_until_expiry', header: 'Days left', render: (r: any) => r.days_until_expiry },
    { key: 'expires_at', header: 'Expires', render: (r: any) => r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '-' },
    { key: 'proficiency_score', header: 'Proficiency', render: (r: any) => r.proficiency_score ?? '-' },
    { key: 'jobs_completed_30d', header: 'Jobs 30d', render: (r: any) => r.jobs_completed_30d },
  ];

  const performerCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'certified_modalities', header: 'Certs', render: (r: any) => r.certified_modalities },
    { key: 'avg_proficiency', header: 'Avg proficiency', render: (r: any) => r.avg_proficiency ?? '-' },
    { key: 'total_jobs_30d', header: 'Total jobs 30d', render: (r: any) => r.total_jobs_30d },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email },
    { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
    { key: 'training_hours_logged', header: 'Hours logged', render: (r: any) => r.training_hours_logged },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
    { key: 'updated_at', header: 'Updated', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleDateString() : '-' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer cross-training matrix</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Each engineer x equipment modality (CT, MRI, ventilator, monitor) certification status. Gap analysis flags high-demand modalities with thin supply.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 32 }}>
        <KpiCard label="Engineers tracked" value={kpi.total_engineers_tracked ?? 0} />
        <KpiCard label="Total certifications" value={kpi.total_certifications ?? 0} />
        <KpiCard label="In progress" value={kpi.total_in_progress ?? 0} />
        <KpiCard label="Avg modalities/eng" value={kpi.avg_modalities_per_engineer ?? 0} />
        <KpiCard label="Critical gap regions" value={kpi.critical_gap_regions ?? 0} />
        <KpiCard label="Expiring 90d" value={kpi.expiring_90d ?? 0} />
        <KpiCard label="Multi-modality eng" value={kpi.multi_modality_engineers ?? 0} />
      </div>

      <Section title="Engineer matrix">
        <DataTable columns={matrixCols} rows={matrixRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Modality coverage summary">
        <DataTable columns={coverageCols} rows={coverageRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Training demand gaps (critical first)">
        <DataTable columns={gapCols} rows={gapRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="Expiring certifications (next 180d)">
        <DataTable columns={expiringCols} rows={expiringRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="High performers (cert count >= 2)">
        <DataTable columns={performerCols} rows={performerRows} rowKey={(_, i) => String(i)} />
      </Section>

      <Section title="In-progress training pipeline">
        <DataTable columns={pipelineCols} rows={pipelineRows} rowKey={(_, i) => String(i)} />
      </Section>
    </div>
  );
}

function KpiCard({ label, value }: { label: string; value: any }) {
  return (
    <div style={{ background: '#fafafa', border: '1px solid #e5e5e5', borderRadius: 8, padding: 14 }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{String(value)}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 32 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>{title}</h2>
      {children}
    </section>
  );
}
