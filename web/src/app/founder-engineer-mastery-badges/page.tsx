import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type BadgeRow = {
  id: string;
  engineer_user_id: string | null;
  badge_label: string | null;
  badge_category: string | null;
  awarded_at: string | null;
  status: string | null;
  captured_at: string | null;
};

type ActionRow = {
  id: string;
  badge_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
  notes_md: string | null;
};

type RecentActionRow = {
  id: string;
  badge_id: string | null;
  action_type: string | null;
  taken_at: string | null;
  by_email: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [badgesRes, actionsRes, recentRes] = await Promise.all([
    sb.rpc('r2100_list_badges'),
    sb.rpc('r2100_list_actions'),
    sb.rpc('r2100_recent_actions', { p_days: 30 }),
  ]);

  const badges: BadgeRow[] = (badgesRes.data as BadgeRow[]) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];
  const recent: RecentActionRow[] = (recentRes.data as RecentActionRow[]) ?? [];

  const badgeCols: Column<BadgeRow>[] = [
    { key: 'badge_label', header: 'Badge', render: (r: any) => r.badge_label ?? '' },
    { key: 'badge_category', header: 'Category', render: (r: any) => r.badge_category ?? '' },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => r.engineer_user_id ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'awarded_at', header: 'Awarded', render: (r: any) => r.awarded_at ?? '' },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'badge_id', header: 'Badge', render: (r: any) => r.badge_id ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  const recentCols: Column<RecentActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'badge_id', header: 'Badge', render: (r: any) => r.badge_id ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ?? '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer 2100-Series Mastery Badges</h1>
        <p className="text-sm text-gray-600">Awarded badges, action history, and recent activity for engineer recognition.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Mastery badges</h2>
        <DataTable rows={badges} columns={badgeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Action log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent activity (last 30 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
