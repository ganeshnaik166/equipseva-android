import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, actionsRes, classesRes, summaryRes] = await Promise.all([
    sb.rpc('list_engineer_toolkit_audits_r2198'),
    sb.rpc('recent_actions_r2198'),
    sb.rpc('top_equipment_classes_r2198'),
    sb.rpc('toolkit_audit_summary_r2198'),
  ]);

  const audits: any[] = Array.isArray(auditsRes.data) ? auditsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const classes: any[] = Array.isArray(classesRes.data) ? classesRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;

  const auditCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => String(r.engineer_name ?? '') },
    { key: 'equipment_class', header: 'Equipment class', render: (r: any) => String(r.equipment_class ?? '') },
    { key: 'tool_name', header: 'Tool / meter', render: (r: any) => String(r.tool_name ?? '') },
    {
      key: 'required',
      header: 'Required',
      render: (r: any) => (r.required ? 'yes' : 'no'),
    },
    {
      key: 'carried',
      header: 'Carried',
      render: (r: any) => (r.carried ? 'yes' : 'MISSING'),
    },
    {
      key: 'calibration_due_on',
      header: 'Calibration due',
      render: (r: any) => r.calibration_due_on ?? '—',
    },
    {
      key: 'days_to_calibration_expiry',
      header: 'Days to expiry',
      render: (r: any) => {
        if (r.days_to_calibration_expiry === null || r.days_to_calibration_expiry === undefined) return '—';
        const d = Number(r.days_to_calibration_expiry);
        if (d < 0) return `EXPIRED (${Math.abs(d)}d ago)`;
        return `${d}d`;
      },
    },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'flagged_reason', header: 'Flag reason', render: (r: any) => String(r.flagged_reason ?? '') },
    {
      key: 'audit_date',
      header: 'Audit date',
      render: (r: any) => r.audit_date ?? '—',
    },
  ];

  const actionCols: Column<any>[] = [
    {
      key: 'created_at',
      header: 'When',
      render: (r: any) => new Date(r.created_at).toLocaleString('en-IN'),
    },
    { key: 'action_kind', header: 'Action', render: (r: any) => String(r.action_kind ?? '') },
    { key: 'actor_email', header: 'Actor', render: (r: any) => String(r.actor_email ?? '') },
    {
      key: 'payload',
      header: 'Payload',
      render: (r: any) => {
        try {
          return JSON.stringify(r.payload);
        } catch {
          return '';
        }
      },
    },
  ];

  const classCols: Column<any>[] = [
    { key: 'equipment_class', header: 'Equipment class', render: (r: any) => String(r.equipment_class ?? '') },
    { key: 'total_audits', header: 'Total audits', render: (r: any) => String(r.total_audits ?? '') },
    { key: 'failed_count', header: 'Failed', render: (r: any) => String(r.failed_count ?? '') },
    { key: 'missing_tool_count', header: 'Missing tools', render: (r: any) => String(r.missing_tool_count ?? '') },
    { key: 'expired_calibration_count', header: 'Expired calibration', render: (r: any) => String(r.expired_calibration_count ?? '') },
    {
      key: 'pass_rate_pct',
      header: 'Pass rate %',
      render: (r: any) => (r.pass_rate_pct == null ? '—' : `${r.pass_rate_pct}%`),
    },
  ];

  const cardStyle: React.CSSProperties = {
    border: '1px solid #e5e7eb',
    borderRadius: 8,
    padding: 16,
    background: '#fff',
    minWidth: 160,
  };
  const labelStyle: React.CSSProperties = { fontSize: 12, color: '#6b7280' };
  const valueStyle: React.CSSProperties = { fontSize: 24, fontWeight: 600, marginTop: 4 };

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 6 }}>
          Engineer toolkit audit
        </h1>
        <p style={{ color: '#4b5563', fontSize: 14 }}>
          Verify every engineer carries the right tools & calibrated meters for the
          equipment classes they service. Flags missing items & expired calibration.
        </p>
      </header>

      <section
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
          gap: 12,
          marginBottom: 32,
        }}
      >
        <div style={cardStyle}>
          <div style={labelStyle}>Total audits</div>
          <div style={valueStyle}>{summary?.total_audits ?? 0}</div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Open</div>
          <div style={valueStyle}>{summary?.open_count ?? 0}</div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Failed</div>
          <div style={{ ...valueStyle, color: '#b91c1c' }}>{summary?.failed_count ?? 0}</div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Passed</div>
          <div style={{ ...valueStyle, color: '#047857' }}>{summary?.passed_count ?? 0}</div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Missing required tool</div>
          <div style={{ ...valueStyle, color: '#b91c1c' }}>
            {summary?.missing_required_tool_count ?? 0}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Expired calibration</div>
          <div style={{ ...valueStyle, color: '#b91c1c' }}>
            {summary?.expired_calibration_count ?? 0}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Expiring in 30d</div>
          <div style={{ ...valueStyle, color: '#b45309' }}>
            {summary?.expiring_30d_count ?? 0}
          </div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Distinct engineers</div>
          <div style={valueStyle}>{summary?.distinct_engineers ?? 0}</div>
        </div>
        <div style={cardStyle}>
          <div style={labelStyle}>Distinct classes</div>
          <div style={valueStyle}>{summary?.distinct_classes ?? 0}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Toolkit audits — latest 200
        </h2>
        <DataTable columns={auditCols} rows={audits} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Failure hotspots by equipment class
        </h2>
        <DataTable columns={classCols} rows={classes} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent audit actions
        </h2>
        <DataTable columns={actionCols} rows={actions} rowKey={(_, i) => String(i)} />
      </section>
    </main>
  );
}
