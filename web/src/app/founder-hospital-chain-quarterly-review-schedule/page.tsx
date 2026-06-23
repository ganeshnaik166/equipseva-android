import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type UpcomingRow = {
  id: string;
  chain_name: string;
  chain_code: string;
  primary_contact_name: string;
  fiscal_quarter: string;
  scheduled_at: string;
  meeting_mode: string;
  agenda_template: string;
  status: string;
  hospital_count: number;
  amc_value_inr_lakhs: number;
  open_actions: number;
};

type CompletedRow = {
  id: string;
  chain_name: string;
  fiscal_quarter: string;
  scheduled_at: string;
  completed_at: string | null;
  satisfaction_score: number | null;
  renewal_signal: string | null;
  next_review_at: string | null;
  meeting_notes: string | null;
};

type ActionRow = {
  id: string;
  review_id: string;
  chain_name: string;
  action_title: string;
  owner_label: string;
  priority: string;
  status: string;
  due_at: string | null;
  days_overdue: number;
};

function fmtDate(s: string | null) {
  if (!s) return '—';
  return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [upcoming, completed, actions] = await Promise.all([
    supabase.rpc('founder_hcqr_r2351_list_upcoming'),
    supabase.rpc('founder_hcqr_r2351_list_completed'),
    supabase.rpc('founder_hcqr_r2351_list_actions'),
  ]);

  const upcomingRows: UpcomingRow[] = (upcoming.data as UpcomingRow[]) ?? [];
  const completedRows: CompletedRow[] = (completed.data as CompletedRow[]) ?? [];
  const actionRows: ActionRow[] = (actions.data as ActionRow[]) ?? [];

  const totalAmc = upcomingRows.reduce((s, r) => s + Number(r.amc_value_inr_lakhs || 0), 0);
  const totalHospitals = upcomingRows.reduce((s, r) => s + Number(r.hospital_count || 0), 0);
  const openActionCount = actionRows.length;
  const overdueCount = actionRows.filter((a) => a.days_overdue > 0).length;

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: UpcomingRow) => (
      <div>
        <div style={{ fontWeight: 600 }}>{r.chain_name}</div>
        <div style={{ fontSize: 11, color: '#666' }}>{r.chain_code} · {r.hospital_count} hospitals</div>
      </div>
    ) },
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: UpcomingRow) => r.fiscal_quarter },
    { key: 'scheduled_at', header: 'Scheduled', render: (r: UpcomingRow) => fmtDate(r.scheduled_at) },
    { key: 'meeting_mode', header: 'Mode', render: (r: UpcomingRow) => (
      <span style={{ textTransform: 'capitalize' }}>{r.meeting_mode}</span>
    ) },
    { key: 'agenda_template', header: 'Agenda', render: (r: UpcomingRow) => (
      <span style={{ fontSize: 11, padding: '2px 6px', background: '#eef', borderRadius: 4 }}>{r.agenda_template}</span>
    ) },
    { key: 'primary_contact_name', header: 'Contact', render: (r: UpcomingRow) => r.primary_contact_name },
    { key: 'amc_value_inr_lakhs', header: 'AMC ₹L', render: (r: UpcomingRow) => Number(r.amc_value_inr_lakhs).toFixed(1) },
    { key: 'status', header: 'Status', render: (r: UpcomingRow) => {
      const color = r.status === 'confirmed' ? '#0a7' : r.status === 'scheduled' ? '#06c' : r.status === 'cancelled' ? '#c33' : '#888';
      return <span style={{ color, fontWeight: 600, textTransform: 'capitalize' }}>{r.status}</span>;
    } },
    { key: 'open_actions', header: 'Open Actions', render: (r: UpcomingRow) => (
      <span style={{ fontWeight: r.open_actions > 0 ? 600 : 400, color: r.open_actions > 0 ? '#c60' : '#666' }}>
        {r.open_actions}
      </span>
    ) },
  ];

  const completedCols: Column<CompletedRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: CompletedRow) => r.chain_name },
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: CompletedRow) => r.fiscal_quarter },
    { key: 'completed_at', header: 'Completed', render: (r: CompletedRow) => fmtDate(r.completed_at) },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: CompletedRow) => {
      if (r.satisfaction_score == null) return '—';
      const color = r.satisfaction_score >= 8 ? '#0a7' : r.satisfaction_score >= 6 ? '#c80' : '#c33';
      return <span style={{ color, fontWeight: 600 }}>{r.satisfaction_score}/10</span>;
    } },
    { key: 'renewal_signal', header: 'Renewal Signal', render: (r: CompletedRow) => {
      if (!r.renewal_signal) return '—';
      const color = r.renewal_signal === 'strong' ? '#0a7' : r.renewal_signal === 'neutral' ? '#888' : r.renewal_signal === 'at_risk' ? '#c80' : '#c33';
      return <span style={{ color, fontWeight: 600, textTransform: 'capitalize' }}>{r.renewal_signal.replace('_', ' ')}</span>;
    } },
    { key: 'next_review_at', header: 'Next Review', render: (r: CompletedRow) => fmtDate(r.next_review_at) },
    { key: 'meeting_notes', header: 'Notes', render: (r: CompletedRow) => (
      <div style={{ maxWidth: 280, fontSize: 11, color: '#444' }}>
        {r.meeting_notes ? (r.meeting_notes.length > 120 ? r.meeting_notes.slice(0, 120) + '…' : r.meeting_notes) : '—'}
      </div>
    ) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: ActionRow) => r.chain_name },
    { key: 'action_title', header: 'Action', render: (r: ActionRow) => (
      <div style={{ maxWidth: 320, fontWeight: 500 }}>{r.action_title}</div>
    ) },
    { key: 'owner_label', header: 'Owner', render: (r: ActionRow) => r.owner_label },
    { key: 'priority', header: 'Priority', render: (r: ActionRow) => {
      const color = r.priority === 'critical' ? '#c33' : r.priority === 'high' ? '#c60' : r.priority === 'medium' ? '#06c' : '#888';
      return <span style={{ color, fontWeight: 600, textTransform: 'capitalize' }}>{r.priority}</span>;
    } },
    { key: 'status', header: 'Status', render: (r: ActionRow) => (
      <span style={{ textTransform: 'capitalize' }}>{r.status.replace('_', ' ')}</span>
    ) },
    { key: 'due_at', header: 'Due', render: (r: ActionRow) => fmtDate(r.due_at) },
    { key: 'days_overdue', header: 'Overdue', render: (r: ActionRow) => {
      if (r.days_overdue <= 0) return <span style={{ color: '#888' }}>—</span>;
      return <span style={{ color: '#c33', fontWeight: 700 }}>{r.days_overdue}d</span>;
    } },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, -apple-system, sans-serif' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>Hospital Chain Quarterly Reviews</h1>
        <p style={{ color: '#666', marginTop: 4, fontSize: 13 }}>
          Schedule when each chain meets us quarterly & track agenda + action follow-ups
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Upcoming Reviews</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{upcomingRows.length}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>AMC Under Review</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>₹{totalAmc.toFixed(1)}L</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Hospitals Covered</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4 }}>{totalHospitals}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Open Action Items</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4, color: openActionCount > 0 ? '#c60' : '#0a7' }}>{openActionCount}</div>
        </div>
        <div style={{ padding: 12, border: '1px solid #ddd', borderRadius: 8, background: '#fff' }}>
          <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>Overdue</div>
          <div style={{ fontSize: 22, fontWeight: 700, marginTop: 4, color: overdueCount > 0 ? '#c33' : '#0a7' }}>{overdueCount}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Upcoming & Recent Reviews</h2>
        <DataTable
          rows={upcomingRows}
          columns={upcomingCols}
          rowKey={(r: UpcomingRow) => r.id}
          emptyMessage="No upcoming quarterly reviews scheduled"
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open Action Items</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          rowKey={(r: ActionRow) => r.id}
          emptyMessage="No open action items"
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Completed Reviews</h2>
        <DataTable
          rows={completedRows}
          columns={completedCols}
          rowKey={(r: CompletedRow) => r.id}
          emptyMessage="No completed reviews yet"
        />
      </section>
    </div>
  );
}
