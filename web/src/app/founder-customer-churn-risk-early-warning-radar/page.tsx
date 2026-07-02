import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [overviewR, signalsR, criticalR, actionsR, bandsR, actionTypesR, followupsR] = await Promise.all([
    sb.rpc('founder_churn_radar_overview_r2233'),
    sb.rpc('founder_churn_radar_signals_r2233'),
    sb.rpc('founder_churn_radar_critical_r2233'),
    sb.rpc('founder_churn_radar_actions_r2233'),
    sb.rpc('founder_churn_radar_by_band_r2233'),
    sb.rpc('founder_churn_radar_action_types_r2233'),
    sb.rpc('founder_churn_radar_followups_r2233'),
  ]);

  const overview = (overviewR.data?.[0] ?? {}) as any;
  const signals = (signalsR.data ?? []) as any[];
  const critical = (criticalR.data ?? []) as any[];
  const actions = (actionsR.data ?? []) as any[];
  const bands = (bandsR.data ?? []) as any[];
  const actionTypes = (actionTypesR.data ?? []) as any[];
  const followups = (followupsR.data ?? []) as any[];

  const signalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '') },
    { key: 'risk_band', header: 'Band', render: (r: any) => String(r.risk_band ?? '') },
    { key: 'composite_risk_score', header: 'Score', render: (r: any) => String(r.composite_risk_score ?? '') },
    { key: 'usage_drop_pct', header: 'Usage Drop %', render: (r: any) => String(r.usage_drop_pct ?? '') },
    { key: 'open_complaints', header: 'Complaints', render: (r: any) => String(r.open_complaints ?? '') },
    { key: 'payment_delay_days', header: 'Pay Delay', render: (r: any) => String(r.payment_delay_days ?? '') },
    { key: 'nps_drop_points', header: 'NPS Drop', render: (r: any) => String(r.nps_drop_points ?? '') },
    { key: 'monthly_revenue_rupees', header: 'MRR', render: (r: any) => String(r.monthly_revenue_rupees ?? '') },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_type', header: 'Type', render: (r: any) => String(r.action_type ?? '') },
    { key: 'action_summary', header: 'Summary', render: (r: any) => String(r.action_summary ?? '') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => String(r.outcome ?? '') },
    { key: 'action_at', header: 'When', render: (r: any) => String(r.action_at ?? '') },
  ];

  const bandCols: Column<any>[] = [
    { key: 'risk_band', header: 'Band', render: (r: any) => String(r.risk_band ?? '') },
    { key: 'hospital_count', header: 'Hospitals', render: (r: any) => String(r.hospital_count ?? '') },
    { key: 'total_revenue_rupees', header: 'Revenue', render: (r: any) => String(r.total_revenue_rupees ?? '') },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => String(r.avg_score ?? '') },
  ];

  const typeCols: Column<any>[] = [
    { key: 'action_type', header: 'Action Type', render: (r: any) => String(r.action_type ?? '') },
    { key: 'action_count', header: 'Count', render: (r: any) => String(r.action_count ?? '') },
    { key: 'latest_at', header: 'Latest', render: (r: any) => String(r.latest_at ?? '') },
  ];

  const followupCols: Column<any>[] = [
    { key: 'action_type', header: 'Type', render: (r: any) => String(r.action_type ?? '') },
    { key: 'action_summary', header: 'Summary', render: (r: any) => String(r.action_summary ?? '') },
    { key: 'follow_up_at', header: 'Follow Up', render: (r: any) => String(r.follow_up_at ?? '') },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1>Customer Churn Risk — Early Warning Radar</h1>
      <p>Composite churn score per hospital &gt; usage drop &amp; complaints &amp; payment delays &amp; NPS drop. Founder action log tracks every save play.</p>

      <h2>Overview</h2>
      <ul>
        <li>Total at risk: {String(overview.total_at_risk ?? 0)}</li>
        <li>Critical: {String(overview.critical_count ?? 0)}</li>
        <li>High: {String(overview.high_count ?? 0)}</li>
        <li>Medium: {String(overview.medium_count ?? 0)}</li>
        <li>Low: {String(overview.low_count ?? 0)}</li>
        <li>Revenue at risk (rupees): {String(overview.revenue_at_risk_rupees ?? 0)}</li>
        <li>Avg risk score: {String(overview.avg_risk_score ?? 0)}</li>
      </ul>

      <h2>Critical Watch — immediate save needed</h2>
      <DataTable columns={signalCols} rows={critical} rowKey={(_, i) => String(i)} />

      <h2>All Signals (Top 200)</h2>
      <DataTable columns={signalCols} rows={signals} rowKey={(_, i) => String(i)} />

      <h2>Risk Band Rollup</h2>
      <DataTable columns={bandCols} rows={bands} rowKey={(_, i) => String(i)} />

      <h2>Founder Action Log</h2>
      <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />

      <h2>Action Type Mix</h2>
      <DataTable columns={typeCols} rows={actionTypes} rowKey={(_, i) => String(i)} />

      <h2>Upcoming Follow-ups</h2>
      <DataTable columns={followupCols} rows={followups} rowKey={(_, i) => String(i)} />
    </div>
  );
}
