import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(1) + '%';
}

function fmtRatio(n: any): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return (v * 100).toFixed(1) + '%';
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function FounderEngineerSkillsGraphPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let byEngineer: any[] = [];
  let gaps: any[] = [];
  let bottlenecks: any[] = [];
  let distribution: any[] = [];
  let recent: any[] = [];

  try {
    const r = await sb.rpc('founder_skill_matrix_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch (_e) { kpis = {}; }

  try {
    const r = await sb.rpc('founder_skill_matrix_by_engineer', { p_limit: 100 });
    byEngineer = r.data || [];
  } catch (_e) { byEngineer = []; }

  try {
    const r = await sb.rpc('founder_skill_fleet_coverage_gaps', { p_limit: 50 });
    gaps = r.data || [];
  } catch (_e) { gaps = []; }

  try {
    const r = await sb.rpc('founder_skill_bottlenecks', { p_limit: 25 });
    bottlenecks = r.data || [];
  } catch (_e) { bottlenecks = []; }

  try {
    const r = await sb.rpc('founder_skill_proficiency_distribution');
    distribution = r.data || [];
  } catch (_e) { distribution = []; }

  try {
    const r = await sb.rpc('founder_skill_recent_assessments', { p_limit: 50 });
    recent = r.data || [];
  } catch (_e) { recent = []; }

  const k: Kpi[] = [
    { label: 'Total engineers', value: fmtNum(kpis.total_engineers) },
    { label: 'Skill entries', value: fmtNum(kpis.total_skill_entries) },
    { label: 'Categories tracked', value: fmtNum(kpis.total_categories) },
    { label: 'Expert entries', value: fmtNum(kpis.expert_count) },
    { label: 'Master entries', value: fmtNum(kpis.master_count) },
    { label: 'Proficient entries', value: fmtNum(kpis.proficient_count) },
    { label: 'Novice entries', value: fmtNum(kpis.novice_count) },
    { label: 'Certified entries', value: fmtNum(kpis.certified_count) },
    { label: 'Avg score', value: kpis.avg_score !== null && kpis.avg_score !== undefined ? Number(kpis.avg_score).toFixed(1) : '—' },
    { label: 'Median score', value: kpis.median_score !== null && kpis.median_score !== undefined ? Number(kpis.median_score).toFixed(1) : '—' },
    { label: 'Uncovered categories', value: fmtNum(kpis.uncovered_categories) },
    { label: 'Bottleneck categories', value: fmtNum(kpis.bottleneck_categories) },
    { label: 'Engineers w/ no skills', value: fmtNum(kpis.engineers_no_skills) },
    { label: 'Engineers w/ 1 skill', value: fmtNum(kpis.engineers_single_skill) },
    { label: 'Assessed last 30d', value: fmtNum(kpis.recent_assessments_30d) },
    { label: 'Stale (>180d)', value: fmtNum(kpis.stale_assessments_180d) },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'tier', header: 'Tier', render: (r: any) => r.tier ?? '—' },
    { key: 'skill_count', header: 'Skills', render: (r: any) => fmtNum(r.skill_count) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => r.avg_score !== null && r.avg_score !== undefined ? Number(r.avg_score).toFixed(1) : '—' },
    { key: 'expert_count', header: 'Experts', render: (r: any) => fmtNum(r.expert_count) },
    { key: 'certified_count', header: 'Certified', render: (r: any) => fmtNum(r.certified_count) },
    { key: 'last_assessed_at', header: 'Last assessed', render: (r: any) => fmtDate(r.last_assessed_at) },
  ];

  const gapCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'engineers_covering', header: 'Covering', render: (r: any) => fmtNum(r.engineers_covering) },
    { key: 'expert_count', header: 'Experts', render: (r: any) => fmtNum(r.expert_count) },
    { key: 'proficient_count', header: 'Proficient+', render: (r: any) => fmtNum(r.proficient_count) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => r.avg_score !== null && r.avg_score !== undefined ? Number(r.avg_score).toFixed(1) : '—' },
    { key: 'coverage_ratio', header: 'Coverage', render: (r: any) => fmtRatio(r.coverage_ratio) },
    { key: 'gap_severity', header: 'Gap', render: (r: any) => r.gap_severity ?? '—' },
  ];

  const bnCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'engineers_covering', header: 'Covering', render: (r: any) => fmtNum(r.engineers_covering) },
    { key: 'expert_count', header: 'Experts', render: (r: any) => fmtNum(r.expert_count) },
    { key: 'bottleneck_score', header: 'Bottleneck', render: (r: any) => r.bottleneck_score !== null && r.bottleneck_score !== undefined ? Number(r.bottleneck_score).toFixed(2) : '—' },
    { key: 'recommendation', header: 'Action', render: (r: any) => r.recommendation ?? '—' },
  ];

  const distCols: Column<any>[] = [
    { key: 'proficiency_level', header: 'Level', render: (r: any) => r.proficiency_level ?? '—' },
    { key: 'entry_count', header: 'Entries', render: (r: any) => fmtNum(r.entry_count) },
    { key: 'pct_of_total', header: 'Share', render: (r: any) => fmtPct(r.pct_of_total) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => r.avg_score !== null && r.avg_score !== undefined ? Number(r.avg_score).toFixed(1) : '—' },
    { key: 'certified_count', header: 'Certified', render: (r: any) => fmtNum(r.certified_count) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category ?? '—' },
    { key: 'proficiency_level', header: 'Level', render: (r: any) => r.proficiency_level ?? '—' },
    { key: 'proficiency_score', header: 'Score', render: (r: any) => fmtNum(r.proficiency_score) },
    { key: 'certified', header: 'Certified', render: (r: any) => r.certified ? 'yes' : 'no' },
    { key: 'last_assessed_at', header: 'Assessed', render: (r: any) => fmtDate(r.last_assessed_at) },
    { key: 'days_since_assessed', header: 'Days ago', render: (r: any) => r.days_since_assessed !== null && r.days_since_assessed !== undefined ? Number(r.days_since_assessed).toFixed(0) : '—' },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer skills graph</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Per-engineer skill matrix {"<"}equipment categories × proficiency{">"}; fleet-coverage gaps; bottlenecks. <strong>r1521★</strong>
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 12, marginBottom: 24 }}>
        {k.map((c) => (
          <div key={c.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{c.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{c.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Skill matrix by engineer</h2>
        <DataTable rowKey={(r: any) => r.id} columns={engCols} rows={byEngineer} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Fleet coverage gaps</h2>
        <DataTable rowKey={(r: any) => r.id} columns={gapCols} rows={gaps} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Skill bottlenecks</h2>
        <DataTable rowKey={(r: any) => r.id} columns={bnCols} rows={bottlenecks} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Proficiency distribution</h2>
        <DataTable rowKey={(r: any) => r.id} columns={distCols} rows={distribution} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent assessments</h2>
        <DataTable rowKey={(r: any) => r.id} columns={recentCols} rows={recent} />
      </section>
    </div>
  );
}
