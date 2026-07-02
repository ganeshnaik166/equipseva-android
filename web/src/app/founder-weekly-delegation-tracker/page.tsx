import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderWeeklyDelegationTrackerPage() {
  const supabase = await getSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  const email = user?.email ?? '';

  const [weekly, byRole, bounces, open, gaps, load, top] = await Promise.all([
    supabase.rpc('delegation_weekly_summary_r2405'),
    supabase.rpc('delegation_by_role_r2405'),
    supabase.rpc('delegation_recent_bounces_r2405'),
    supabase.rpc('delegation_open_items_r2405'),
    supabase.rpc('delegation_category_gaps_r2405'),
    supabase.rpc('delegation_founder_load_r2405'),
    supabase.rpc('delegation_top_handlers_r2405'),
  ]);

  const weeklyCols: Column<any>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'total_delegated', header: 'Delegated', render: (r) => r.total_delegated },
    { key: 'handled_independently', header: 'Handled solo', render: (r) => r.handled_independently },
    { key: 'bounced_back', header: 'Bounced back', render: (r) => r.bounced_back },
    { key: 'dropped', header: 'Dropped', render: (r) => r.dropped },
    { key: 'bounce_rate', header: 'Bounce %', render: (r) => (r.bounce_rate ?? 0) + '%' },
  ];

  const roleCols: Column<any>[] = [
    { key: 'delegated_to_role', header: 'Role', render: (r) => r.delegated_to_role },
    { key: 'total_tasks', header: 'Tasks', render: (r) => r.total_tasks },
    { key: 'handled', header: 'Handled', render: (r) => r.handled },
    { key: 'bounced', header: 'Bounced', render: (r) => r.bounced },
    { key: 'handle_rate', header: 'Handle %', render: (r) => (r.handle_rate ?? 0) + '%' },
    { key: 'avg_founder_hours', header: 'Avg founder hrs', render: (r) => r.avg_founder_hours ?? 0 },
  ];

  const bounceCols: Column<any>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'task_title', header: 'Task', render: (r) => r.task_title },
    { key: 'delegated_to_role', header: 'Role', render: (r) => r.delegated_to_role },
    { key: 'bounce_reason', header: 'Why bounced', render: (r) => r.bounce_reason ?? '-' },
    { key: 'gap_identified', header: 'Gap', render: (r) => r.gap_identified ?? '-' },
    { key: 'founder_hours_spent', header: 'Founder hrs', render: (r) => r.founder_hours_spent ?? 0 },
  ];

  const openCols: Column<any>[] = [
    { key: 'task_title', header: 'Task', render: (r) => r.task_title },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'priority', header: 'Priority', render: (r) => r.priority },
    { key: 'delegated_to_role', header: 'Role', render: (r) => r.delegated_to_role },
    { key: 'due_date', header: 'Due', render: (r) => r.due_date ?? '-' },
    { key: 'decision_authority', header: 'Authority', render: (r) => r.decision_authority },
  ];

  const gapCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'total_tasks', header: 'Tasks', render: (r) => r.total_tasks },
    { key: 'bounced', header: 'Bounced', render: (r) => r.bounced },
    { key: 'dropped', header: 'Dropped', render: (r) => r.dropped },
    { key: 'gap_rate', header: 'Gap %', render: (r) => (r.gap_rate ?? 0) + '%' },
  ];

  const loadCols: Column<any>[] = [
    { key: 'week_starting', header: 'Week', render: (r) => r.week_starting },
    { key: 'total_founder_hours', header: 'Total founder hrs', render: (r) => r.total_founder_hours ?? 0 },
    { key: 'hours_on_bounces', header: 'Hours on bounces', render: (r) => r.hours_on_bounces ?? 0 },
    { key: 'hours_on_originally_owned', header: 'Hours owned', render: (r) => r.hours_on_originally_owned ?? 0 },
  ];

  const topCols: Column<any>[] = [
    { key: 'delegate_email', header: 'Delegate', render: (r) => r.delegate_email ?? '-' },
    { key: 'role_text', header: 'Role', render: (r) => r.role_text },
    { key: 'total_assigned', header: 'Assigned', render: (r) => r.total_assigned },
    { key: 'handled_independently', header: 'Solo', render: (r) => r.handled_independently },
    { key: 'success_rate', header: 'Success %', render: (r) => (r.success_rate ?? 0) + '%' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder weekly delegation tracker</h1>
      <p style={{ color: '#666', marginTop: 4, fontSize: 13 }}>
        What founder delegated & whether it stuck. Signed in as {email}.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Weekly summary (last 12 weeks)</h2>
        <DataTable
          rows={weekly.data ?? []}
          columns={weeklyCols}
          emptyMessage="No delegations logged"
          rowKey={(r) => String(r.week_starting)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>By delegate role</h2>
        <DataTable
          rows={byRole.data ?? []}
          columns={roleCols}
          emptyMessage="No role data"
          rowKey={(r) => String(r.delegated_to_role)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent bounce-backs (decisions came back to founder)</h2>
        <DataTable
          rows={bounces.data ?? []}
          columns={bounceCols}
          emptyMessage="No bounces — clean delegation"
          rowKey={(r) => String(r.id)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Open delegations</h2>
        <DataTable
          rows={open.data ?? []}
          columns={openCols}
          emptyMessage="No open delegations"
          rowKey={(r) => String(r.id)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Category gaps (where delegation breaks)</h2>
        <DataTable
          rows={gaps.data ?? []}
          columns={gapCols}
          emptyMessage="No category gaps"
          rowKey={(r) => String(r.category)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Founder load (hours pulled back in)</h2>
        <DataTable
          rows={load.data ?? []}
          columns={loadCols}
          emptyMessage="No load data"
          rowKey={(r) => String(r.week_starting)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Top handlers (delegates who actually own it)</h2>
        <DataTable
          rows={top.data ?? []}
          columns={topCols}
          emptyMessage="Need >= 2 tasks per delegate"
          rowKey={(r) => String(r.delegated_to_user_id)}
        />
      </section>
    </main>
  );
}
