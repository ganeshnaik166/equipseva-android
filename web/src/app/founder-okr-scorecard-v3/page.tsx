import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any, digits = 0): string {
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toLocaleString('en-IN', { maximumFractionDigits: digits });
}
function fmtPct(n: any): string {
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return `${v.toFixed(1)}%`;
}
function fmtDate(d: any): string {
  if (!d) return '—';
  try { return new Date(d).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let summary: any[] = [];
  let objectives: any[] = [];
  let keyResults: any[] = [];
  let checkins: any[] = [];
  let grades: any[] = [];

  try {
    const r = await sb.rpc('founder_okr_v3_quarter_summary');
    summary = (r.data as any[]) ?? [];
  } catch { summary = []; }
  try {
    const r = await sb.rpc('founder_okr_v3_objective_progress');
    objectives = (r.data as any[]) ?? [];
  } catch { objectives = []; }
  try {
    const r = await sb.rpc('founder_okr_v3_key_results_detail');
    keyResults = (r.data as any[]) ?? [];
  } catch { keyResults = []; }
  try {
    const r = await sb.rpc('founder_okr_v3_recent_checkins');
    checkins = (r.data as any[]) ?? [];
  } catch { checkins = []; }
  try {
    const r = await sb.rpc('founder_okr_v3_grade_distribution');
    grades = (r.data as any[]) ?? [];
  } catch { grades = []; }

  const currentQ = summary[0] ?? {};
  const totalObj = objectives.length;
  const activeObj = objectives.filter(o => o.status === 'active').length;
  const doneObj = objectives.filter(o => o.status === 'done').length;
  const gradedObj = objectives.filter(o => !!o.final_grade).length;
  const avgProgress = objectives.length
    ? objectives.reduce((a, o) => a + Number(o.progress_pct || 0), 0) / objectives.length
    : 0;
  const onTrack = objectives.filter(o => Number(o.progress_pct || 0) >= 70).length;
  const atRisk = objectives.filter(o => {
    const p = Number(o.progress_pct || 0);
    return p >= 30 && p < 70;
  }).length;
  const offTrack = objectives.filter(o => Number(o.progress_pct || 0) < 30).length;
  const totalKr = keyResults.length;
  const krsHit = keyResults.filter(k => Number(k.progress_pct || 0) >= 100).length;
  const checkinsCount = checkins.length;
  const staleCheckins = checkins.filter(c => Number(c.age_days || 0) > 7).length;
  const gradeA = grades.find(g => g.final_grade === 'A')?.obj_count ?? 0;
  const gradeF = grades.find(g => g.final_grade === 'F')?.obj_count ?? 0;
  const totalWeight = currentQ.total_weight ?? 0;
  const daysLeft = currentQ.days_remaining ?? 0;

  const kpis: Kpi[] = [
    { label: 'Current quarter', value: String(currentQ.quarter_label ?? '—') },
    { label: 'Days remaining', value: fmtNum(daysLeft, 1) },
    { label: 'Total objectives', value: fmtNum(totalObj) },
    { label: 'Active', value: fmtNum(activeObj) },
    { label: 'Done', value: fmtNum(doneObj) },
    { label: 'Graded', value: fmtNum(gradedObj) },
    { label: 'Avg progress', value: fmtPct(avgProgress) },
    { label: 'On track (>= 70%)', value: fmtNum(onTrack) },
    { label: 'At risk (30-70%)', value: fmtNum(atRisk) },
    { label: 'Off track ({"<"} 30%)', value: fmtNum(offTrack) },
    { label: 'Key results total', value: fmtNum(totalKr) },
    { label: 'KRs hit target', value: fmtNum(krsHit) },
    { label: 'Recent check-ins', value: fmtNum(checkinsCount) },
    { label: 'Stale (>7d)', value: fmtNum(staleCheckins) },
    { label: 'Grade A objectives', value: fmtNum(gradeA) },
    { label: 'Grade F objectives', value: fmtNum(gradeF) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'objectives_count', header: 'Objectives', render: (r: any) => fmtNum(r.objectives_count) },
    { key: 'active_count', header: 'Active', render: (r: any) => fmtNum(r.active_count) },
    { key: 'done_count', header: 'Done', render: (r: any) => fmtNum(r.done_count) },
    { key: 'avg_progress_pct', header: 'Avg %', render: (r: any) => fmtPct(r.avg_progress_pct) },
    { key: 'total_weight', header: 'Weight', render: (r: any) => fmtNum(r.total_weight, 1) },
    { key: 'days_remaining', header: 'Days left', render: (r: any) => fmtNum(r.days_remaining, 1) },
  ];

  const objCols: Column<any>[] = [
    { key: 'objective_title', header: 'Objective', render: (r: any) => r.objective_title ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'weight_pct', header: 'Weight', render: (r: any) => fmtNum(r.weight_pct, 1) },
    { key: 'kr_count', header: 'KRs', render: (r: any) => fmtNum(r.kr_count) },
    { key: 'progress_pct', header: 'Progress', render: (r: any) => fmtPct(r.progress_pct) },
    { key: 'last_checkin_at', header: 'Last check-in', render: (r: any) => fmtDate(r.last_checkin_at) },
    { key: 'days_to_close', header: 'Days to close', render: (r: any) => fmtNum(r.days_to_close, 1) },
    { key: 'final_grade', header: 'Grade', render: (r: any) => r.final_grade ?? '—' },
  ];

  const krCols: Column<any>[] = [
    { key: 'objective_title', header: 'Objective', render: (r: any) => r.objective_title ?? '—' },
    { key: 'kr_title', header: 'KR', render: (r: any) => r.kr_title ?? '—' },
    { key: 'kr_unit', header: 'Unit', render: (r: any) => r.kr_unit ?? '—' },
    { key: 'start_value', header: 'Start', render: (r: any) => fmtNum(r.start_value, 2) },
    { key: 'current_value', header: 'Current', render: (r: any) => fmtNum(r.current_value, 2) },
    { key: 'target_value', header: 'Target', render: (r: any) => fmtNum(r.target_value, 2) },
    { key: 'progress_pct', header: 'Progress', render: (r: any) => fmtPct(r.progress_pct) },
    { key: 'last_checkin_at', header: 'Checked', render: (r: any) => fmtDate(r.last_checkin_at) },
  ];

  const checkinCols: Column<any>[] = [
    { key: 'objective_title', header: 'Objective', render: (r: any) => r.objective_title ?? '—' },
    { key: 'kr_title', header: 'KR', render: (r: any) => r.kr_title ?? '—' },
    { key: 'checkin_at', header: 'When', render: (r: any) => fmtDate(r.checkin_at) },
    { key: 'current_value', header: 'Value', render: (r: any) => fmtNum(r.current_value, 2) },
    { key: 'age_days', header: 'Age (d)', render: (r: any) => fmtNum(r.age_days, 1) },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'final_grade', header: 'Grade', render: (r: any) => r.final_grade ?? '—' },
    { key: 'obj_count', header: 'Objectives', render: (r: any) => fmtNum(r.obj_count) },
    { key: 'avg_weight', header: 'Avg weight', render: (r: any) => fmtNum(r.avg_weight, 1) },
    { key: 'quarters_covered', header: 'Quarters', render: (r: any) => fmtNum(r.quarters_covered) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Founder OKR Scorecard v3
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Quarterly OKR tracker. Per-objective key results with weekly check-ins,
        auto-aggregated progress, and end-of-quarter founder grade.
        Total weight this quarter: {fmtNum(totalWeight, 1)}.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 32 }}>
        {kpis.map((k, i) => (
          <div key={i} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Quarter summary (last 8)</h2>
      <DataTable
        rows={summary}
        columns={summaryCols}
        rowKey={(r: any) => r.quarter_label}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Objective progress</h2>
      <DataTable
        rows={objectives}
        columns={objCols}
        rowKey={(r: any) => r.id}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Key results detail</h2>
      <DataTable
        rows={keyResults}
        columns={krCols}
        rowKey={(r: any) => r.id}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Recent check-ins</h2>
      <DataTable
        rows={checkins}
        columns={checkinCols}
        rowKey={(r: any) => r.id}
      />

      <h2 style={{ fontSize: 20, fontWeight: 600, margin: '24px 0 12px' }}>Grade distribution</h2>
      <DataTable
        rows={grades}
        columns={gradeCols}
        rowKey={(r: any) => r.final_grade}
      />
    </main>
  );
}
