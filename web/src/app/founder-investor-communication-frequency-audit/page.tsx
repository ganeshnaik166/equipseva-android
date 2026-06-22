import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorCommunicationFrequencyAuditPage() {
  const sb = await getSupabaseServerClient();

  const [auditsRes, inadequateRes, actionsRes] = await Promise.all([
    sb.rpc('list_investor_freq_audits_r2073'),
    sb.rpc('inadequate_investor_freq_r2073'),
    sb.rpc('recent_investor_freq_actions_r2073'),
  ]);

  const audits: any[] = Array.isArray(auditsRes.data) ? auditsRes.data : [];
  const inadequate: any[] = Array.isArray(inadequateRes.data) ? inadequateRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const auditColumns: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'audit_period_label', header: 'Period', render: (r: any) => r.audit_period_label ?? '' },
    { key: 'communications_count', header: 'Touches', render: (r: any) => String(r.communications_count ?? 0) },
    { key: 'avg_days_between_touches', header: 'Avg Days', render: (r: any) => r.avg_days_between_touches != null ? Number(r.avg_days_between_touches).toFixed(1) : '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const inadequateColumns: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'audit_period_label', header: 'Period', render: (r: any) => r.audit_period_label ?? '' },
    { key: 'communications_count', header: 'Touches', render: (r: any) => String(r.communications_count ?? 0) },
    { key: 'avg_days_between_touches', header: 'Avg Days', render: (r: any) => r.avg_days_between_touches != null ? Number(r.avg_days_between_touches).toFixed(1) : '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'audit_id', header: 'Audit', render: (r: any) => String(r.audit_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => (r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Investor Communication Frequency Audit
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Audit how often we touch each investor. Flag inadequate cadence and log recalibration actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          All Frequency Audits
        </h2>
        <DataTable
          rows={audits}
          columns={auditColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Inadequate or Needs Recalibration
        </h2>
        <DataTable
          rows={inadequate}
          columns={inadequateColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Recent Frequency Actions
        </h2>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
