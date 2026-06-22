import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [listRes, topRes, aggRes, recentRes] = await Promise.all([
    sb.rpc('list_tender_roi_r2219'),
    sb.rpc('top_tender_roi_r2219'),
    sb.rpc('aggregate_tender_roi_r2219'),
    sb.rpc('recent_actions_tender_roi_r2219'),
  ]);

  const rows: any[] = Array.isArray(listRes.data) ? listRes.data : [];
  const tops: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const agg: any = Array.isArray(aggRes.data) ? aggRes.data[0] ?? {} : (aggRes.data ?? {});
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const cols: Column<any>[] = [
    { key: 'tender_code', header: 'Tender', render: (r: any) => String(r.tender_code ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'city', header: 'City', render: (r: any) => String(r.city ?? '') },
    { key: 'won_at', header: 'Won', render: (r: any) => String(r.won_at ?? '') },
    { key: 'bid_cost_rupees', header: 'Bid Cost (Rs)', render: (r: any) => Number(r.bid_cost_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'realized_revenue_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.realized_revenue_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'roi_ratio', header: 'ROI x', render: (r: any) => r.roi_ratio == null ? '-' : String(r.roi_ratio) },
    { key: 'payback_months', header: 'Payback (mo)', render: (r: any) => r.payback_months == null ? '-' : String(r.payback_months) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const topCols: Column<any>[] = [
    { key: 'tender_code', header: 'Tender', render: (r: any) => String(r.tender_code ?? '') },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'roi_ratio', header: 'ROI x', render: (r: any) => r.roi_ratio == null ? '-' : String(r.roi_ratio) },
    { key: 'realized_revenue_rupees', header: 'Revenue (Rs)', render: (r: any) => Number(r.realized_revenue_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'op_name', header: 'Op', render: (r: any) => String(r.op_name ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    { key: 'created_at', header: 'When', render: (r: any) => String(r.created_at ?? '').slice(0, 19) },
    { key: 'after_value', header: 'Payload', render: (r: any) => JSON.stringify(r.after_value ?? {}) },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>
        Hospital Tender Response ROI
      </h1>
      <p style={{ color: '#555', marginBottom: 16, fontSize: 13 }}>
        Track bid effort & cost vs realized revenue. Surface ROI ratio and payback months for every tender won.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 12, marginBottom: 24 }}>
        <Card label="Tenders" value={String(agg.total_tenders ?? 0)} />
        <Card label="Bid Cost (Rs)" value={Number(agg.total_bid_cost_rupees ?? 0).toLocaleString('en-IN')} />
        <Card label="Realized (Rs)" value={Number(agg.total_realized_rupees ?? 0).toLocaleString('en-IN')} />
        <Card label="Blended ROI x" value={agg.blended_roi == null ? '-' : String(agg.blended_roi)} />
        <Card label="Payback < 6mo" value={String(agg.payback_lt_6mo ?? 0)} />
        <Card label="Payback > 12mo" value={String(agg.payback_gt_12mo ?? 0)} />
      </div>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>All tenders won</h2>
      <DataTable columns={cols} rows={rows} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Top 10 ROI</h2>
      <DataTable columns={topCols} rows={tops} rowKey={(_, i) => String(i)} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent founder actions</h2>
      <DataTable columns={actionCols} rows={recent} rowKey={(_, i) => String(i)} />
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 18, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}
