import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerTravelVsBillableTimePage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';
  const founderEmail = process.env.FOUNDER_EMAIL ?? '';
  if (!email || email !== founderEmail) {
    return (
      <main style={{ padding: 24 }}>
        <h1>Forbidden</h1>
        <p>Founder access only.</p>
      </main>
    );
  }

  const [kpis, cities, regions, worst, trend, top, actions] = await Promise.all([
    supabase.rpc('engineer_travel_headline_kpis_r2354'),
    supabase.rpc('engineer_travel_city_breakdown_r2354'),
    supabase.rpc('engineer_travel_region_rollup_r2354'),
    supabase.rpc('engineer_travel_worst_offenders_r2354'),
    supabase.rpc('engineer_travel_daily_trend_r2354'),
    supabase.rpc('engineer_travel_top_performers_r2354'),
    supabase.rpc('engineer_travel_optimization_actions_list_r2354'),
  ]);

  const k = (kpis.data as any[] | null)?.[0] ?? null;

  const cityCols: Column<any>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'engineers_count', header: 'Engineers', render: (r) => r.engineers_count },
    { key: 'travel_pct', header: 'Travel %', render: (r) => `${r.travel_pct ?? 0}%` },
    { key: 'billable_pct', header: 'Billable %', render: (r) => `${r.billable_pct ?? 0}%` },
    { key: 'total_distance_km', header: 'Distance (km)', render: (r) => r.total_distance_km },
    { key: 'total_revenue_rupees', header: 'Revenue (Rs)', render: (r) => r.total_revenue_rupees },
  ];

  const regionCols: Column<any>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'engineers_count', header: 'Engineers', render: (r) => r.engineers_count },
    { key: 'travel_pct', header: 'Travel %', render: (r) => `${r.travel_pct ?? 0}%` },
    { key: 'billable_pct', header: 'Billable %', render: (r) => `${r.billable_pct ?? 0}%` },
    { key: 'avg_distance_per_engineer_km', header: 'Avg km/engineer', render: (r) => r.avg_distance_per_engineer_km },
    { key: 'total_revenue_rupees', header: 'Revenue (Rs)', render: (r) => r.total_revenue_rupees },
  ];

  const worstCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'days_logged', header: 'Days', render: (r) => r.days_logged },
    { key: 'travel_pct', header: 'Travel %', render: (r) => `${r.travel_pct ?? 0}%` },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => r.jobs_completed },
  ];

  const trendCols: Column<any>[] = [
    { key: 'log_date', header: 'Date', render: (r) => r.log_date },
    { key: 'engineers_count', header: 'Engineers', render: (r) => r.engineers_count },
    { key: 'travel_pct', header: 'Travel %', render: (r) => `${r.travel_pct ?? 0}%` },
    { key: 'billable_pct', header: 'Billable %', render: (r) => `${r.billable_pct ?? 0}%` },
  ];

  const topCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => r.engineer_email },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'billable_pct', header: 'Billable %', render: (r) => `${r.billable_pct ?? 0}%` },
    { key: 'jobs_completed', header: 'Jobs', render: (r) => r.jobs_completed },
    { key: 'total_revenue_rupees', header: 'Revenue (Rs)', render: (r) => r.total_revenue_rupees },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Type', render: (r) => r.action_type },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'action_summary', header: 'Summary', render: (r) => r.action_summary },
    { key: 'expected_minutes_saved', header: 'Mins saved', render: (r) => r.expected_minutes_saved },
    { key: 'expected_rupees_saved', header: 'Rs saved', render: (r) => r.expected_rupees_saved },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'created_at', header: 'Created', render: (r) => r.created_at },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer Travel vs Billable Time
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Last 30 days — how much of engineer shift hours go to driving vs actual billable work, sliced by city & region.
      </p>

      {k ? (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Engineers tracked</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.engineers_tracked}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Travel %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.travel_pct ?? 0}%</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Billable %</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.billable_pct ?? 0}%</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Total shift hrs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_shift_hours}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Travel hrs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_travel_hours}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Billable hrs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_billable_hours}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Distance (km)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_distance_km}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Fuel cost (Rs)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_fuel_cost_rupees}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Revenue (Rs)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.total_revenue_rupees}</div>
          </div>
          <div style={{ padding: 12, border: '1px solid #eee', borderRadius: 8 }}>
            <div style={{ color: '#666', fontSize: 12 }}>Open actions</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{k.open_optimization_actions}</div>
          </div>
        </section>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>City breakdown</h2>
        <DataTable
          rows={(cities.data as any[]) ?? []}
          columns={cityCols}
          emptyMessage="No city data yet."
          rowKey={(r) => `${r.region}-${r.city}`}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Region rollup</h2>
        <DataTable
          rows={(regions.data as any[]) ?? []}
          columns={regionCols}
          emptyMessage="No region data yet."
          rowKey={(r) => r.region}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Worst offenders — travel-heavy engineers
        </h2>
        <DataTable
          rows={(worst.data as any[]) ?? []}
          columns={worstCols}
          emptyMessage="No offenders detected."
          rowKey={(r) => r.engineer_id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top performers — highest billable %</h2>
        <DataTable
          rows={(top.data as any[]) ?? []}
          columns={topCols}
          emptyMessage="No performers tracked."
          rowKey={(r) => r.engineer_id}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Daily trend (last 30 days)</h2>
        <DataTable
          rows={(trend.data as any[]) ?? []}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r) => String(r.log_date)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Optimization actions</h2>
        <DataTable
          rows={(actions.data as any[]) ?? []}
          columns={actionCols}
          emptyMessage="No actions logged."
          rowKey={(r) => r.id}
        />
      </section>
    </main>
  );
}
