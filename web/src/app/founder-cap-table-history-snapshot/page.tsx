import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [snapshots, events, trajectory, kindSummary, latest, monthly, esopEvo] = await Promise.all([
    supabase.rpc('list_snapshots_r2529'),
    supabase.rpc('list_dilution_events_r2529'),
    supabase.rpc('founder_ownership_trajectory_r2529'),
    supabase.rpc('snapshot_kind_summary_r2529'),
    supabase.rpc('latest_locked_snapshot_r2529'),
    supabase.rpc('monthly_event_trend_r2529'),
    supabase.rpc('esop_pool_evolution_r2529'),
  ]);

  const snapshotCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'snapshot_kind', header: 'Kind', render: (r: any) => String(r.snapshot_kind ?? '') },
    { key: 'founder_ownership_pct', header: 'Founder %', render: (r: any) => `${Number(r.founder_ownership_pct ?? 0).toFixed(2)}%` },
    { key: 'esop_pool_pct', header: 'ESOP %', render: (r: any) => `${Number(r.esop_pool_pct ?? 0).toFixed(2)}%` },
    { key: 'total_investors_count', header: 'Investors', render: (r: any) => String(r.total_investors_count ?? 0) },
    { key: 'valuation_rupees', header: 'Valuation (Rs)', render: (r: any) => `Rs ${Number(r.valuation_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const eventCols: Column<any>[] = [
    { key: 'event_at', header: 'When', render: (r: any) => String(r.event_at ?? '').slice(0, 10) },
    { key: 'event_kind', header: 'Kind', render: (r: any) => String(r.event_kind ?? '') },
    { key: 'founder_delta_pct', header: 'Founder Δ%', render: (r: any) => `${Number(r.founder_delta_pct ?? 0).toFixed(2)}%` },
    { key: 'esop_delta_pct', header: 'ESOP Δ%', render: (r: any) => `${Number(r.esop_delta_pct ?? 0).toFixed(2)}%` },
    { key: 'employee_impact_summary', header: 'Impact', render: (r: any) => String(r.employee_impact_summary ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const trajCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'founder_ownership_pct', header: 'Founder %', render: (r: any) => `${Number(r.founder_ownership_pct ?? 0).toFixed(2)}%` },
    { key: 'valuation_rupees', header: 'Valuation (Rs)', render: (r: any) => `Rs ${Number(r.valuation_rupees ?? 0).toLocaleString('en-IN')}` },
    { key: 'snapshot_kind', header: 'Kind', render: (r: any) => String(r.snapshot_kind ?? '') },
  ];

  const kindCols: Column<any>[] = [
    { key: 'snapshot_kind', header: 'Kind', render: (r: any) => String(r.snapshot_kind ?? '') },
    { key: 'snapshots_count', header: 'Count', render: (r: any) => String(r.snapshots_count ?? 0) },
    { key: 'avg_founder_pct', header: 'Avg Founder %', render: (r: any) => `${Number(r.avg_founder_pct ?? 0).toFixed(2)}%` },
    { key: 'avg_esop_pct', header: 'Avg ESOP %', render: (r: any) => `${Number(r.avg_esop_pct ?? 0).toFixed(2)}%` },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => String(r.month_start ?? '').slice(0, 7) },
    { key: 'events_count', header: 'Events', render: (r: any) => String(r.events_count ?? 0) },
    { key: 'total_founder_delta', header: 'Founder Δ%', render: (r: any) => `${Number(r.total_founder_delta ?? 0).toFixed(2)}%` },
    { key: 'total_esop_delta', header: 'ESOP Δ%', render: (r: any) => `${Number(r.total_esop_delta ?? 0).toFixed(2)}%` },
  ];

  const esopCols: Column<any>[] = [
    { key: 'snapshot_date', header: 'Date', render: (r: any) => String(r.snapshot_date ?? '') },
    { key: 'esop_pool_pct', header: 'ESOP Pool %', render: (r: any) => `${Number(r.esop_pool_pct ?? 0).toFixed(2)}%` },
    { key: 'snapshot_kind', header: 'Kind', render: (r: any) => String(r.snapshot_kind ?? '') },
    { key: 'total_investors_count', header: 'Investors', render: (r: any) => String(r.total_investors_count ?? 0) },
  ];

  const latestRow = Array.isArray(latest.data) && latest.data.length > 0 ? latest.data[0] : null;

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 600, marginBottom: 8 }}>Founder Cap Table History & Snapshot</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Snapshot date &gt; cap table &gt; dilution events &gt; founder ownership &gt; ESOP &gt; notes.
      </p>

      {latestRow && (
        <section style={{ background: '#f8fafc', padding: 16, borderRadius: 8, marginBottom: 24, border: '1px solid #e2e8f0' }}>
          <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Latest Locked Snapshot</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: 12 }}>
            <div><strong>Date:</strong> {String(latestRow.snapshot_date ?? '')}</div>
            <div><strong>Kind:</strong> {String(latestRow.snapshot_kind ?? '')}</div>
            <div><strong>Founder %:</strong> {Number(latestRow.founder_ownership_pct ?? 0).toFixed(2)}%</div>
            <div><strong>ESOP %:</strong> {Number(latestRow.esop_pool_pct ?? 0).toFixed(2)}%</div>
            <div><strong>Investors:</strong> {String(latestRow.total_investors_count ?? 0)}</div>
            <div><strong>Valuation:</strong> Rs {Number(latestRow.valuation_rupees ?? 0).toLocaleString('en-IN')}</div>
          </div>
        </section>
      )}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Snapshots</h2>
        <DataTable
          rows={snapshots.data ?? []}
          columns={snapshotCols}
          emptyMessage="No snapshots yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Dilution Events</h2>
        <DataTable
          rows={events.data ?? []}
          columns={eventCols}
          emptyMessage="No dilution events recorded"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Founder Ownership Trajectory</h2>
        <DataTable
          rows={trajectory.data ?? []}
          columns={trajCols}
          emptyMessage="No trajectory data"
          rowKey={(r: any, i: number) => String(r.snapshot_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Snapshot Kind Summary</h2>
        <DataTable
          rows={kindSummary.data ?? []}
          columns={kindCols}
          emptyMessage="No summary data"
          rowKey={(r: any, i: number) => String(r.snapshot_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly Event Trend</h2>
        <DataTable
          rows={monthly.data ?? []}
          columns={monthlyCols}
          emptyMessage="No monthly trend data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>ESOP Pool Evolution</h2>
        <DataTable
          rows={esopEvo.data ?? []}
          columns={esopCols}
          emptyMessage="No ESOP evolution data"
          rowKey={(r: any, i: number) => String(r.snapshot_date ?? i)}
        />
      </section>
    </main>
  );
}
