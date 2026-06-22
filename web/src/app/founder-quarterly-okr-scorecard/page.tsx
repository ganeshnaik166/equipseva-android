import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, objectives, categories, midPending, topPerf, lessons, rollfwd] = await Promise.all([
    sb.rpc('founder_okr_quarter_summary_r2237'),
    sb.rpc('founder_okr_objectives_list_r2237'),
    sb.rpc('founder_okr_category_breakdown_r2237'),
    sb.rpc('founder_okr_mid_check_pending_r2237'),
    sb.rpc('founder_okr_top_performers_r2237'),
    sb.rpc('founder_okr_lessons_list_r2237'),
    sb.rpc('founder_okr_rollforward_pending_r2237'),
  ]);

  const summaryRows = (summary.data ?? []) as any[];
  const objectiveRows = (objectives.data ?? []) as any[];
  const categoryRows = (categories.data ?? []) as any[];
  const midRows = (midPending.data ?? []) as any[];
  const topRows = (topPerf.data ?? []) as any[];
  const lessonRows = (lessons.data ?? []) as any[];
  const rollRows = (rollfwd.data ?? []) as any[];

  const totalObjectives = objectiveRows.length;
  const scoredCount = objectiveRows.filter((o) => o.status === 'scored').length;
  const avgScore = scoredCount
    ? (objectiveRows.filter((o) => o.final_score_pct != null).reduce((a, b) => a + Number(b.final_score_pct || 0), 0) / scoredCount).toFixed(1)
    : '—';
  const midPendingCount = midRows.length;

  const summaryCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'fiscal_year', header: 'FY', render: (r: any) => String(r.fiscal_year ?? '') },
    { key: 'quarter_num', header: 'Q#', render: (r: any) => String(r.quarter_num ?? '') },
    { key: 'objective_count', header: 'Objectives', render: (r: any) => String(r.objective_count ?? 0) },
    { key: 'active_count', header: 'Active', render: (r: any) => String(r.active_count ?? 0) },
    { key: 'scored_count', header: 'Scored', render: (r: any) => String(r.scored_count ?? 0) },
    { key: 'avg_score', header: 'Avg Score %', render: (r: any) => r.avg_score != null ? String(r.avg_score) : '—' },
    { key: 'total_weight', header: 'Weight Sum', render: (r: any) => String(r.total_weight ?? 0) },
  ];

  const objectiveCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'objective_title', header: 'Objective', render: (r: any) => String(r.objective_title ?? '') },
    { key: 'key_result_text', header: 'Key Result', render: (r: any) => String(r.key_result_text ?? '') },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'baseline_value', header: 'Baseline', render: (r: any) => String(r.baseline_value ?? 0) },
    { key: 'target_value', header: 'Target', render: (r: any) => String(r.target_value ?? 0) },
    { key: 'mid_quarter_value', header: 'Mid', render: (r: any) => r.mid_quarter_value != null ? String(r.mid_quarter_value) : '—' },
    { key: 'end_quarter_value', header: 'End', render: (r: any) => r.end_quarter_value != null ? String(r.end_quarter_value) : '—' },
    { key: 'weight_pct', header: 'Wt %', render: (r: any) => String(r.weight_pct ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'final_score_pct', header: 'Score %', render: (r: any) => r.final_score_pct != null ? String(r.final_score_pct) : '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '—') },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
    { key: 'objective_count', header: 'Objectives', render: (r: any) => String(r.objective_count ?? 0) },
    { key: 'scored_count', header: 'Scored', render: (r: any) => String(r.scored_count ?? 0) },
    { key: 'avg_score', header: 'Avg Score %', render: (r: any) => r.avg_score != null ? String(r.avg_score) : '—' },
    { key: 'total_weight', header: 'Weight Sum', render: (r: any) => String(r.total_weight ?? 0) },
  ];

  const midCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'objective_title', header: 'Objective', render: (r: any) => String(r.objective_title ?? '') },
    { key: 'key_result_text', header: 'Key Result', render: (r: any) => String(r.key_result_text ?? '') },
    { key: 'baseline_value', header: 'Baseline', render: (r: any) => String(r.baseline_value ?? 0) },
    { key: 'target_value', header: 'Target', render: (r: any) => String(r.target_value ?? 0) },
    { key: 'weight_pct', header: 'Wt %', render: (r: any) => String(r.weight_pct ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '—') },
    { key: 'days_since_created', header: 'Age (days)', render: (r: any) => String(r.days_since_created ?? 0) },
  ];

  const topCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'objective_title', header: 'Objective', render: (r: any) => String(r.objective_title ?? '') },
    { key: 'key_result_text', header: 'Key Result', render: (r: any) => String(r.key_result_text ?? '') },
    { key: 'final_score_pct', header: 'Score %', render: (r: any) => String(r.final_score_pct ?? 0) },
    { key: 'weight_pct', header: 'Wt %', render: (r: any) => String(r.weight_pct ?? 0) },
    { key: 'category', header: 'Category', render: (r: any) => String(r.category ?? '') },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'lesson_type', header: 'Type', render: (r: any) => String(r.lesson_type ?? '') },
    { key: 'lesson_text', header: 'Lesson', render: (r: any) => String(r.lesson_text ?? '') },
    { key: 'action_item', header: 'Action', render: (r: any) => String(r.action_item ?? '—') },
    { key: 'rolled_to_quarter', header: 'Rolled To', render: (r: any) => String(r.rolled_to_quarter ?? '—') },
    { key: 'resolved', header: 'Resolved', render: (r: any) => r.resolved ? 'yes' : 'no' },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString() : '—' },
  ];

  const rollCols: Column<any>[] = [
    { key: 'quarter_label', header: 'From Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'lesson_text', header: 'Lesson', render: (r: any) => String(r.lesson_text ?? '') },
    { key: 'action_item', header: 'Action', render: (r: any) => String(r.action_item ?? '—') },
    { key: 'rolled_to_quarter', header: 'Rolled To', render: (r: any) => String(r.rolled_to_quarter ?? '—') },
    { key: 'age_days', header: 'Age (days)', render: (r: any) => String(r.age_days ?? 0) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>Quarterly OKR Scorecard</h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        OKRs by quarter, mid-quarter check-in, end-quarter score, and lessons rolled forward.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Objectives</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalObjectives}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Scored</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{scoredCount}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Avg Score %</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{avgScore}</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Mid-Check Pending</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{midPendingCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Quarter Summary</h2>
        <DataTable columns={summaryCols} rows={summaryRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Objectives & Key Results</h2>
        <DataTable columns={objectiveCols} rows={objectiveRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Category Breakdown</h2>
        <DataTable columns={categoryCols} rows={categoryRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Mid-Quarter Check-In Pending</h2>
        <DataTable columns={midCols} rows={midRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Performing Objectives</h2>
        <DataTable columns={topCols} rows={topRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Lessons Log</h2>
        <DataTable columns={lessonCols} rows={lessonRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Roll-Forward Pending</h2>
        <DataTable columns={rollCols} rows={rollRows} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
