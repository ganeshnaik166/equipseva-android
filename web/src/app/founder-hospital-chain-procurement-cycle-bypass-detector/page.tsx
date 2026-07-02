import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [evRes, chainRes, urgRes, typeRes, auditRes, kpiRes, dispRes] = await Promise.all([
    sb.rpc('list_bypass_events_r2319'),
    sb.rpc('chain_bypass_summary_r2319'),
    sb.rpc('unreviewed_high_risk_bypasses_r2319'),
    sb.rpc('bypass_type_distribution_r2319'),
    sb.rpc('recent_bypass_audit_log_r2319'),
    sb.rpc('bypass_kpi_r2319'),
    sb.rpc('bypass_reviewer_disposition_breakdown_r2319'),
  ]);

  const events: any[] = Array.isArray(evRes.data) ? evRes.data : [];
  const chains: any[] = Array.isArray(chainRes.data) ? chainRes.data : [];
  const urgent: any[] = Array.isArray(urgRes.data) ? urgRes.data : [];
  const types: any[] = Array.isArray(typeRes.data) ? typeRes.data : [];
  const audit: any[] = Array.isArray(auditRes.data) ? auditRes.data : [];
  const kpi: any = Array.isArray(kpiRes.data) && kpiRes.data.length > 0 ? kpiRes.data[0] : {};
  const disp: any[] = Array.isArray(dispRes.data) ? dispRes.data : [];

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const fmtDate = (d: string | null | undefined) => (d ? new Date(d).toLocaleString() : '—');

  const evColumns: Column<any>[] = [
    { key: 'occurred_at', header: 'Occurred', render: (r: any) => fmtDate(r.occurred_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'bypass_type', header: 'Bypass Type', render: (r: any) => r.bypass_type },
    { key: 'bypassed_step', header: 'Bypassed Step', render: (r: any) => r.bypassed_step },
    { key: 'order_value_rupees', header: 'Order Value', render: (r: any) => fmtRupees(r.order_value_rupees) },
    { key: 'risk_score', header: 'Risk Score', render: (r: any) => String(r.risk_score ?? 0) },
    { key: 'risk_flag', header: 'Risk Flag', render: (r: any) => r.risk_flag },
    { key: 'reviewed', header: 'Reviewed', render: (r: any) => (r.reviewed ? 'yes' : 'no') },
    { key: 'reviewer_disposition', header: 'Disposition', render: (r: any) => r.reviewer_disposition ?? '—' },
    { key: 'initiated_by_email', header: 'Initiated By', render: (r: any) => r.initiated_by_email ?? '—' },
    { key: 'declared_reason', header: 'Declared Reason', render: (r: any) => (r.declared_reason ?? '').slice(0, 100) },
    { key: 'audit_count', header: 'Audit Entries', render: (r: any) => String(r.audit_count ?? 0) },
  ];

  const chainColumns: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'total_events', header: 'Events', render: (r: any) => String(r.total_events ?? 0) },
    { key: 'critical_events', header: 'Critical', render: (r: any) => String(r.critical_events ?? 0) },
    { key: 'high_events', header: 'High', render: (r: any) => String(r.high_events ?? 0) },
    { key: 'unreviewed_events', header: 'Unreviewed', render: (r: any) => String(r.unreviewed_events ?? 0) },
    { key: 'total_bypassed_value_rupees', header: 'Bypassed Value', render: (r: any) => fmtRupees(r.total_bypassed_value_rupees) },
    { key: 'avg_risk_score', header: 'Avg Risk', render: (r: any) => Number(r.avg_risk_score ?? 0).toFixed(1) },
    { key: 'last_event_at', header: 'Last Event', render: (r: any) => fmtDate(r.last_event_at) },
  ];

  const urgColumns: Column<any>[] = [
    { key: 'occurred_at', header: 'Occurred', render: (r: any) => fmtDate(r.occurred_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'bypass_type', header: 'Type', render: (r: any) => r.bypass_type },
    { key: 'order_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.order_value_rupees) },
    { key: 'risk_score', header: 'Risk', render: (r: any) => String(r.risk_score ?? 0) },
    { key: 'risk_flag', header: 'Flag', render: (r: any) => r.risk_flag },
    { key: 'initiated_by_email', header: 'Initiated By', render: (r: any) => r.initiated_by_email ?? '—' },
    { key: 'declared_reason', header: 'Declared Reason', render: (r: any) => (r.declared_reason ?? '').slice(0, 120) },
  ];

  const typeColumns: Column<any>[] = [
    { key: 'bypass_type', header: 'Bypass Type', render: (r: any) => r.bypass_type },
    { key: 'event_count', header: 'Events', render: (r: any) => String(r.event_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'avg_risk_score', header: 'Avg Risk', render: (r: any) => Number(r.avg_risk_score ?? 0).toFixed(1) },
    { key: 'critical_count', header: 'Critical', render: (r: any) => String(r.critical_count ?? 0) },
  ];

  const auditColumns: Column<any>[] = [
    { key: 'acted_at', header: 'Acted At', render: (r: any) => fmtDate(r.acted_at) },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? '—' },
    { key: 'action', header: 'Action', render: (r: any) => r.action },
    { key: 'prior_risk_flag', header: 'Prior Flag', render: (r: any) => r.prior_risk_flag ?? '—' },
    { key: 'new_risk_flag', header: 'New Flag', render: (r: any) => r.new_risk_flag ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => (r.note ?? '').slice(0, 140) },
  ];

  const dispColumns: Column<any>[] = [
    { key: 'reviewer_disposition', header: 'Disposition', render: (r: any) => r.reviewer_disposition },
    { key: 'event_count', header: 'Events', render: (r: any) => String(r.event_count ?? 0) },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Procurement-Cycle Bypass Detector</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Catches hospital chains that bypass their own declared procurement workflow via urgency overrides, direct purchases,
        off-panel vendors, or below-threshold order splits. Risk-scored, reviewable, and fully audit-logged.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Bypass Events</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{String(kpi.total_events ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Unreviewed</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b91c1c' }}>{String(kpi.unreviewed_events ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Critical</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b91c1c' }}>{String(kpi.critical_events ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>High</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{String(kpi.high_events ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Bypassed Value</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{fmtRupees(kpi.total_bypassed_value_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Unique Chains</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{String(kpi.unique_chains ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Last 30 Days</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{String(kpi.last_30d_events ?? 0)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Unreviewed High-Risk Bypasses</h2>
        <DataTable
          rows={urgent}
          columns={urgColumns}
          rowKey={(r: any) => String(r.id)}
          emptyMessage="No unreviewed high-risk bypasses."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Chain Bypass Summary</h2>
        <DataTable
          rows={chains}
          columns={chainColumns}
          rowKey={(r: any) => String(r.chain_id)}
          emptyMessage="No chains have recorded bypass events."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Bypass Type Distribution</h2>
        <DataTable
          rows={types}
          columns={typeColumns}
          rowKey={(r: any) => String(r.bypass_type)}
          emptyMessage="No bypass events recorded."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Reviewer Disposition Breakdown</h2>
        <DataTable
          rows={disp}
          columns={dispColumns}
          rowKey={(r: any) => String(r.reviewer_disposition)}
          emptyMessage="No dispositions recorded."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Bypass Events</h2>
        <DataTable
          rows={events}
          columns={evColumns}
          rowKey={(r: any) => String(r.id)}
          emptyMessage="No bypass events have been detected."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Audit Log</h2>
        <DataTable
          rows={audit}
          columns={auditColumns}
          rowKey={(r: any) => String(r.id)}
          emptyMessage="No audit entries logged."
        />
      </section>
    </main>
  );
}
