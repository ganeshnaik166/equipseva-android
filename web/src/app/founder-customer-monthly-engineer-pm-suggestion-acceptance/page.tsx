import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = { metric: string; value: string };
type SuggestionRow = {
  id: string;
  suggested_at: string;
  customer_org_name: string;
  city: string;
  device_model: string;
  pm_task_summary: string;
  estimated_rupees: number;
  urgency: string;
  status: string;
  engineer_tier: string;
};
type CityRow = { city: string; total: number; accepted: number; acceptance_rate: number; avg_lag_hours: number };
type TierRow = { engineer_tier: string; total: number; accepted: number; acceptance_rate: number; total_value_rupees: number };
type OutcomeRow = {
  customer_org_name: string;
  city: string;
  outcome_month: string;
  total_suggestions: number;
  accepted_count: number;
  revenue_realized_rupees: number;
  revenue_lost_rupees: number;
  csat_score: number;
  retention_signal: string;
};
type AtRiskRow = {
  customer_org_name: string;
  city: string;
  retention_signal: string;
  total_suggestions: number;
  accepted_count: number;
  declined_count: number;
  expired_count: number;
  revenue_lost_rupees: number;
  csat_score: number;
};
type UrgencyRow = {
  urgency: string;
  total: number;
  accepted: number;
  declined: number;
  pending: number;
  expired: number;
  conversion_pct: number;
};
type DeviceRow = {
  device_category: string;
  total_suggested: number;
  total_accepted: number;
  accepted_value_rupees: number;
  lost_value_rupees: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    kpiRes,
    recentRes,
    cityRes,
    tierRes,
    outcomesRes,
    atRiskRes,
    urgencyRes,
    deviceRes,
  ] = await Promise.all([
    supabase.rpc('r2904_kpi_summary'),
    supabase.rpc('r2904_recent_suggestions'),
    supabase.rpc('r2904_acceptance_by_city'),
    supabase.rpc('r2904_acceptance_by_tier'),
    supabase.rpc('r2904_customer_outcomes'),
    supabase.rpc('r2904_at_risk_customers'),
    supabase.rpc('r2904_urgency_funnel'),
    supabase.rpc('r2904_revenue_by_device_category'),
  ]);

  const kpis: KpiRow[] = (kpiRes.data as KpiRow[]) ?? [];
  const recent: SuggestionRow[] = (recentRes.data as SuggestionRow[]) ?? [];
  const byCity: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const byTier: TierRow[] = (tierRes.data as TierRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomesRes.data as OutcomeRow[]) ?? [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[]) ?? [];
  const urgency: UrgencyRow[] = (urgencyRes.data as UrgencyRow[]) ?? [];
  const devices: DeviceRow[] = (deviceRes.data as DeviceRow[]) ?? [];

  const recentCols: Column<SuggestionRow>[] = [
    { key: 'suggested_at', header: 'Suggested', render: (r) => new Date(r.suggested_at).toLocaleString() },
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'device_model', header: 'Device', render: (r) => r.device_model },
    { key: 'pm_task_summary', header: 'PM Task', render: (r) => r.pm_task_summary },
    { key: 'estimated_rupees', header: 'Est. (₹)', render: (r) => r.estimated_rupees.toLocaleString('en-IN') },
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'status', header: 'Status', render: (r) => r.status },
    { key: 'engineer_tier', header: 'Tier', render: (r) => r.engineer_tier },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
    { key: 'acceptance_rate', header: 'Accept %', render: (r) => `${r.acceptance_rate ?? 0}%` },
    { key: 'avg_lag_hours', header: 'Avg Lag (h)', render: (r) => r.avg_lag_hours ?? '—' },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'engineer_tier', header: 'Engineer Tier', render: (r) => r.engineer_tier },
    { key: 'total', header: 'Suggested', render: (r) => r.total },
    { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
    { key: 'acceptance_rate', header: 'Accept %', render: (r) => `${r.acceptance_rate ?? 0}%` },
    { key: 'total_value_rupees', header: 'Accepted Value (₹)', render: (r) => (r.total_value_rupees ?? 0).toLocaleString('en-IN') },
  ];

  const outcomeCols: Column<OutcomeRow>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'outcome_month', header: 'Month', render: (r) => r.outcome_month },
    { key: 'total_suggestions', header: 'Suggested', render: (r) => r.total_suggestions },
    { key: 'accepted_count', header: 'Accepted', render: (r) => r.accepted_count },
    { key: 'revenue_realized_rupees', header: 'Realized (₹)', render: (r) => r.revenue_realized_rupees.toLocaleString('en-IN') },
    { key: 'revenue_lost_rupees', header: 'Lost (₹)', render: (r) => r.revenue_lost_rupees.toLocaleString('en-IN') },
    { key: 'csat_score', header: 'CSAT', render: (r) => r.csat_score },
    { key: 'retention_signal', header: 'Signal', render: (r) => r.retention_signal },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'customer_org_name', header: 'Customer', render: (r) => r.customer_org_name },
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'retention_signal', header: 'Signal', render: (r) => r.retention_signal },
    { key: 'total_suggestions', header: 'Suggested', render: (r) => r.total_suggestions },
    { key: 'accepted_count', header: 'Accepted', render: (r) => r.accepted_count },
    { key: 'declined_count', header: 'Declined', render: (r) => r.declined_count },
    { key: 'expired_count', header: 'Expired', render: (r) => r.expired_count },
    { key: 'revenue_lost_rupees', header: 'Lost (₹)', render: (r) => r.revenue_lost_rupees.toLocaleString('en-IN') },
    { key: 'csat_score', header: 'CSAT', render: (r) => r.csat_score },
  ];

  const urgencyCols: Column<UrgencyRow>[] = [
    { key: 'urgency', header: 'Urgency', render: (r) => r.urgency },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'accepted', header: 'Accepted', render: (r) => r.accepted },
    { key: 'declined', header: 'Declined', render: (r) => r.declined },
    { key: 'pending', header: 'Pending', render: (r) => r.pending },
    { key: 'expired', header: 'Expired', render: (r) => r.expired },
    { key: 'conversion_pct', header: 'Conversion %', render: (r) => `${r.conversion_pct ?? 0}%` },
  ];

  const deviceCols: Column<DeviceRow>[] = [
    { key: 'device_category', header: 'Device Category', render: (r) => r.device_category },
    { key: 'total_suggested', header: 'Suggested', render: (r) => r.total_suggested },
    { key: 'total_accepted', header: 'Accepted', render: (r) => r.total_accepted },
    { key: 'accepted_value_rupees', header: 'Accepted (₹)', render: (r) => r.accepted_value_rupees.toLocaleString('en-IN') },
    { key: 'lost_value_rupees', header: 'Lost (₹)', render: (r) => r.lost_value_rupees.toLocaleString('en-IN') },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, fontWeight: 700, marginBottom: 6 }}>
        Customer Monthly Engineer-Initiated PM Suggestion Acceptance
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Round r2904 · Batch 400 milestone · track how customers respond to engineer-initiated
        preventive-maintenance suggestions & the revenue + retention impact.
      </p>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>KPI Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
          {kpis.map((k) => (
            <div key={k.metric} style={{ border: '1px solid #e2e2e2', borderRadius: 8, padding: 12, background: '#fafafa' }}>
              <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.4 }}>{k.metric.replace(/_/g, ' ')}</div>
              <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Recent PM Suggestions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No recent suggestions."
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Acceptance by City</h2>
        <DataTable
          rows={byCity}
          columns={cityCols}
          emptyMessage="No city rollups."
          rowKey={(r, i) => String(r.city ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Acceptance by Engineer Tier</h2>
        <DataTable
          rows={byTier}
          columns={tierCols}
          emptyMessage="No tier rollups."
          rowKey={(r, i) => String(r.engineer_tier ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Customer Monthly Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes yet."
          rowKey={(r, i) => `${r.customer_org_name}-${r.outcome_month}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>At-Risk & Churning Customers</h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          emptyMessage="No at-risk customers — strong acceptance everywhere."
          rowKey={(r, i) => `${r.customer_org_name}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Urgency Funnel</h2>
        <DataTable
          rows={urgency}
          columns={urgencyCols}
          emptyMessage="No urgency data."
          rowKey={(r, i) => String(r.urgency ?? i)}
        />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Revenue by Device Category</h2>
        <DataTable
          rows={devices}
          columns={deviceCols}
          emptyMessage="No device rollups."
          rowKey={(r, i) => String(r.device_category ?? i)}
        />
      </section>
    </div>
  );
}
