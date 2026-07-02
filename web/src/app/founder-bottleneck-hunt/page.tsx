import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type HuntRow = {
  id: string;
  hunt_week: string;
  identified_bottleneck_md: string;
  bottleneck_owner_email: string | null;
  impact_pct: number | null;
  removed_by: string | null;
  status: string;
  open_actions: number;
  done_actions: number;
  created_at: string;
};

type ActionRow = {
  id: string;
  hunt_id: string;
  hunt_week: string;
  action_text: string;
  owner_email: string | null;
  due_date: string | null;
  status: string;
  completed_at: string | null;
  created_at: string;
};

type CurrentRow = {
  id: string;
  hunt_week: string;
  identified_bottleneck_md: string;
  bottleneck_owner_email: string | null;
  impact_pct: number | null;
  status: string;
  open_actions: number;
  total_actions: number;
};

type HistoryRow = {
  hunt_week: string;
  status: string;
  impact_pct: number | null;
  bottleneck_owner_email: string | null;
  open_actions: number;
  done_actions: number;
  days_to_remove: number | null;
};

function fmtDate(s: string | null): string {
  if (!s) return '—';
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return s;
  }
}

function fmtPct(n: number | null): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(1)}%`;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [huntsRes, actionsRes, currentRes, historyRes] = await Promise.all([
    sb.rpc('list_bottleneck_hunts_r1834', { p_limit: 50 }),
    sb.rpc('list_bottleneck_actions_r1834', { p_hunt_id: null }),
    sb.rpc('current_bottleneck_r1834'),
    sb.rpc('weekly_bottleneck_history_r1834', { p_weeks: 12 }),
  ]);

  const hunts: HuntRow[] = (huntsRes.data as HuntRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const currentArr: CurrentRow[] = (currentRes.data as CurrentRow[]) ?? [];
  const current: CurrentRow | null = currentArr.length > 0 ? currentArr[0] : null;
  const history: HistoryRow[] = (historyRes.data as HistoryRow[]) ?? [];

  const huntCols: Column<HuntRow>[] = [
    { key: 'hunt_week', header: 'Week', render: (r: any) => fmtDate(r.hunt_week) },
    {
      key: 'identified_bottleneck_md',
      header: 'Bottleneck',
      render: (r: any) => (
        <div style={{ maxWidth: 420, whiteSpace: 'pre-wrap' }}>{r.identified_bottleneck_md}</div>
      ),
    },
    { key: 'bottleneck_owner_email', header: 'Owner', render: (r: any) => r.bottleneck_owner_email ?? '—' },
    { key: 'impact_pct', header: 'Impact', render: (r: any) => fmtPct(r.impact_pct) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'open_actions',
      header: 'Actions',
      render: (r: any) => `${r.open_actions} open / ${r.done_actions} done`,
    },
    { key: 'removed_by', header: 'Removed', render: (r: any) => fmtDate(r.removed_by) },
    { key: 'created_at', header: 'Logged', render: (r: any) => fmtDate(r.created_at) },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'hunt_week', header: 'Week', render: (r: any) => fmtDate(r.hunt_week) },
    {
      key: 'action_text',
      header: 'Action',
      render: (r: any) => <div style={{ maxWidth: 380, whiteSpace: 'pre-wrap' }}>{r.action_text}</div>,
    },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDate(r.due_date) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'completed_at', header: 'Done', render: (r: any) => fmtDate(r.completed_at) },
  ];

  const historyCols: Column<HistoryRow>[] = [
    { key: 'hunt_week', header: 'Week', render: (r: any) => fmtDate(r.hunt_week) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'impact_pct', header: 'Impact', render: (r: any) => fmtPct(r.impact_pct) },
    { key: 'bottleneck_owner_email', header: 'Owner', render: (r: any) => r.bottleneck_owner_email ?? '—' },
    {
      key: 'open_actions',
      header: 'Actions',
      render: (r: any) => `${r.open_actions} open / ${r.done_actions} done`,
    },
    {
      key: 'days_to_remove',
      header: 'Days to remove',
      render: (r: any) => (r.days_to_remove === null || r.days_to_remove === undefined ? '—' : String(r.days_to_remove)),
    },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Founder Bottleneck Hunt</h1>
        <p style={{ color: '#555', fontSize: 14 }}>
          Hunt the single org bottleneck each week — one decision, process, or person that's
          throttling throughput. Log it, attack it, remove it, repeat.
        </p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Current bottleneck</h2>
        {current ? (
          <div
            style={{
              border: '1px solid #e5e7eb',
              borderRadius: 8,
              padding: 16,
              background: '#fafafa',
            }}
          >
            <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>
              Week of {fmtDate(current.hunt_week)} · status {current.status}
            </div>
            <div style={{ fontSize: 15, whiteSpace: 'pre-wrap', marginBottom: 12 }}>
              {current.identified_bottleneck_md}
            </div>
            <div style={{ fontSize: 13, color: '#374151' }}>
              Owner: {current.bottleneck_owner_email ?? '—'} · Impact: {fmtPct(current.impact_pct)} ·
              Actions: {current.open_actions} open / {current.total_actions} total
            </div>
          </div>
        ) : (
          <div style={{ color: '#6b7280', fontSize: 14 }}>
            No active bottleneck logged. Time to hunt — pick the slowest seam this week.
          </div>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Hunt log ({hunts.length})
        </h2>
        <DataTable
          rows={hunts}
          columns={huntCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Open & recent actions ({actions.length})
        </h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Weekly history (last 12)
        </h2>
        <DataTable
          rows={history}
          columns={historyCols}
          rowKey={(r: any, i: number) => String(r.hunt_week ?? i)}
        />
      </section>

      <footer style={{ marginTop: 32, fontSize: 12, color: '#6b7280' }}>
        Round 1834 · founder-only · bottleneck &gt; everything else
      </footer>
    </main>
  );
}
