import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerCustomerReactionTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [reactionsRes, escalationsRes, actionsRes] = await Promise.all([
    sb.rpc('list_reactions_r2028'),
    sb.rpc('escalations_r2028'),
    sb.rpc('recent_actions_r2028'),
  ]);

  const reactions: any[] = Array.isArray(reactionsRes.data) ? reactionsRes.data : [];
  const escalations: any[] = Array.isArray(escalationsRes.data) ? escalationsRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const reactionCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? '' },
    { key: 'reaction_type', header: 'Type', render: (r: any) => r.reaction_type ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'reaction_md', header: 'Note', render: (r: any) => r.reaction_md ?? '' },
  ];

  const escalationCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '' },
    { key: 'reaction_type', header: 'Type', render: (r: any) => r.reaction_type ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '' },
    { key: 'reaction_md', header: 'Note', render: (r: any) => r.reaction_md ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Customer Reaction Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track customer reactions to engineer service. Capture thank-yous, concerns, upsets, escalations, and repeat requests.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Reactions</h2>
        <p className="text-xs text-gray-500 mb-2">Total: {reactions.length}</p>
        <DataTable rows={reactions} columns={reactionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Escalations</h2>
        <p className="text-xs text-gray-500 mb-2">Total: {escalations.length}</p>
        <DataTable rows={escalations} columns={escalationCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <p className="text-xs text-gray-500 mb-2">Total: {actions.length}</p>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
