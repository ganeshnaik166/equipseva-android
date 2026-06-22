import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [stockoutsRes, criticalRes, actionsRes, recentRes] = await Promise.all([
    sb.rpc('list_stockouts_r1911'),
    sb.rpc('critical_only_r1911'),
    sb.rpc('list_actions_r1911'),
    sb.rpc('recent_actions_r1911'),
  ]);

  const stockouts: any[] = stockoutsRes.data ?? [];
  const critical: any[] = criticalRes.data ?? [];
  const actions: any[] = actionsRes.data ?? [];
  const recent: any[] = recentRes.data ?? [];

  const totalCritical = critical.length;
  const totalConcern = stockouts.filter((s) => s.risk_level === 'concern').length;
  const totalWatch = stockouts.filter((s) => s.risk_level === 'watch').length;
  const totalActions14d = recent.length;

  const stockoutColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '-'}</span> },
    { key: 'supply_name', header: 'Supply', render: (r: any) => <span>{r.supply_name ?? '-'}</span> },
    { key: 'supply_category', header: 'Category', render: (r: any) => <span>{r.supply_category ?? '-'}</span> },
    { key: 'current_stock_units', header: 'Stock', render: (r: any) => <span>{r.current_stock_units ?? 0}</span> },
    { key: 'reorder_point', header: 'Reorder Pt', render: (r: any) => <span>{r.reorder_point ?? 0}</span> },
    { key: 'days_until_stockout', header: 'Days Left', render: (r: any) => <span>{r.days_until_stockout ?? 0}</span> },
    { key: 'risk_level', header: 'Risk', render: (r: any) => <span style={{ fontWeight: 600, color: r.risk_level === 'critical' ? '#b91c1c' : r.risk_level === 'concern' ? '#c2410c' : r.risk_level === 'watch' ? '#a16207' : '#15803d' }}>{r.risk_level ?? '-'}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{r.captured_at ? new Date(r.captured_at).toLocaleString() : '-'}</span> },
  ];

  const criticalColumns: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '-'}</span> },
    { key: 'supply_name', header: 'Supply', render: (r: any) => <span>{r.supply_name ?? '-'}</span> },
    { key: 'supply_category', header: 'Category', render: (r: any) => <span>{r.supply_category ?? '-'}</span> },
    { key: 'current_stock_units', header: 'Stock', render: (r: any) => <span>{r.current_stock_units ?? 0}</span> },
    { key: 'days_until_stockout', header: 'Days Left', render: (r: any) => <span style={{ color: '#b91c1c', fontWeight: 600 }}>{r.days_until_stockout ?? 0}</span> },
    { key: 'captured_at', header: 'Captured', render: (r: any) => <span>{r.captured_at ? new Date(r.captured_at).toLocaleString() : '-'}</span> },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => <span>{r.taken_at ? new Date(r.taken_at).toLocaleString() : '-'}</span> },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => <span>{r.hospital_name ?? '-'}</span> },
    { key: 'supply_name', header: 'Supply', render: (r: any) => <span>{r.supply_name ?? '-'}</span> },
    { key: 'action_type', header: 'Action', render: (r: any) => <span>{r.action_type ?? '-'}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '-'}</span> },
    { key: 'outcome', header: 'Outcome', render: (r: any) => <span>{r.outcome ?? '-'}</span> },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <header style={{ marginBottom: '24px' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>Hospital Critical Supply Stockout Risk</h1>
        <p style={{ color: '#666', fontSize: '14px' }}>
          Track stockout risk across hospitals by supply category. Spot critical items running below reorder point and act before customer impact.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '12px', marginBottom: '32px' }}>
        <div style={{ padding: '16px', border: '1px solid #fecaca', borderRadius: '8px', background: '#fef2f2' }}>
          <div style={{ fontSize: '12px', color: '#991b1b', textTransform: 'uppercase', fontWeight: 600 }}>Critical</div>
          <div style={{ fontSize: '24px', fontWeight: 700, color: '#b91c1c' }}>{totalCritical}</div>
          <div style={{ fontSize: '11px', color: '#7f1d1d' }}>stockout imminent</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #fed7aa', borderRadius: '8px', background: '#fff7ed' }}>
          <div style={{ fontSize: '12px', color: '#9a3412', textTransform: 'uppercase', fontWeight: 600 }}>Concern</div>
          <div style={{ fontSize: '24px', fontWeight: 700, color: '#c2410c' }}>{totalConcern}</div>
          <div style={{ fontSize: '11px', color: '#7c2d12' }}>below reorder point</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #fde68a', borderRadius: '8px', background: '#fefce8' }}>
          <div style={{ fontSize: '12px', color: '#854d0e', textTransform: 'uppercase', fontWeight: 600 }}>Watch</div>
          <div style={{ fontSize: '24px', fontWeight: 700, color: '#a16207' }}>{totalWatch}</div>
          <div style={{ fontSize: '11px', color: '#713f12' }}>monitor closely</div>
        </div>
        <div style={{ padding: '16px', border: '1px solid #e5e7eb', borderRadius: '8px', background: '#fff' }}>
          <div style={{ fontSize: '12px', color: '#374151', textTransform: 'uppercase', fontWeight: 600 }}>Actions (14d)</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalActions14d}</div>
          <div style={{ fontSize: '11px', color: '#6b7280' }}>recent interventions</div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Critical Stockouts</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Items flagged critical — days until stockout is at or below the critical threshold. Act now.
        </p>
        <DataTable rows={critical} columns={criticalColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>All Stockout Snapshots</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Every captured snapshot across hospitals and supply categories. Sorted by risk severity then days remaining.
        </p>
        <DataTable rows={stockouts} columns={stockoutColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Recent Actions (last 14 days)</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Interventions logged in the past two weeks — reorders, escalations, alternate sourcing, and customer notifications.
        </p>
        <DataTable rows={recent} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Full Action Log</h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '12px' }}>
          Complete history of stockout actions across all hospitals and supplies.
        </p>
        <DataTable rows={actions} columns={actionColumns} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
