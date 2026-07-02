import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalEquipmentAgingCurvePage() {
  const sb = await getSupabaseServerClient();

  const [curvesRes, recosRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_aging_curves_r1895'),
    sb.rpc('list_aging_recommendations_r1895'),
    sb.rpc('top_aging_categories_r1895'),
    sb.rpc('recent_aging_decisions_r1895'),
  ]);

  const curves: any[] = Array.isArray(curvesRes.data) ? curvesRes.data : [];
  const recos: any[] = Array.isArray(recosRes.data) ? recosRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const curveCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '-') },
    { key: 'age_bucket', header: 'Age Bucket (yrs)', render: (r: any) => String(r.age_bucket ?? '-').replace('plus_y', '+y').replace('_', '-') },
    { key: 'total_units', header: 'Total Units', render: (r: any) => Number(r.total_units ?? 0).toLocaleString('en-IN') },
    { key: 'units_failed_pct', header: 'Failure %', render: (r: any) => `${Number(r.units_failed_pct ?? 0).toFixed(2)}%` },
    { key: 'avg_repair_cost_rupees', header: 'Avg Repair Cost', render: (r: any) => `Rs ${Number(r.avg_repair_cost_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'recorded_at', header: 'Recorded', render: (r: any) => r.recorded_at ? new Date(r.recorded_at).toLocaleDateString('en-IN') : '-' },
  ];

  const recoCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '-') },
    { key: 'age_bucket', header: 'Age Bucket', render: (r: any) => String(r.age_bucket ?? '-').replace('plus_y', '+y').replace('_', '-') },
    { key: 'recommendation', header: 'Recommendation', render: (r: any) => String(r.recommendation ?? '-').replace('_', ' ') },
    { key: 'estimated_savings_rupees', header: 'Est. Savings', render: (r: any) => `Rs ${Number(r.estimated_savings_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'founder_decision', header: 'Decision', render: (r: any) => String(r.founder_decision ?? 'pending') },
    { key: 'created_at', header: 'Logged', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleDateString('en-IN') : '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '-') },
    { key: 'total_units', header: 'Total Units', render: (r: any) => Number(r.total_units ?? 0).toLocaleString('en-IN') },
    { key: 'weighted_failure_pct', header: 'Weighted Failure %', render: (r: any) => `${Number(r.weighted_failure_pct ?? 0).toFixed(2)}%` },
    { key: 'total_avg_repair_cost', header: 'Sum Avg Repair Cost', render: (r: any) => `Rs ${Number(r.total_avg_repair_cost ?? 0).toLocaleString('en-IN')}` },
  ];

  const recentCols: Column<any>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => String(r.equipment_category ?? '-') },
    { key: 'age_bucket', header: 'Age Bucket', render: (r: any) => String(r.age_bucket ?? '-').replace('plus_y', '+y').replace('_', '-') },
    { key: 'recommendation', header: 'Recommendation', render: (r: any) => String(r.recommendation ?? '-').replace('_', ' ') },
    { key: 'founder_decision', header: 'Decision', render: (r: any) => String(r.founder_decision ?? '-') },
    { key: 'estimated_savings_rupees', header: 'Est. Savings', render: (r: any) => `Rs ${Number(r.estimated_savings_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'updated_at', header: 'Decided', render: (r: any) => r.updated_at ? new Date(r.updated_at).toLocaleString('en-IN') : '-' },
  ];

  const totalCurves = curves.length;
  const pendingRecos = recos.filter((r: any) => !r.founder_decision).length;
  const acceptedRecos = recos.filter((r: any) => r.founder_decision === 'accepted').length;
  const totalSavings = recos
    .filter((r: any) => r.founder_decision === 'accepted')
    .reduce((s: number, r: any) => s + Number(r.estimated_savings_rupees ?? 0), 0);

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>Hospital Equipment Aging Curve</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Round r1895 — aging curve per equipment category (years vs failure rate) with founder replacement decisions.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 16, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Curve Rows</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{totalCurves}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 16, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending Recommendations</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{pendingRecos}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 16, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Accepted</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{acceptedRecos}</div>
        </div>
        <div style={{ border: '1px solid #ddd', borderRadius: 8, padding: 16, background: '#fafafa' }}>
          <div style={{ fontSize: 12, color: '#666' }}>Accepted Savings</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>Rs {totalSavings.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Aging Curves (category × age bucket)</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Buckets: 0-2y, 2-5y, 5-10y, 10-15y, 15+y. Higher failure % &gt; 20% suggests replacement window.
        </p>
        <DataTable rows={curves} columns={curveCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Aging Categories</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Weighted failure % across all age buckets. Categories with weighted failure &gt; 15% are replacement candidates.
        </p>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.equipment_category ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Replacement Recommendations</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Recommendation types: monitor &lt; preemptive_repair &lt; replace_soon &lt; replace_now. Founder decides accept/decline/defer.
        </p>
        <DataTable rows={recos} columns={recoCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Founder Decisions</h2>
        <p style={{ fontSize: 12, color: '#666', marginBottom: 12 }}>
          Last 50 decided recommendations across all categories.
        </p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <footer style={{ fontSize: 12, color: '#888', borderTop: '1px solid #eee', paddingTop: 12 }}>
        Founder-only console — all reads gated by is_founder(). Writes logged to founder_action_log.
      </footer>
    </main>
  );
}
