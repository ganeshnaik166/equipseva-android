import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [risksRes, actionsRes, focusRes, distRes, funnelRes, trendRes, ownerRes] = await Promise.all([
    supabase.rpc('list_renewal_risk_r2659'),
    supabase.rpc('list_mitigation_actions_r2659'),
    supabase.rpc('top_critical_focus_r2659'),
    supabase.rpc('risk_distribution_r2659'),
    supabase.rpc('status_funnel_r2659'),
    supabase.rpc('quarterly_risk_trend_r2659'),
    supabase.rpc('owner_load_r2659'),
  ]);

  const risks = (risksRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const dist = (distRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const ownerLoad = (ownerRes.data ?? []) as any[];

  const fmt = (s: string | null | undefined) =>
    s ? new Date(s).toISOString().slice(0, 10) : '';

  const riskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'renewal_due_at', header: 'Renewal Due', render: (r: any) => fmt(r.renewal_due_at) },
    { key: 'risk_kind', header: 'Risk', render: (r: any) => r.risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_at', header: 'When', render: (r: any) => fmt(r.action_at) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'renewal_due_at', header: 'Due', render: (r: any) => fmt(r.renewal_due_at) },
    { key: 'risk_kind', header: 'Risk', render: (r: any) => r.risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => String(r.open_actions ?? 0) },
  ];

  const distCols: Column<any>[] = [
    { key: 'risk_kind', header: 'Risk Kind', render: (r: any) => r.risk_kind },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Total', render: (r: any) => String(r.total ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
    { key: 'high_count', header: 'High', render: (r: any) => String(r.high_count ?? 0) },
    { key: 'medium_count', header: 'Medium', render: (r: any) => String(r.medium_count ?? 0) },
    { key: 'low_count', header: 'Low', render: (r: any) => String(r.low_count ?? 0) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'active_risks', header: 'Active Risks', render: (r: any) => String(r.active_risks ?? 0) },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => String(r.open_actions ?? 0) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 22, fontWeight: 600, marginBottom: 6 }}>
        Hospital Chain Quarterly Renewal Risk Radar
      </h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track chain renewals at risk &gt; intervene early &gt; protect ARR.
      </p>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>Top Critical Focus</h2>
      <DataTable
        rows={focus}
        columns={focusCols}
        emptyMessage="No critical chains in focus."
        rowKey={(r: any, i: number) => String(r.id ?? `${r.chain_name}-${i}`)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>Risk Distribution</h2>
      <DataTable
        rows={dist}
        columns={distCols}
        emptyMessage="No risks logged."
        rowKey={(r: any, i: number) => String(r.risk_kind ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>Status Funnel</h2>
      <DataTable
        rows={funnel}
        columns={funnelCols}
        emptyMessage="No status data."
        rowKey={(r: any, i: number) => String(r.status ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>Quarterly Risk Trend</h2>
      <DataTable
        rows={trend}
        columns={trendCols}
        emptyMessage="No quarters logged."
        rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>Owner Load</h2>
      <DataTable
        rows={ownerLoad}
        columns={ownerCols}
        emptyMessage="No owners assigned."
        rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>All Renewal Risks</h2>
      <DataTable
        rows={risks}
        columns={riskCols}
        emptyMessage="No risks logged."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '20px 0 8px' }}>Mitigation Actions</h2>
      <DataTable
        rows={actions}
        columns={actionCols}
        emptyMessage="No mitigation actions logged."
        rowKey={(r: any, i: number) => String(r.id ?? i)}
      />
    </div>
  );
}
