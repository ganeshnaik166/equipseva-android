import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [
    qbrsRes,
    actionsRes,
    overdueRes,
    completionRes,
    topOpenRes,
    npsRes,
    funnelRes,
  ] = await Promise.all([
    sb.rpc('list_qbrs_r2415'),
    sb.rpc('list_actions_r2415'),
    sb.rpc('overdue_qbrs_r2415'),
    sb.rpc('action_completion_rate_r2415'),
    sb.rpc('top_open_actions_r2415'),
    sb.rpc('chain_nps_at_qbr_r2415'),
    sb.rpc('qbr_completion_funnel_r2415'),
  ]);

  const qbrs: any[] = Array.isArray(qbrsRes.data) ? qbrsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];
  const overdue: any[] = Array.isArray(overdueRes.data) ? overdueRes.data : [];
  const completion: any[] = Array.isArray(completionRes.data) ? completionRes.data : [];
  const topOpen: any[] = Array.isArray(topOpenRes.data) ? topOpenRes.data : [];
  const nps: any[] = Array.isArray(npsRes.data) ? npsRes.data : [];
  const funnel: any[] = Array.isArray(funnelRes.data) ? funnelRes.data : [];

  const heldCount = qbrs.filter(q => q.status === 'held').length;
  const scheduledCount = qbrs.filter(q => q.status === 'scheduled').length;
  const totalActions = actions.length;
  const openActions = actions.filter(a => a.status === 'open' || a.status === 'in_progress').length;

  const qbrCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'held_on', header: 'Held On', render: (r: any) => r.held_on ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'attendee_count', header: 'Attendees', render: (r: any) => r.attendee_count },
    { key: 'nps_at_qbr', header: 'NPS', render: (r: any) => r.nps_at_qbr ?? '—' },
    { key: 'next_qbr_due_on', header: 'Next Due', render: (r: any) => r.next_qbr_due_on ?? '—' },
    { key: 'our_attendee_emails', header: 'Our Team', render: (r: any) => r.our_attendee_emails ?? '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'owner_side', header: 'Side', render: (r: any) => r.owner_side },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'days_to_due', header: 'Days to Due', render: (r: any) => r.days_to_due ?? '—' },
  ];

  const overdueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'last_quarter', header: 'Last Quarter', render: (r: any) => r.last_quarter ?? '—' },
    { key: 'last_held_on', header: 'Last Held', render: (r: any) => r.last_held_on ?? '—' },
    { key: 'next_qbr_due_on', header: 'Was Due', render: (r: any) => r.next_qbr_due_on ?? '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue },
    { key: 'last_status', header: 'Last Status', render: (r: any) => r.last_status },
  ];

  const completionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_actions', header: 'Total', render: (r: any) => r.total_actions },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'in_progress_count', header: 'In Progress', render: (r: any) => r.in_progress_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => r.dropped_count },
    { key: 'completion_rate_pct', header: 'Completion %', render: (r: any) => `${r.completion_rate_pct}%` },
  ];

  const topOpenCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'qbr_quarter', header: 'Quarter', render: (r: any) => r.qbr_quarter },
    { key: 'action_text', header: 'Action', render: (r: any) => r.action_text },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'owner_side', header: 'Side', render: (r: any) => r.owner_side },
    { key: 'priority', header: 'Priority', render: (r: any) => r.priority },
    { key: 'due_at', header: 'Due', render: (r: any) => r.due_at ? new Date(r.due_at).toLocaleDateString() : '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => r.days_overdue ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const npsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'qbrs_with_nps', header: 'QBRs w/ NPS', render: (r: any) => r.qbrs_with_nps },
    { key: 'latest_nps', header: 'Latest NPS', render: (r: any) => r.latest_nps ?? '—' },
    { key: 'latest_quarter', header: 'Latest Quarter', render: (r: any) => r.latest_quarter ?? '—' },
    { key: 'latest_held_on', header: 'Latest Held', render: (r: any) => r.latest_held_on ?? '—' },
    { key: 'avg_nps', header: 'Avg NPS', render: (r: any) => r.avg_nps ?? '—' },
    { key: 'min_nps', header: 'Min', render: (r: any) => r.min_nps ?? '—' },
    { key: 'max_nps', header: 'Max', render: (r: any) => r.max_nps ?? '—' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'meeting_count', header: 'Meetings', render: (r: any) => r.meeting_count },
    { key: 'pct_of_total', header: '% of Total', render: (r: any) => `${r.pct_of_total}%` },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain QBR Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Round r2415 · Quarterly business reviews, attendees, action items, NPS at QBR, and follow-up status across chain accounts.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '12px', marginBottom: '24px' }}>
        <div style={{ padding: '16px', background: '#f5f5f5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total QBRs</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{qbrs.length}</div>
        </div>
        <div style={{ padding: '16px', background: '#f5f5f5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Held</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{heldCount}</div>
        </div>
        <div style={{ padding: '16px', background: '#f5f5f5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Scheduled</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{scheduledCount}</div>
        </div>
        <div style={{ padding: '16px', background: '#f5f5f5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Overdue Chains</div>
          <div style={{ fontSize: '24px', fontWeight: 700, color: overdue.length > 0 ? '#c00' : '#000' }}>{overdue.length}</div>
        </div>
        <div style={{ padding: '16px', background: '#f5f5f5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Total Actions</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalActions}</div>
        </div>
        <div style={{ padding: '16px', background: '#f5f5f5', borderRadius: '8px' }}>
          <div style={{ fontSize: '12px', color: '#666' }}>Open / In Progress</div>
          <div style={{ fontSize: '24px', fontWeight: 700 }}>{openActions}</div>
        </div>
      </div>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>QBR Completion Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No QBR records yet."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Overdue QBRs (next-due date passed)</h2>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          emptyMessage="No overdue chains."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Top Open Actions</h2>
        <DataTable
          rows={topOpen}
          columns={topOpenCols}
          emptyMessage="No open actions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Action Completion Rate by Chain</h2>
        <DataTable
          rows={completion}
          columns={completionCols}
          emptyMessage="No completion data."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>NPS at QBR by Chain</h2>
        <DataTable
          rows={nps}
          columns={npsCols}
          emptyMessage="No NPS scores recorded."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All QBR Meetings</h2>
        <DataTable
          rows={qbrs}
          columns={qbrCols}
          emptyMessage="No QBR meetings logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Action Items</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No action items logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
