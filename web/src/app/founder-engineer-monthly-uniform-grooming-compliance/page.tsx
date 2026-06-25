import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_inspections: number;
  exemplary_count: number;
  pass_count: number;
  warning_count: number;
  fail_count: number;
  avg_overall: number | null;
  open_violations: number;
};

type Inspection = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  region: string;
  inspection_date: string;
  inspector_name: string;
  uniform_score: number;
  grooming_score: number;
  overall_score: number;
  outcome: string;
  notes: string | null;
};

type Violation = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  category: string;
  severity: string;
  description: string;
  corrective_action: string;
  resolved: boolean;
  resolved_at: string | null;
};

type RegionRow = {
  region: string;
  inspections: number;
  avg_uniform: number | null;
  avg_grooming: number | null;
  avg_overall: number | null;
  fail_count: number;
};

type CatSevRow = {
  category: string;
  severity: string;
  total: number;
  open_count: number;
};

type OffenderRow = {
  engineer_code: string;
  engineer_name: string;
  region: string;
  inspections: number;
  avg_overall: number | null;
  violation_count: number;
  open_count: number;
};

type CorrectiveRow = {
  status: string;
  total: number;
  pct: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overviewRes, inspectionsRes, violationsRes, regionRes, catSevRes, offendersRes, correctiveRes] =
    await Promise.all([
      supabase.rpc('founder_ugc_overview_r2718'),
      supabase.rpc('founder_ugc_inspections_r2718'),
      supabase.rpc('founder_ugc_violations_r2718'),
      supabase.rpc('founder_ugc_region_breakdown_r2718'),
      supabase.rpc('founder_ugc_category_severity_r2718'),
      supabase.rpc('founder_ugc_top_offenders_r2718'),
      supabase.rpc('founder_ugc_corrective_status_r2718'),
    ]);

  const overview: Overview | null = (overviewRes.data?.[0] as Overview) ?? null;
  const inspections: Inspection[] = (inspectionsRes.data as Inspection[]) ?? [];
  const violations: Violation[] = (violationsRes.data as Violation[]) ?? [];
  const regions: RegionRow[] = (regionRes.data as RegionRow[]) ?? [];
  const catSev: CatSevRow[] = (catSevRes.data as CatSevRow[]) ?? [];
  const offenders: OffenderRow[] = (offendersRes.data as OffenderRow[]) ?? [];
  const corrective: CorrectiveRow[] = (correctiveRes.data as CorrectiveRow[]) ?? [];

  const kpis = [
    { label: 'Total Inspections', value: overview?.total_inspections ?? 0 },
    { label: 'Exemplary', value: overview?.exemplary_count ?? 0 },
    { label: 'Pass', value: overview?.pass_count ?? 0 },
    { label: 'Warning', value: overview?.warning_count ?? 0 },
    { label: 'Fail', value: overview?.fail_count ?? 0 },
    { label: 'Avg Overall Score', value: overview?.avg_overall ?? 0 },
    { label: 'Open Violations', value: overview?.open_violations ?? 0 },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700 }}>
          Engineer Monthly Uniform & Grooming Compliance
        </h1>
        <p style={{ color: '#6b7280', marginTop: '8px' }}>
          Round r2718 · engineer × inspection × score × violation × corrective × outcome.
          Overall scores &gt;=90 are exemplary; &lt;60 fail.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))',
          gap: '12px',
          marginBottom: '32px',
        }}
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            style={{
              padding: '16px',
              border: '1px solid #e5e7eb',
              borderRadius: '12px',
              background: '#ffffff',
            }}
          >
            <div style={{ fontSize: '12px', color: '#6b7280', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: '24px', fontWeight: 700, marginTop: '6px' }}>{String(k.value)}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Corrective Action Status</h2>
        <DataTable
          rows={corrective}
          columns={[
            { key: 'status', header: 'Status', render: (r: CorrectiveRow) => r.status },
            { key: 'total', header: 'Total', render: (r: CorrectiveRow) => String(r.total) },
            { key: 'pct', header: 'Share %', render: (r: CorrectiveRow) => (r.pct ?? 0) + '%' },
          ]}
          emptyMessage="No data"
          rowKey={(r: CorrectiveRow, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Region Breakdown</h2>
        <DataTable
          rows={regions}
          columns={[
            { key: 'region', header: 'Region', render: (r: RegionRow) => r.region },
            { key: 'inspections', header: 'Inspections', render: (r: RegionRow) => String(r.inspections) },
            { key: 'avg_uniform', header: 'Avg Uniform', render: (r: RegionRow) => String(r.avg_uniform ?? '-') },
            { key: 'avg_grooming', header: 'Avg Grooming', render: (r: RegionRow) => String(r.avg_grooming ?? '-') },
            { key: 'avg_overall', header: 'Avg Overall', render: (r: RegionRow) => String(r.avg_overall ?? '-') },
            { key: 'fail_count', header: 'Fails', render: (r: RegionRow) => String(r.fail_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RegionRow, i: number) => String(r.region ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Category & Severity Heatmap</h2>
        <DataTable
          rows={catSev}
          columns={[
            { key: 'category', header: 'Category', render: (r: CatSevRow) => r.category },
            { key: 'severity', header: 'Severity', render: (r: CatSevRow) => r.severity },
            { key: 'total', header: 'Total', render: (r: CatSevRow) => String(r.total) },
            { key: 'open_count', header: 'Open', render: (r: CatSevRow) => String(r.open_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CatSevRow, i: number) => r.category + '-' + r.severity + '-' + i}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Top Offenders (lowest avg overall first)
        </h2>
        <DataTable
          rows={offenders}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: OffenderRow) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: OffenderRow) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r: OffenderRow) => r.region },
            { key: 'inspections', header: 'Inspections', render: (r: OffenderRow) => String(r.inspections) },
            { key: 'avg_overall', header: 'Avg Overall', render: (r: OffenderRow) => String(r.avg_overall ?? '-') },
            { key: 'violation_count', header: 'Violations', render: (r: OffenderRow) => String(r.violation_count) },
            { key: 'open_count', header: 'Open', render: (r: OffenderRow) => String(r.open_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OffenderRow, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Inspections Log</h2>
        <DataTable
          rows={inspections}
          columns={[
            { key: 'inspection_date', header: 'Date', render: (r: Inspection) => r.inspection_date },
            { key: 'engineer_code', header: 'Code', render: (r: Inspection) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Inspection) => r.engineer_name },
            { key: 'region', header: 'Region', render: (r: Inspection) => r.region },
            { key: 'inspector_name', header: 'Inspector', render: (r: Inspection) => r.inspector_name },
            { key: 'uniform_score', header: 'Uniform', render: (r: Inspection) => String(r.uniform_score) },
            { key: 'grooming_score', header: 'Grooming', render: (r: Inspection) => String(r.grooming_score) },
            { key: 'overall_score', header: 'Overall', render: (r: Inspection) => String(r.overall_score) },
            { key: 'outcome', header: 'Outcome', render: (r: Inspection) => r.outcome },
            { key: 'notes', header: 'Notes', render: (r: Inspection) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Inspection, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Violations & Corrective Actions</h2>
        <DataTable
          rows={violations}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: Violation) => r.engineer_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: Violation) => r.engineer_name },
            { key: 'category', header: 'Category', render: (r: Violation) => r.category },
            { key: 'severity', header: 'Severity', render: (r: Violation) => r.severity },
            { key: 'description', header: 'Description', render: (r: Violation) => r.description },
            { key: 'corrective_action', header: 'Corrective Action', render: (r: Violation) => r.corrective_action },
            { key: 'resolved', header: 'Resolved', render: (r: Violation) => (r.resolved ? 'yes' : 'no') },
            { key: 'resolved_at', header: 'Resolved At', render: (r: Violation) => r.resolved_at ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r: Violation, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
