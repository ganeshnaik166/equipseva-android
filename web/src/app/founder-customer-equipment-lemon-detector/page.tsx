import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    failuresRes,
    scorecardsRes,
    topLemonsRes,
    recommendationsRes,
    modelPatternsRes,
    monthlyTrendRes,
    economicsRes,
  ] = await Promise.all([
    supabase.rpc('list_failures_r2420'),
    supabase.rpc('list_scorecards_r2420'),
    supabase.rpc('top_lemons_r2420'),
    supabase.rpc('replacement_recommendations_r2420'),
    supabase.rpc('model_failure_patterns_r2420'),
    supabase.rpc('monthly_failure_trend_r2420'),
    supabase.rpc('repair_vs_replace_economics_r2420'),
  ]);

  const failures = (failuresRes.data ?? []) as any[];
  const scorecards = (scorecardsRes.data ?? []) as any[];
  const topLemons = (topLemonsRes.data ?? []) as any[];
  const recommendations = (recommendationsRes.data ?? []) as any[];
  const modelPatterns = (modelPatternsRes.data ?? []) as any[];
  const monthlyTrend = (monthlyTrendRes.data ?? []) as any[];
  const economics = (economicsRes.data ?? []) as any[];

  const failureColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'failure_at', header: 'Failure At', render: (r: any) => r.failure_at ? new Date(r.failure_at).toLocaleString() : '-' },
    { key: 'failure_kind', header: 'Kind', render: (r: any) => r.failure_kind },
    { key: 'cm_visits', header: 'CM Visits', render: (r: any) => r.cm_visits },
    { key: 'cm_cost_rupees', header: 'CM Cost', render: (r: any) => `₹${(r.cm_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: any) => r.downtime_minutes },
    { key: 'root_cause', header: 'Root Cause', render: (r: any) => r.root_cause ?? '-' },
    { key: 'repaired_at', header: 'Repaired At', render: (r: any) => r.repaired_at ? new Date(r.repaired_at).toLocaleDateString() : 'open' },
  ];

  const scorecardColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'total_failures', header: 'Failures', render: (r: any) => r.total_failures },
    { key: 'total_cm_cost_rupees', header: 'CM Cost', render: (r: any) => `₹${Number(r.total_cm_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => r.total_downtime_minutes },
    { key: 'lemon_score', header: 'Lemon Score', render: (r: any) => r.lemon_score },
    { key: 'recommendation', header: 'Action', render: (r: any) => r.recommendation },
    { key: 'replacement_cost_rupees', header: 'Replace Cost', render: (r: any) => `₹${(r.replacement_cost_rupees ?? 0).toLocaleString('en-IN')}` },
  ];

  const topLemonColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'lemon_score', header: 'Score', render: (r: any) => r.lemon_score },
    { key: 'total_failures', header: 'Failures', render: (r: any) => r.total_failures },
    { key: 'total_cm_cost_rupees', header: 'CM Cost', render: (r: any) => `₹${Number(r.total_cm_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => r.total_downtime_minutes },
    { key: 'recommendation', header: 'Action', render: (r: any) => r.recommendation },
  ];

  const recommendationColumns: Column<any>[] = [
    { key: 'recommendation', header: 'Recommendation', render: (r: any) => r.recommendation },
    { key: 'unit_count', header: 'Units', render: (r: any) => r.unit_count },
    { key: 'total_repair_cost_rupees', header: 'Repair Cost', render: (r: any) => `₹${Number(r.total_repair_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_replacement_cost_rupees', header: 'Replace Cost', render: (r: any) => `₹${Number(r.total_replacement_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => r.total_downtime_minutes },
  ];

  const modelPatternColumns: Column<any>[] = [
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'failure_count', header: 'Failures', render: (r: any) => r.failure_count },
    { key: 'total_cm_cost_rupees', header: 'CM Cost', render: (r: any) => `₹${Number(r.total_cm_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => r.total_downtime_minutes },
    { key: 'most_common_kind', header: 'Top Failure Kind', render: (r: any) => r.most_common_kind ?? '-' },
  ];

  const monthlyColumns: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '-' },
    { key: 'failure_count', header: 'Failures', render: (r: any) => r.failure_count },
    { key: 'total_cm_cost_rupees', header: 'CM Cost', render: (r: any) => `₹${Number(r.total_cm_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => r.total_downtime_minutes },
  ];

  const economicsColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_model', header: 'Model', render: (r: any) => r.equipment_model },
    { key: 'repair_cost_to_date_rupees', header: 'Repair Cost', render: (r: any) => `₹${(r.repair_cost_to_date_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'replacement_cost_rupees', header: 'Replace Cost', render: (r: any) => `₹${(r.replacement_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'repair_to_replace_pct', header: 'Repair/Replace %', render: (r: any) => `${Number(r.repair_to_replace_pct ?? 0).toFixed(2)}%` },
    { key: 'recommendation', header: 'Action', render: (r: any) => r.recommendation },
    { key: 'lemon_score', header: 'Score', render: (r: any) => r.lemon_score },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Customer Equipment Lemon Detector
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Spot lemons early — failures & CM cost vs replacement economics.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Lemons</h2>
        <DataTable
          rows={topLemons}
          columns={topLemonColumns}
          emptyMessage="No lemons flagged yet."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.equipment_label}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Repair vs Replace Economics</h2>
        <DataTable
          rows={economics}
          columns={economicsColumns}
          emptyMessage="No economics rows."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.equipment_label}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recommendation Mix</h2>
        <DataTable
          rows={recommendations}
          columns={recommendationColumns}
          emptyMessage="No recommendations."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.recommendation}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Lemon Scorecards</h2>
        <DataTable
          rows={scorecards}
          columns={scorecardColumns}
          emptyMessage="No scorecards."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Model Failure Patterns</h2>
        <DataTable
          rows={modelPatterns}
          columns={modelPatternColumns}
          emptyMessage="No model patterns."
          rowKey={(r: any, i: number) => String(r.equipment_model ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Failure Trend</h2>
        <DataTable
          rows={monthlyTrend}
          columns={monthlyColumns}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Failure Log</h2>
        <DataTable
          rows={failures}
          columns={failureColumns}
          emptyMessage="No failures logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
