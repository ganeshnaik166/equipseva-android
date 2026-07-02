import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TriggerRow = {
  id: string;
  investor_id: string;
  trigger_event_label: string;
  trigger_date: string;
  shares_compensated: number;
  trigger_type: string;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  trigger_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  shares_count: number;
  notes_md: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return '';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}

function fmtShares(n: number | null): string {
  if (n === null || n === undefined) return '0';
  return Number(n).toLocaleString();
}

function shortId(s: string | null): string {
  if (!s) return '';
  return s.slice(0, 8);
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [triggersRes, recentTriggersRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_triggers_r2165'),
    sb.rpc('recent_triggers_r2165', { p_limit: 20 }),
    sb.rpc('recent_actions_r2165', { p_limit: 20 }),
  ]);

  const triggers: TriggerRow[] = (triggersRes.data as TriggerRow[] | null) ?? [];
  const recentTriggers: TriggerRow[] = (recentTriggersRes.data as TriggerRow[] | null) ?? [];
  const recentActions: ActionRow[] = (recentActionsRes.data as ActionRow[] | null) ?? [];

  const triggerColumns: Column<TriggerRow>[] = [
    { key: 'trigger_event_label', header: 'Event', render: (r: any) => String(r.trigger_event_label ?? '') },
    { key: 'investor_id', header: 'Investor', render: (r: any) => shortId(r.investor_id) },
    { key: 'trigger_date', header: 'Trigger Date', render: (r: any) => String(r.trigger_date ?? '') },
    { key: 'shares_compensated', header: 'Shares Comp.', render: (r: any) => fmtShares(r.shares_compensated) },
    { key: 'trigger_type', header: 'Type', render: (r: any) => String(r.trigger_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const recentTriggerColumns: Column<TriggerRow>[] = [
    { key: 'trigger_event_label', header: 'Event', render: (r: any) => String(r.trigger_event_label ?? '') },
    { key: 'trigger_type', header: 'Type', render: (r: any) => String(r.trigger_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'shares_compensated', header: 'Shares', render: (r: any) => fmtShares(r.shares_compensated) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'trigger_id', header: 'Trigger', render: (r: any) => shortId(r.trigger_id) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'shares_count', header: 'Shares', render: (r: any) => fmtShares(r.shares_count) },
    { key: 'taken_at', header: 'Taken', render: (r: any) => fmtDate(r.taken_at) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div style={{ padding: '1.5rem', maxWidth: '1200px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', fontWeight: 700, marginBottom: '0.5rem' }}>
        Investor Cap Table Anti-Dilution Trigger
      </h1>
      <p style={{ color: '#555', marginBottom: '1.5rem' }}>
        Track anti-dilution trigger events across the cap table. Types include weighted average broad,
        weighted average narrow, and full ratchet. Round 2165.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          All Triggers
        </h2>
        <p style={{ color: '#666', marginBottom: '0.75rem' }}>
          Total: {triggers.length} trigger events captured.
        </p>
        <DataTable
          rows={triggers}
          columns={triggerColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Recent Triggers (Last 20)
        </h2>
        <DataTable
          rows={recentTriggers}
          columns={recentTriggerColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '0.75rem' }}>
          Recent Actions (Last 20)
        </h2>
        <p style={{ color: '#666', marginBottom: '0.75rem' }}>
          Audit log of status changes on trigger events.
        </p>
        <DataTable
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
