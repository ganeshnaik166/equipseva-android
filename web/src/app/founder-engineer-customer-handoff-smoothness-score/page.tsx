import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerCustomerHandoffSmoothnessScorePage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  const [overview, recent, distribution, atRisk, signals, retention, performers] = await Promise.all([
    supabase.rpc('r2378_handoff_overview'),
    supabase.rpc('r2378_recent_handoffs', { p_limit: 50 }),
    supabase.rpc('r2378_smoothness_distribution'),
    supabase.rpc('r2378_at_risk_handoffs'),
    supabase.rpc('r2378_signal_breakdown'),
    supabase.rpc('r2378_retention_impact'),
    supabase.rpc('r2378_top_handoff_performers'),
  ]);

  const kpi = (overview.data && overview.data[0]) || {};

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => <span>{r.hospital_name}</span> },
    { key: 'outgoing_engineer_email', header: 'Outgoing', render: (r) => <span>{r.outgoing_engineer_email}</span> },
    { key: 'incoming_engineer_email', header: 'Incoming', render: (r) => <span>{r.incoming_engineer_email}</span> },
    { key: 'reason', header: 'Reason', render: (r) => <span>{r.reason}</span> },
    { key: 'handoff_status', header: 'Status', render: (r) => <span>{r.handoff_status}</span> },
    { key: 'smoothness_score', header: 'Score', render: (r) => <span>{r.smoothness_score}</span> },
    { key: 'service_gap_hours', header: 'Gap (hrs)', render: (r) => <span>{r.service_gap_hours}</span> },
    { key: 'customer_blind', header: 'Blind?', render: (r) => <span>{r.customer_blind ? 'yes' : 'no'}</span> },
    { key: 'retention_status', header: 'Retention', render: (r) => <span>{r.retention_status}</span> },
  ];

  const distCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r) => <span>{r.bucket}</span> },
    { key: 'handoff_count', header: 'Count', render: (r) => <span>{r.handoff_count}</span> },
    { key: 'pct_of_total', header: '% of total', render: (r) => <span>{r.pct_of_total}%</span> },
  ];

  const riskCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r) => <span>{r.hospital_name}</span> },
    { key: 'outgoing_engineer_email', header: 'Outgoing', render: (r) => <span>{r.outgoing_engineer_email}</span> },
    { key: 'incoming_engineer_email', header: 'Incoming', render: (r) => <span>{r.incoming_engineer_email}</span> },
    { key: 'smoothness_score', header: 'Score', render: (r) => <span>{r.smoothness_score}</span> },
    { key: 'service_gap_hours', header: 'Gap (hrs)', render: (r) => <span>{r.service_gap_hours}</span> },
    { key: 'open_tickets_at_handoff', header: 'Open tix', render: (r) => <span>{r.open_tickets_at_handoff}</span> },
    { key: 'documentation_completeness_pct', header: 'Doc %', render: (r) => <span>{r.documentation_completeness_pct}%</span> },
    { key: 'risk_reason', header: 'Risk', render: (r) => <span>{r.risk_reason}</span> },
  ];

  const signalCols: Column<any>[] = [
    { key: 'signal_kind', header: 'Signal', render: (r) => <span>{r.signal_kind}</span> },
    { key: 'total_signals', header: 'Total', render: (r) => <span>{r.total_signals}</span> },
    { key: 'unresolved_signals', header: 'Unresolved', render: (r) => <span>{r.unresolved_signals}</span> },
    { key: 'avg_weight', header: 'Avg weight', render: (r) => <span>{r.avg_weight}</span> },
  ];

  const retentionCols: Column<any>[] = [
    { key: 'reason', header: 'Reason', render: (r) => <span>{r.reason}</span> },
    { key: 'total_handoffs', header: 'Total', render: (r) => <span>{r.total_handoffs}</span> },
    { key: 'retained', header: 'Retained', render: (r) => <span>{r.retained}</span> },
    { key: 'at_risk', header: 'At risk', render: (r) => <span>{r.at_risk}</span> },
    { key: 'churned', header: 'Churned', render: (r) => <span>{r.churned}</span> },
    { key: 'retention_pct', header: 'Retain %', render: (r) => <span>{r.retention_pct}%</span> },
    { key: 'avg_smoothness', header: 'Avg score', render: (r) => <span>{r.avg_smoothness}</span> },
  ];

  const perfCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r) => <span>{r.engineer_email}</span> },
    { key: 'handoff_count', header: 'Handoffs', render: (r) => <span>{r.handoff_count}</span> },
    { key: 'avg_smoothness', header: 'Avg score', render: (r) => <span>{r.avg_smoothness}</span> },
    { key: 'avg_service_gap', header: 'Avg gap (hrs)', render: (r) => <span>{r.avg_service_gap}</span> },
    { key: 'customer_blind_count', header: 'Blind count', render: (r) => <span>{r.customer_blind_count}</span> },
    { key: 'retention_rate_pct', header: 'Retain %', render: (r) => <span>{r.retention_rate_pct}%</span> },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Customer-Handoff Smoothness Score</h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Round 2378 · HEAVY · signed in as {email}. Track engineer-to-engineer transitions at hospitals — service gap, customer awareness, retention impact.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total handoffs</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.total_handoffs ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Completed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.completed_handoffs ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>In progress</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.in_progress_handoffs ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Failed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.failed_handoffs ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg smoothness</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.avg_smoothness_score ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Avg gap (hrs)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.avg_service_gap_hours ?? 0}</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Customer-blind %</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.customer_blind_pct ?? 0}%</div>
        </div>
        <div style={{ border: '1px solid #ddd', padding: 12, borderRadius: 6 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Churn attributed</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{kpi.churn_attributed_count ?? 0} ({kpi.churn_attribution_pct ?? 0}%)</div>
        </div>
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 16, marginBottom: 8 }}>Smoothness distribution</h2>
      <DataTable
        rows={distribution.data ?? []}
        columns={distCols}
        emptyMessage="no completed handoffs yet"
        rowKey={(r: any) => r.bucket}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>At-risk in-flight handoffs</h2>
      <DataTable
        rows={atRisk.data ?? []}
        columns={riskCols}
        emptyMessage="no at-risk handoffs — all transitions look healthy"
        rowKey={(r: any) => r.id}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Recent handoffs</h2>
      <DataTable
        rows={recent.data ?? []}
        columns={recentCols}
        emptyMessage="no handoffs logged"
        rowKey={(r: any) => r.id}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Signal breakdown</h2>
      <DataTable
        rows={signals.data ?? []}
        columns={signalCols}
        emptyMessage="no signals captured"
        rowKey={(r: any) => r.signal_kind}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Retention impact by reason</h2>
      <DataTable
        rows={retention.data ?? []}
        columns={retentionCols}
        emptyMessage="no completed handoffs to analyze"
        rowKey={(r: any) => r.reason}
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top handoff performers</h2>
      <DataTable
        rows={performers.data ?? []}
        columns={perfCols}
        emptyMessage="no performer data yet"
        rowKey={(r: any) => r.engineer_email}
      />
    </div>
  );
}
