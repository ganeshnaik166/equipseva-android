import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TrendRow = {
  id: string;
  hospital_id: string;
  period_label: string;
  total_spend_rupees: number;
  avg_monthly_spend_rupees: number;
  trend_direction: string;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  trend_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const trendsRes = await sb.rpc('list_trends_r2183', { p_limit: 100 });
  const decliningRes = await sb.rpc('declining_customers_r2183');
  const actionsRes = await sb.rpc('recent_actions_r2183', { p_limit: 50 });

  const trends: TrendRow[] = (trendsRes.data as TrendRow[]) ?? [];
  const declining: TrendRow[] = (decliningRes.data as TrendRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'hospital_id', header: 'Hospital', render: (r: any) => String(r.hospital_id ?? '').slice(0, 8) },
    { key: 'total_spend_rupees', header: 'Total Spend', render: (r: any) => `Rs ${Number(r.total_spend_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'avg_monthly_spend_rupees', header: 'Avg Monthly', render: (r: any) => `Rs ${Number(r.avg_monthly_spend_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'trend_direction', header: 'Direction', render: (r: any) => String(r.trend_direction ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'trend_id', header: 'Trend', render: (r: any) => String(r.trend_id ?? '').slice(0, 8) },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const growingCount = trends.filter((t) => t.status === 'growing' || t.status === 'exceptional').length;
  const decliningCount = trends.filter((t) => t.status === 'declining' || t.status === 'at_risk').length;
  const totalSpend = trends.reduce((acc, t) => acc + Number(t.total_spend_rupees ?? 0), 0);

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Customer Spend Trend Index</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>Track customer spend trends. Celebrate growth, intervene on decline.</p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Growing or Exceptional</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{growingCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Declining or At Risk</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{decliningCount}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Tracked Spend</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>Rs {totalSpend.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Trend Snapshots</h2>
        <DataTable rows={trends} columns={trendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Declining Customers</h2>
        <DataTable rows={declining} columns={trendCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
