import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type PlaybookRow = {
  id: string;
  playbook_title: string;
  failure_category: string;
  version: number;
  is_active: boolean;
  event_count: number;
  saved_count: number;
  lost_count: number;
};

type EventRow = {
  id: string;
  occurred_on: string;
  failure_category: string;
  engineer_id: string | null;
  customer_org_id: string | null;
  playbook_id: string | null;
  playbook_title: string | null;
  playbook_used: boolean;
  outcome: string;
  customer_csat: number | null;
  resolved_at: string | null;
};

type CategoryStatRow = {
  failure_category: string;
  total_events: number;
  playbook_used_count: number;
  playbook_skipped_count: number;
  saved_count: number;
  lost_count: number;
  partial_count: number;
  save_rate_with_playbook: number | null;
  save_rate_without_playbook: number | null;
  avg_csat: number | null;
};

type SuggestionRow = {
  event_id: string;
  occurred_on: string;
  failure_category: string;
  playbook_id: string | null;
  playbook_title: string | null;
  outcome: string;
  customer_csat: number | null;
  playbook_update_suggestion: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [playbooksRes, eventsRes, statsRes, suggestionsRes] = await Promise.all([
    sb.rpc('list_playbooks_r2380'),
    sb.rpc('list_events_r2380'),
    sb.rpc('category_recovery_stats_r2380'),
    sb.rpc('pending_update_suggestions_r2380'),
  ]);

  const playbooks: PlaybookRow[] = (playbooksRes.data as PlaybookRow[] | null) ?? [];
  const events: EventRow[] = (eventsRes.data as EventRow[] | null) ?? [];
  const stats: CategoryStatRow[] = (statsRes.data as CategoryStatRow[] | null) ?? [];
  const suggestions: SuggestionRow[] = (suggestionsRes.data as SuggestionRow[] | null) ?? [];

  const playbookCols: Column<PlaybookRow>[] = [
    { key: 'playbook_title', header: 'Title', render: (r: any) => r.playbook_title },
    { key: 'failure_category', header: 'Category', render: (r: any) => r.failure_category },
    { key: 'version', header: 'Version', render: (r: any) => r.version },
    { key: 'is_active', header: 'Active', render: (r: any) => (r.is_active ? 'yes' : 'no') },
    { key: 'event_count', header: 'Events', render: (r: any) => r.event_count },
    { key: 'saved_count', header: 'Saved', render: (r: any) => r.saved_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: 'occurred_on', header: 'Date', render: (r: any) => r.occurred_on },
    { key: 'failure_category', header: 'Category', render: (r: any) => r.failure_category },
    { key: 'engineer_id', header: 'Engineer', render: (r: any) => (r.engineer_id ? String(r.engineer_id).slice(0, 8) : '—') },
    { key: 'customer_org_id', header: 'Customer', render: (r: any) => (r.customer_org_id ? String(r.customer_org_id).slice(0, 8) : '—') },
    { key: 'playbook_title', header: 'Playbook', render: (r: any) => r.playbook_title ?? '—' },
    { key: 'playbook_used', header: 'Used?', render: (r: any) => (r.playbook_used ? 'yes' : 'no') },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'customer_csat', header: 'CSAT', render: (r: any) => (r.customer_csat ?? '—') },
  ];

  const statCols: Column<CategoryStatRow>[] = [
    { key: 'failure_category', header: 'Category', render: (r: any) => r.failure_category },
    { key: 'total_events', header: 'Total', render: (r: any) => r.total_events },
    { key: 'playbook_used_count', header: 'Used', render: (r: any) => r.playbook_used_count },
    { key: 'playbook_skipped_count', header: 'Skipped', render: (r: any) => r.playbook_skipped_count },
    { key: 'saved_count', header: 'Saved', render: (r: any) => r.saved_count },
    { key: 'lost_count', header: 'Lost', render: (r: any) => r.lost_count },
    { key: 'partial_count', header: 'Partial', render: (r: any) => r.partial_count },
    { key: 'save_rate_with_playbook', header: 'Save% w/ pb', render: (r: any) => (r.save_rate_with_playbook ?? '—') },
    { key: 'save_rate_without_playbook', header: 'Save% w/o pb', render: (r: any) => (r.save_rate_without_playbook ?? '—') },
    { key: 'avg_csat', header: 'Avg CSAT', render: (r: any) => (r.avg_csat ?? '—') },
  ];

  const suggestionCols: Column<SuggestionRow>[] = [
    { key: 'occurred_on', header: 'Date', render: (r: any) => r.occurred_on },
    { key: 'failure_category', header: 'Category', render: (r: any) => r.failure_category },
    { key: 'playbook_title', header: 'Playbook', render: (r: any) => r.playbook_title ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'customer_csat', header: 'CSAT', render: (r: any) => (r.customer_csat ?? '—') },
    { key: 'playbook_update_suggestion', header: 'Suggestion', render: (r: any) => r.playbook_update_suggestion },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Service-Recovery Playbook Usage</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track service-failure events: did the engineer use the recovery playbook, was the customer saved or lost, and what playbook updates do we need to roll in.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Playbooks ({playbooks.length})</h2>
        <DataTable
          rows={playbooks}
          columns={playbookCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No playbooks yet — add one per failure category."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Category recovery stats ({stats.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Save-rate with playbook vs without. If save-rate w/ pb &gt;= save-rate w/o pb, the playbook is paying off.
        </p>
        <DataTable
          rows={stats}
          columns={statCols}
          rowKey={(r: any, i: number) => String(r.failure_category ?? i)}
          emptyMessage="No recovery events logged yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent events ({events.length})</h2>
        <DataTable
          rows={events}
          columns={eventCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No service-failure events yet."
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Playbook update suggestions ({suggestions.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Engineer-flagged gaps in the current playbook. Review =&gt; roll into next version =&gt; mark suggestion handled.
        </p>
        <DataTable
          rows={suggestions}
          columns={suggestionCols}
          rowKey={(r: any, i: number) => String(r.event_id ?? i)}
          emptyMessage="No pending playbook update suggestions."
        />
      </section>
    </div>
  );
}
