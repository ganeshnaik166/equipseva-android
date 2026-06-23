import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainKeyAccountHealthScorePage() {
  const supabase = await getSupabaseServerClient();

  const [
    snapshotsRes,
    plansRes,
    redFocusRes,
    distributionRes,
    renewalRiskRes,
    engagementRes,
    trendRes,
  ] = await Promise.all([
    supabase.rpc('list_snapshots_r2447'),
    supabase.rpc('list_intervention_plans_r2447'),
    supabase.rpc('red_focus_r2447'),
    supabase.rpc('health_label_distribution_r2447'),
    supabase.rpc('top_renewal_risk_r2447'),
    supabase.rpc('top_engagement_chains_r2447'),
    supabase.rpc('monthly_composite_trend_r2447'),
  ]);

  const snapshots = (snapshotsRes.data ?? []) as any[];
  const plans = (plansRes.data ?? []) as any[];
  const redFocus = (redFocusRes.data ?? []) as any[];
  const distribution = (distributionRes.data ?? []) as any[];
  const renewalRisk = (renewalRiskRes.data ?? []) as any[];
  const engagement = (engagementRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const fmtRupees = (v: number | null | undefined) => {
    if (v === null || v === undefined) return '-';
    return '₹' + Number(v).toLocaleString('en-IN');
  };

  const labelBadge = (label: string | null | undefined) => {
    const colors: Record<string, string> = {
      red:   '#fee2e2',
      amber: '#fef3c7',
      green: '#dcfce7',
      super: '#dbeafe',
    };
    const c = colors[label ?? ''] ?? '#f3f4f6';
    return (
      <span style={{ background: c, padding: '2px 8px', borderRadius: 4, fontSize: 12, textTransform: 'uppercase' }}>
        {label ?? '-'}
      </span>
    );
  };

  const snapshotsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'snapshot_date', header: 'Date', render: (r: any) => r.snapshot_date },
    { key: 'health_composite', header: 'Composite', render: (r: any) => r.health_composite },
    { key: 'health_label', header: 'Label', render: (r: any) => labelBadge(r.health_label) },
    { key: 'nps', header: 'NPS', render: (r: any) => r.nps },
    { key: 'mrr_rupees', header: 'MRR', render: (r: any) => fmtRupees(r.mrr_rupees) },
    { key: 'ticket_count_30d', header: 'Tickets 30d', render: (r: any) => r.ticket_count_30d },
    { key: 'avg_resolution_hours', header: 'Avg res (h)', render: (r: any) => Number(r.avg_resolution_hours ?? 0).toFixed(1) },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => r.engagement_score },
    { key: 'renewal_probability_pct', header: 'Renewal %', render: (r: any) => r.renewal_probability_pct },
    { key: 'top_risk', header: 'Top risk', render: (r: any) => r.top_risk ?? '-' },
    { key: 'top_opportunity', header: 'Top opp', render: (r: any) => r.top_opportunity ?? '-' },
  ];

  const plansCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleDateString() : '-' },
    { key: 'current_health_label', header: 'Now', render: (r: any) => labelBadge(r.current_health_label) },
    { key: 'target_health_label', header: 'Target', render: (r: any) => labelBadge(r.target_health_label) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'action_due_at', header: 'Due', render: (r: any) => r.action_due_at ? new Date(r.action_due_at).toLocaleDateString() : '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'recommended_action_md', header: 'Action', render: (r: any) => <span style={{ whiteSpace: 'pre-wrap', fontSize: 12 }}>{r.recommended_action_md}</span> },
  ];

  const redFocusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'health_label', header: 'Label', render: (r: any) => labelBadge(r.health_label) },
    { key: 'health_composite', header: 'Composite', render: (r: any) => r.health_composite },
    { key: 'mrr_rupees', header: 'MRR at risk', render: (r: any) => fmtRupees(r.mrr_rupees) },
    { key: 'top_risk', header: 'Top risk', render: (r: any) => r.top_risk ?? '-' },
    { key: 'snapshot_date', header: 'As of', render: (r: any) => r.snapshot_date },
  ];

  const distributionCols: Column<any>[] = [
    { key: 'health_label', header: 'Label', render: (r: any) => labelBadge(r.health_label) },
    { key: 'chain_count', header: 'Chains', render: (r: any) => r.chain_count },
    { key: 'total_mrr_rupees', header: 'Total MRR', render: (r: any) => fmtRupees(r.total_mrr_rupees) },
  ];

  const renewalCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'renewal_probability_pct', header: 'Renewal %', render: (r: any) => r.renewal_probability_pct },
    { key: 'mrr_rupees', header: 'MRR', render: (r: any) => fmtRupees(r.mrr_rupees) },
    { key: 'health_label', header: 'Label', render: (r: any) => labelBadge(r.health_label) },
    { key: 'top_risk', header: 'Top risk', render: (r: any) => r.top_risk ?? '-' },
  ];

  const engagementCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'engagement_score', header: 'Engagement', render: (r: any) => r.engagement_score },
    { key: 'nps', header: 'NPS', render: (r: any) => r.nps },
    { key: 'health_label', header: 'Label', render: (r: any) => labelBadge(r.health_label) },
    { key: 'top_opportunity', header: 'Top opp', render: (r: any) => r.top_opportunity ?? '-' },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start },
    { key: 'avg_composite', header: 'Avg composite', render: (r: any) => r.avg_composite },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps },
    { key: 'chains_tracked', header: 'Chains tracked', render: (r: any) => r.chains_tracked },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Hospital Chain Key Account Health Score
      </h1>
      <p style={{ color: '#666', marginBottom: 24, fontSize: 14 }}>
        Chain × NPS × MRR × tickets × engagement × renewal probability => composite health label
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Health label distribution</h2>
        <DataTable
          rows={distribution}
          columns={distributionCols}
          emptyMessage="No snapshots yet"
          rowKey={(r: any, i: number) => String(r.health_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Red & amber focus list</h2>
        <DataTable
          rows={redFocus}
          columns={redFocusCols}
          emptyMessage="All chains healthy"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top renewal risk</h2>
        <DataTable
          rows={renewalRisk}
          columns={renewalCols}
          emptyMessage="No renewal-risk chains"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top engagement chains</h2>
        <DataTable
          rows={engagement}
          columns={engagementCols}
          emptyMessage="No engagement data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Monthly composite trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All chain health snapshots</h2>
        <DataTable
          rows={snapshots}
          columns={snapshotsCols}
          emptyMessage="No snapshots yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Intervention plans</h2>
        <DataTable
          rows={plans}
          columns={plansCols}
          emptyMessage="No intervention plans"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
