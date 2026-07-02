import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [summary, byStage, allDeals, stuck, highConf, byCity, weighted] = await Promise.all([
    sb.rpc('r2251_pipeline_summary'),
    sb.rpc('r2251_pipeline_by_stage'),
    sb.rpc('r2251_all_deals'),
    sb.rpc('r2251_stuck_deals'),
    sb.rpc('r2251_high_confidence'),
    sb.rpc('r2251_by_city'),
    sb.rpc('r2251_weighted_pipeline'),
  ]);

  const s = summary.data?.[0] ?? { total_deals: 0, total_value_rupees: 0, active_deals: 0, signed_deals: 0, lost_deals: 0, avg_confidence: 0 };
  const fmt = (n: number) => `₹${(Number(n) / 100000).toFixed(1)}L`;

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r) => String(r.stage).toUpperCase() },
    { key: 'deal_count', header: 'Deals', render: (r) => r.deal_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r) => fmt(r.total_value_rupees) },
    { key: 'avg_weeks_in_stage', header: 'Avg Weeks', render: (r) => r.avg_weeks_in_stage },
    { key: 'avg_confidence', header: 'Avg Conf %', render: (r) => r.avg_confidence },
  ];

  const dealCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'stage', header: 'Stage', render: (r) => String(r.stage).toUpperCase() },
    { key: 'deal_value_rupees', header: 'Value', render: (r) => fmt(r.deal_value_rupees) },
    { key: 'weeks_in_stage', header: 'Weeks in stage', render: (r) => r.weeks_in_stage },
    { key: 'close_confidence_pct', header: 'Confidence %', render: (r) => r.close_confidence_pct },
    { key: 'expected_close_date', header: 'Expected close', render: (r) => r.expected_close_date ?? '—' },
  ];

  const stuckCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'stage', header: 'Stage', render: (r) => String(r.stage).toUpperCase() },
    { key: 'weeks_in_stage', header: 'Weeks stuck', render: (r) => r.weeks_in_stage },
    { key: 'deal_value_rupees', header: 'Value', render: (r) => fmt(r.deal_value_rupees) },
    { key: 'close_confidence_pct', header: 'Conf %', render: (r) => r.close_confidence_pct },
  ];

  const highConfCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => r.hospital_name },
    { key: 'stage', header: 'Stage', render: (r) => String(r.stage).toUpperCase() },
    { key: 'deal_value_rupees', header: 'Value', render: (r) => fmt(r.deal_value_rupees) },
    { key: 'close_confidence_pct', header: 'Conf %', render: (r) => r.close_confidence_pct },
    { key: 'expected_close_date', header: 'Expected close', render: (r) => r.expected_close_date ?? '—' },
  ];

  const cityCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'deal_count', header: 'Deals', render: (r) => r.deal_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r) => fmt(r.total_value_rupees) },
    { key: 'signed_count', header: 'Signed', render: (r) => r.signed_count },
  ];

  const weightedCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r) => String(r.stage).toUpperCase() },
    { key: 'deal_count', header: 'Deals', render: (r) => r.deal_count },
    { key: 'raw_value_rupees', header: 'Raw Value', render: (r) => fmt(r.raw_value_rupees) },
    { key: 'weighted_value_rupees', header: 'Weighted (by conf %)', render: (r) => fmt(r.weighted_value_rupees) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital signed-MOU pipeline</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        Prospective hospitals at LOI / MOU / PO / signed stages. Deals stuck &gt; 21 days surface in the laggard table.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total deals</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{s.total_deals}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total value</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmt(s.total_value_rupees)}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Active</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{s.active_deals}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Signed</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#16a34a' }}>{s.signed_deals}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Lost</div>
          <div style={{ fontSize: 22, fontWeight: 700, color: '#dc2626' }}>{s.lost_deals}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg conf %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{s.avg_confidence}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pipeline by stage</h2>
        <DataTable columns={stageCols} rows={byStage.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Weighted pipeline (value × confidence)</h2>
        <DataTable columns={weightedCols} rows={weighted.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Stuck deals (in stage &gt; 21 days)</h2>
        <DataTable columns={stuckCols} rows={stuck.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>High confidence (&gt;= 70%)</h2>
        <DataTable columns={highConfCols} rows={highConf.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By city</h2>
        <DataTable columns={cityCols} rows={byCity.data ?? []} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All deals</h2>
        <DataTable columns={dealCols} rows={allDeals.data ?? []} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
