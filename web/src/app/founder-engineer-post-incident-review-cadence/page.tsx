import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Escalation = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  customer_org: string;
  escalation_title: string;
  severity: string;
  occurred_on: string;
  postmortem_due_on: string;
  postmortem_done_on: string | null;
  postmortem_status: string;
  days_to_postmortem: number | null;
  insight_count: number;
};

type Overdue = {
  id: string;
  engineer_email: string | null;
  customer_org: string;
  escalation_title: string;
  severity: string;
  occurred_on: string;
  postmortem_due_on: string;
  days_overdue: number;
};

type Theme = {
  recurring_theme: string;
  occurrence_count: number;
  engineer_count: number;
  last_logged_at: string;
};

type CadenceRow = {
  engineer_user_id: string;
  engineer_email: string | null;
  total_escalations: number;
  on_time_postmortems: number;
  late_postmortems: number;
  pending_postmortems: number;
  skipped_postmortems: number;
  on_time_pct: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [escRes, overdueRes, themesRes, cadenceRes] = await Promise.all([
    supabase.rpc('list_escalations_r2374'),
    supabase.rpc('overdue_postmortems_r2374'),
    supabase.rpc('recurring_themes_r2374'),
    supabase.rpc('engineer_cadence_summary_r2374'),
  ]);

  const escalations: Escalation[] = (escRes.data as Escalation[] | null) ?? [];
  const overdue: Overdue[] = (overdueRes.data as Overdue[] | null) ?? [];
  const themes: Theme[] = (themesRes.data as Theme[] | null) ?? [];
  const cadence: CadenceRow[] = (cadenceRes.data as CadenceRow[] | null) ?? [];

  const totalEsc = escalations.length;
  const onTime = escalations.filter((e) => e.postmortem_status === 'done_on_time').length;
  const late = escalations.filter((e) => e.postmortem_status === 'done_late').length;
  const pending = escalations.filter((e) => e.postmortem_status === 'pending').length;
  const onTimePct = totalEsc > 0 ? Math.round((onTime / totalEsc) * 1000) / 10 : 0;

  const escCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: Escalation) => r.engineer_email ?? r.engineer_user_id.slice(0, 8) },
    { key: 'customer_org', header: 'Customer', render: (r: Escalation) => r.customer_org },
    { key: 'escalation_title', header: 'Escalation', render: (r: Escalation) => r.escalation_title },
    { key: 'severity', header: 'Sev', render: (r: Escalation) => r.severity.toUpperCase() },
    { key: 'occurred_on', header: 'Occurred', render: (r: Escalation) => r.occurred_on },
    { key: 'postmortem_due_on', header: 'PM Due', render: (r: Escalation) => r.postmortem_due_on },
    {
      key: 'postmortem_status',
      header: 'Status',
      render: (r: Escalation) => {
        if (r.postmortem_status === 'done_on_time') return 'On time';
        if (r.postmortem_status === 'done_late') return 'Late';
        if (r.postmortem_status === 'skipped') return 'Skipped';
        return 'Pending';
      },
    },
    { key: 'days_to_postmortem', header: 'Days to PM', render: (r: Escalation) => (r.days_to_postmortem ?? '—') },
    { key: 'insight_count', header: 'Insights', render: (r: Escalation) => r.insight_count },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: Overdue) => r.engineer_email ?? '—' },
    { key: 'customer_org', header: 'Customer', render: (r: Overdue) => r.customer_org },
    { key: 'escalation_title', header: 'Escalation', render: (r: Overdue) => r.escalation_title },
    { key: 'severity', header: 'Sev', render: (r: Overdue) => r.severity.toUpperCase() },
    { key: 'occurred_on', header: 'Occurred', render: (r: Overdue) => r.occurred_on },
    { key: 'postmortem_due_on', header: 'Was Due', render: (r: Overdue) => r.postmortem_due_on },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: Overdue) => r.days_overdue },
  ];

  const themeCols: Column<any>[] = [
    { key: 'recurring_theme', header: 'Recurring Theme', render: (r: Theme) => r.recurring_theme },
    { key: 'occurrence_count', header: 'Occurrences', render: (r: Theme) => r.occurrence_count },
    { key: 'engineer_count', header: 'Engineers', render: (r: Theme) => r.engineer_count },
    { key: 'last_logged_at', header: 'Last Logged', render: (r: Theme) => new Date(r.last_logged_at).toLocaleDateString() },
  ];

  const cadenceCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: CadenceRow) => r.engineer_email ?? r.engineer_user_id.slice(0, 8) },
    { key: 'total_escalations', header: 'Total Esc', render: (r: CadenceRow) => r.total_escalations },
    { key: 'on_time_postmortems', header: 'On Time', render: (r: CadenceRow) => r.on_time_postmortems },
    { key: 'late_postmortems', header: 'Late', render: (r: CadenceRow) => r.late_postmortems },
    { key: 'pending_postmortems', header: 'Pending', render: (r: CadenceRow) => r.pending_postmortems },
    { key: 'on_time_pct', header: 'On-time %', render: (r: CadenceRow) => (r.on_time_pct == null ? '—' : `${r.on_time_pct}%`) },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Post-Incident Review Cadence</h1>
      <p style={{ color: '#666', marginBottom: 20, fontSize: 14 }}>
        For every major customer escalation, was the post-mortem completed within 7 days? Track insights & recurring themes.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Escalations</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalEsc}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>PM On Time</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#16a34a' }}>{onTime}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>PM Late</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#d97706' }}>{late}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Pending</div>
          <div style={{ fontSize: 28, fontWeight: 700, color: '#dc2626' }}>{pending}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>On-time %</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{onTimePct}%</div>
        </div>
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Overdue Post-mortems (&gt; 7 days)</h2>
      <DataTable
        rows={overdue}
        columns={overdueCols}
        rowKey={(r: Overdue) => r.id}
        emptyMessage="No overdue post-mortems — cadence is clean."
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '28px 0 8px' }}>Recurring Insight Themes</h2>
      <p style={{ color: '#666', fontSize: 13, marginBottom: 8 }}>
        Themes flagged across &gt;= 2 escalations — these are systemic, not one-offs.
      </p>
      <DataTable
        rows={themes}
        columns={themeCols}
        rowKey={(r: Theme) => r.recurring_theme}
        emptyMessage="No recurring themes yet."
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '28px 0 8px' }}>Engineer Cadence Summary</h2>
      <DataTable
        rows={cadence}
        columns={cadenceCols}
        rowKey={(r: CadenceRow) => r.engineer_user_id}
        emptyMessage="No escalations logged."
      />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '28px 0 8px' }}>All Escalations</h2>
      <DataTable
        rows={escalations}
        columns={escCols}
        rowKey={(r: Escalation) => r.id}
        emptyMessage="No escalations logged."
      />
    </div>
  );
}
