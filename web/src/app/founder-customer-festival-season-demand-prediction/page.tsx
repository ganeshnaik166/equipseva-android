import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerFestivalSeasonDemandPredictionPage() {
  const supabase = await getSupabaseServerClient();

  const [
    demandRes,
    actionsRes,
    topLiftRes,
    funnelRes,
    readinessRes,
    trendRes,
    topHospitalsRes,
  ] = await Promise.all([
    supabase.rpc('list_demand_r2572'),
    supabase.rpc('list_prep_actions_r2572'),
    supabase.rpc('top_lift_festivals_r2572'),
    supabase.rpc('prep_status_funnel_r2572'),
    supabase.rpc('inventory_readiness_summary_r2572'),
    supabase.rpc('monthly_action_trend_r2572'),
    supabase.rpc('top_hospitals_by_demand_r2572'),
  ]);

  const demand = (demandRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const topLift = (topLiftRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const readiness = (readinessRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const topHospitals = (topHospitalsRes.data ?? []) as any[];

  const demandCols: Column<any>[] = [
    { key: 'festival_label', header: 'Festival', render: (r: any) => r.festival_label },
    { key: 'prior_year_demand_count', header: 'Prior Year', render: (r: any) => r.prior_year_demand_count },
    { key: 'predicted_demand_count', header: 'Predicted', render: (r: any) => r.predicted_demand_count },
    { key: 'demand_lift_pct', header: 'Lift %', render: (r: any) => r.demand_lift_pct },
    { key: 'inventory_readiness_pct', header: 'Inventory Ready %', render: (r: any) => r.inventory_readiness_pct },
    { key: 'engineer_prep_count', header: 'Engineer Prep', render: (r: any) => r.engineer_prep_count },
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'festival_label', header: 'Festival', render: (r: any) => r.festival_label },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topLiftCols: Column<any>[] = [
    { key: 'festival_label', header: 'Festival', render: (r: any) => r.festival_label },
    { key: 'prior_year_demand_count', header: 'Prior Year', render: (r: any) => r.prior_year_demand_count },
    { key: 'predicted_demand_count', header: 'Predicted', render: (r: any) => r.predicted_demand_count },
    { key: 'demand_lift_pct', header: 'Lift %', render: (r: any) => r.demand_lift_pct },
    { key: 'inventory_readiness_pct', header: 'Inventory Ready %', render: (r: any) => r.inventory_readiness_pct },
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'prep_status', header: 'Prep Status', render: (r: any) => r.prep_status },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
    { key: 'avg_lift_pct', header: 'Avg Lift %', render: (r: any) => r.avg_lift_pct },
    { key: 'avg_readiness', header: 'Avg Readiness %', render: (r: any) => r.avg_readiness },
    { key: 'total_engineer_prep', header: 'Total Engineer Prep', render: (r: any) => r.total_engineer_prep },
  ];

  const readinessCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'cnt', header: 'Count', render: (r: any) => r.cnt },
    { key: 'avg_readiness', header: 'Avg Readiness %', render: (r: any) => r.avg_readiness },
    { key: 'min_readiness', header: 'Min Readiness %', render: (r: any) => r.min_readiness },
    { key: 'max_readiness', header: 'Max Readiness %', render: (r: any) => r.max_readiness },
    { key: 'avg_lift_pct', header: 'Avg Lift %', render: (r: any) => r.avg_lift_pct },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'cnt', header: 'Actions', render: (r: any) => r.cnt },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
  ];

  const topHospitalsCols: Column<any>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '-' },
    { key: 'festival_count', header: 'Festivals', render: (r: any) => r.festival_count },
    { key: 'total_predicted', header: 'Total Predicted', render: (r: any) => r.total_predicted },
    { key: 'total_prior', header: 'Total Prior', render: (r: any) => r.total_prior },
    { key: 'avg_lift_pct', header: 'Avg Lift %', render: (r: any) => r.avg_lift_pct },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Customer Festival Season Demand Prediction
      </h1>
      <p style={{ color: '#555', marginBottom: '24px' }}>
        Hospital & festival × prior-year vs predicted demand × inventory readiness & engineer prep.
        Drives extra-inventory / cross-train / shift-plan / courier-priority / communication actions before each surge.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Festival Demand Forecast</h2>
        <DataTable
          rows={demand}
          columns={demandCols}
          emptyMessage="No festival demand rows yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Engineer Prep Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No prep actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Lift Festivals</h2>
        <DataTable
          rows={topLift}
          columns={topLiftCols}
          emptyMessage="No festivals ranked"
          rowKey={(r: any, i: number) => String(r.festival_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Prep Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No prep funnel data"
          rowKey={(r: any, i: number) => String(r.prep_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Inventory Readiness Summary</h2>
        <DataTable
          rows={readiness}
          columns={readinessCols}
          emptyMessage="No readiness data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Monthly Action Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No monthly action trend"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '20px', fontWeight: 600, marginBottom: '12px' }}>Top Hospitals by Demand</h2>
        <DataTable
          rows={topHospitals}
          columns={topHospitalsCols}
          emptyMessage="No hospitals ranked"
          rowKey={(r: any, i: number) => String(r.hospital_user_id ?? i)}
        />
      </section>
    </div>
  );
}
