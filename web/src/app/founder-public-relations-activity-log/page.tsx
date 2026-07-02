import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ActivityRow = {
  id: string;
  activity_label: string;
  activity_type: string;
  publication: string;
  status: string;
  activity_date: string | null;
  captured_at: string;
  action_count: number;
};

type PublishedRow = {
  id: string;
  activity_label: string;
  activity_type: string;
  publication: string;
  activity_date: string | null;
  days_ago: number;
};

type ActionRow = {
  id: string;
  activity_id: string;
  activity_label: string;
  action_type: string;
  taken_at: string;
  by_email: string;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [activitiesRes, publishedRes, actionsRes] = await Promise.all([
    sb.rpc('list_pr_activities_r2110'),
    sb.rpc('recent_published_pr_r2110'),
    sb.rpc('recent_pr_actions_r2110'),
  ]);

  const activities: ActivityRow[] = (activitiesRes.data as ActivityRow[] | null) ?? [];
  const published: PublishedRow[] = (publishedRes.data as PublishedRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];

  const activityCols: Column<ActivityRow>[] = [
    { key: 'activity_label', header: 'Activity', render: (r: any) => r.activity_label },
    { key: 'activity_type', header: 'Type', render: (r: any) => r.activity_type },
    { key: 'publication', header: 'Publication', render: (r: any) => r.publication || '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'activity_date', header: 'Date', render: (r: any) => r.activity_date ?? '—' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at).slice(0, 10) },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
  ];

  const publishedCols: Column<PublishedRow>[] = [
    { key: 'activity_label', header: 'Activity', render: (r: any) => r.activity_label },
    { key: 'activity_type', header: 'Type', render: (r: any) => r.activity_type },
    { key: 'publication', header: 'Publication', render: (r: any) => r.publication || '—' },
    { key: 'activity_date', header: 'Date', render: (r: any) => r.activity_date ?? '—' },
    { key: 'days_ago', header: 'Days ago', render: (r: any) => r.days_ago },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'activity_label', header: 'Activity', render: (r: any) => r.activity_label },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => String(r.taken_at).slice(0, 16).replace('T', ' ') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email || '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Founder Public Relations Activity Log</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Log of press releases, interviews, podcasts, articles, social posts and event appearances. Track planned, active and published activities along with follow-up actions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All activities ({activities.length})</h2>
        <DataTable
          rows={activities}
          columns={activityCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recently published ({published.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Activities with status published, most recent first, capped at fifty rows.
        </p>
        <DataTable
          rows={published}
          columns={publishedCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent actions ({actions.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Latest follow-up actions taken across all PR activities.
        </p>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
