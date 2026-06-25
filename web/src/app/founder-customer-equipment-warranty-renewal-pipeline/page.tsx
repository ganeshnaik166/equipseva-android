import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [renewalsRes, outcomesRes, focusRes, funnelRes, probRes, trendRes, revenueRes] = await Promise.all([
    supabase.rpc('list_warranty_renewals_r2620'),
    supabase.rpc('list_outcomes_r2620'),
    supabase.rpc('expiring_30d_focus_r2620'),
    supabase.rpc('status_funnel_r2620'),
    supabase.rpc('win_probability_summary_r2620'),
    supabase.rpc('monthly_renewal_trend_r2620'),
    supabase.rpc('revenue_summary_r2620'),
  ]);

  const renewals = (renewalsRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const prob = (probRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const revenue = (revenueRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : '₹' + Number(n).toLocaleString('en-IN');

  const renewalCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'warranty_end_date', header: 'Warranty End', render: (r: any) => r.warranty_end_date },
    { key: 'days_to_expiry', header: 'Days to Expiry', render: (r: any) => r.days_to_expiry },
    { key: 'renewal_value_rupees', header: 'Renewal Value', render: (r: any) => fmtRupees(r.renewal_value_rupees) },
    { key: 'win_probability_pct', header: 'Win Prob %', render: (r: any) => r.win_probability_pct + '%' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'observed_at', header: 'Observed', render: (r: any) => new Date(r.observed_at).toLocaleString() },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'revenue_realized_rupees', header: 'Revenue Realized', render: (r: any) => fmtRupees(r.revenue_realized_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'warranty_end_date', header: 'End Date', render: (r: any) => r.warranty_end_date },
    { key: 'days_to_expiry', header: 'Days Left', render: (r: any) => r.days_to_expiry },
    { key: 'renewal_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.renewal_value_rupees) },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => r.win_probability_pct + '%' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'opportunity_count', header: 'Opportunities', render: (r: any) => r.opportunity_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'avg_win_probability_pct', header: 'Avg Win %', render: (r: any) => (r.avg_win_probability_pct ?? 0) + '%' },
  ];

  const probCols: Column<any>[] = [
    { key: 'probability_band', header: 'Probability Band', render: (r: any) => r.probability_band },
    { key: 'opportunity_count', header: 'Opportunities', render: (r: any) => r.opportunity_count },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'weighted_value_rupees', header: 'Weighted Value', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'observed_outcomes', header: 'Outcomes', render: (r: any) => r.observed_outcomes },
    { key: 'renewed_count', header: 'Renewed/Upgraded', render: (r: any) => r.renewed_count },
    { key: 'lapsed_count', header: 'Lapsed', render: (r: any) => r.lapsed_count },
    { key: 'revenue_realized_rupees', header: 'Revenue', render: (r: any) => fmtRupees(r.revenue_realized_rupees) },
  ];

  const revenueCols: Column<any>[] = [
    { key: 'metric_label', header: 'Metric', render: (r: any) => r.metric_label },
    { key: 'metric_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.metric_value_rupees) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Customer Equipment Warranty Renewal Pipeline
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track expiring warranties, renewal quotes, win probabilities & realized revenue. Round 2620.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Revenue Summary</h2>
        <DataTable
          rows={revenue}
          columns={revenueCols}
          emptyMessage="No revenue data."
          rowKey={(r: any, i: number) => String(r.metric_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Expiring in 30 Days (focus list)</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No renewals expiring in 30 days."
          rowKey={(r: any, i: number) => String(r.equipment_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Win Probability Bands</h2>
        <DataTable
          rows={prob}
          columns={probCols}
          emptyMessage="No probability data."
          rowKey={(r: any, i: number) => String(r.probability_band ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Monthly Renewal Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Warranty Renewals</h2>
        <DataTable
          rows={renewals}
          columns={renewalCols}
          emptyMessage="No renewals found."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Renewal Outcomes Log</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
