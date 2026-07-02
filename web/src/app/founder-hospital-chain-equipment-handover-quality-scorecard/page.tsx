import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderHospitalChainEquipmentHandoverQualityScorecardPage() {
  const supabase = await getSupabaseServerClient();

  const [handovers, disputes, lowFocus, kindBreakdown, topChains, monthly, engineerSummary] = await Promise.all([
    supabase.rpc('list_handover_quality_r2555'),
    supabase.rpc('list_dispute_resolutions_r2555'),
    supabase.rpc('low_completeness_focus_r2555'),
    supabase.rpc('dispute_kind_breakdown_r2555'),
    supabase.rpc('top_chains_by_quality_r2555'),
    supabase.rpc('monthly_quality_trend_r2555'),
    supabase.rpc('engineer_quality_summary_r2555'),
  ]);

  const handoverCols: Column<any>[] = [
    { key: 'handover_at', header: 'Handover', render: (r: any) => new Date(r.handover_at).toLocaleDateString() },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'completeness_pct', header: 'Complete', render: (r: any) => `${r.completeness_pct}%` },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => `${r.csat_score}/10` },
    { key: 'dispute_risk_kind', header: 'Risk', render: (r: any) => r.dispute_risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'top_gap', header: 'Top gap', render: (r: any) => r.top_gap ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const disputeCols: Column<any>[] = [
    { key: 'opened_at', header: 'Opened', render: (r: any) => new Date(r.opened_at).toLocaleDateString() },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'dispute_kind', header: 'Kind', render: (r: any) => r.dispute_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => r.resolved_at ? new Date(r.resolved_at).toLocaleDateString() : '—' },
    { key: 'resolution_summary', header: 'Summary', render: (r: any) => r.resolution_summary ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const lowFocusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'completeness_pct', header: 'Complete', render: (r: any) => `${r.completeness_pct}%` },
    { key: 'csat_score', header: 'CSAT', render: (r: any) => `${r.csat_score}/10` },
    { key: 'dispute_risk_kind', header: 'Risk', render: (r: any) => r.dispute_risk_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'top_gap', header: 'Top gap', render: (r: any) => r.top_gap ?? '—' },
    { key: 'handover_at', header: 'Handover', render: (r: any) => new Date(r.handover_at).toLocaleDateString() },
  ];

  const kindCols: Column<any>[] = [
    { key: 'dispute_kind', header: 'Kind', render: (r: any) => r.dispute_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => r.total_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'closed_count', header: 'Closed', render: (r: any) => r.closed_count },
    { key: 'avg_days_to_resolve', header: 'Avg days to resolve', render: (r: any) => r.avg_days_to_resolve ?? '—' },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'handover_count', header: 'Handovers', render: (r: any) => r.handover_count },
    { key: 'avg_completeness', header: 'Avg complete', render: (r: any) => `${r.avg_completeness}%` },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => `${r.avg_csat}/10` },
    { key: 'red_count', header: 'Red', render: (r: any) => r.red_count },
    { key: 'critical_risk_count', header: 'Critical risk', render: (r: any) => r.critical_risk_count },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'handover_count', header: 'Handovers', render: (r: any) => r.handover_count },
    { key: 'avg_completeness', header: 'Avg complete', render: (r: any) => `${r.avg_completeness}%` },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => `${r.avg_csat}/10` },
    { key: 'red_count', header: 'Red', render: (r: any) => r.red_count },
  ];

  const engineerCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer id', render: (r: any) => r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '—' },
    { key: 'cached_highest_tier', header: 'Tier', render: (r: any) => r.cached_highest_tier ?? '—' },
    { key: 'handover_count', header: 'Handovers', render: (r: any) => r.handover_count },
    { key: 'avg_completeness', header: 'Avg complete', render: (r: any) => `${r.avg_completeness}%` },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => `${r.avg_csat}/10` },
    { key: 'red_count', header: 'Red', render: (r: any) => r.red_count },
    { key: 'critical_risk_count', header: 'Critical', render: (r: any) => r.critical_risk_count },
  ];

  return (
    <div style={{ padding: '2rem', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Hospital Chain — Equipment Handover Quality Scorecard
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Chain > equipment handover > completeness > engineer > CSAT > dispute risk.
        Tracks every handover quality signal so red ones never reach the chain CXO before we do.
      </p>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>All handovers</h2>
        <DataTable
          rows={handovers.data ?? []}
          columns={handoverCols}
          emptyMessage="No handovers logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Open & closed disputes</h2>
        <DataTable
          rows={disputes.data ?? []}
          columns={disputeCols}
          emptyMessage="No disputes logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Low completeness focus (< 80%)
        </h2>
        <DataTable
          rows={lowFocus.data ?? []}
          columns={lowFocusCols}
          emptyMessage="No low-completeness handovers"
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Dispute kind breakdown</h2>
        <DataTable
          rows={kindBreakdown.data ?? []}
          columns={kindCols}
          emptyMessage="No dispute data"
          rowKey={(r: any, i: number) => String(r.dispute_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Top chains by quality</h2>
        <DataTable
          rows={topChains.data ?? []}
          columns={chainCols}
          emptyMessage="No chain data"
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Monthly quality trend</h2>
        <DataTable
          rows={monthly.data ?? []}
          columns={monthlyCols}
          emptyMessage="No monthly data"
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>Engineer quality summary</h2>
        <DataTable
          rows={engineerSummary.data ?? []}
          columns={engineerCols}
          emptyMessage="No engineer data"
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>
    </div>
  );
}
