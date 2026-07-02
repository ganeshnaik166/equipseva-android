import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Stakeholder = {
  id: string;
  stakeholder_name: string;
  stakeholder_type: string;
  influence_level: number;
  interest_level: number;
  current_attitude: string;
  status: string;
  captured_at: string;
};

type HighInfluence = {
  id: string;
  stakeholder_name: string;
  stakeholder_type: string;
  influence_level: number;
  interest_level: number;
  current_attitude: string;
  status: string;
};

type RecentAction = {
  id: string;
  stakeholder_id: string;
  stakeholder_name: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function FounderStakeholderInfluenceMatrixPage() {
  const sb = await getSupabaseServerClient();

  const [listRes, highRes, recentRes] = await Promise.all([
    sb.rpc('list_stakeholders_r2046'),
    sb.rpc('high_influence_r2046'),
    sb.rpc('recent_actions_r2046'),
  ]);

  const stakeholders: Stakeholder[] = (listRes.data as Stakeholder[]) ?? [];
  const highInfluence: HighInfluence[] = (highRes.data as HighInfluence[]) ?? [];
  const recentActions: RecentAction[] = (recentRes.data as RecentAction[]) ?? [];

  const stakeholderCols: Column<Stakeholder>[] = [
    { key: 'stakeholder_name', header: 'Name', render: (r: any) => r.stakeholder_name },
    { key: 'stakeholder_type', header: 'Type', render: (r: any) => r.stakeholder_type },
    { key: 'influence_level', header: 'Influence', render: (r: any) => String(r.influence_level) },
    { key: 'interest_level', header: 'Interest', render: (r: any) => String(r.interest_level) },
    { key: 'current_attitude', header: 'Attitude', render: (r: any) => r.current_attitude },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const highCols: Column<HighInfluence>[] = [
    { key: 'stakeholder_name', header: 'Name', render: (r: any) => r.stakeholder_name },
    { key: 'stakeholder_type', header: 'Type', render: (r: any) => r.stakeholder_type },
    { key: 'influence_level', header: 'Influence', render: (r: any) => String(r.influence_level) },
    { key: 'interest_level', header: 'Interest', render: (r: any) => String(r.interest_level) },
    { key: 'current_attitude', header: 'Attitude', render: (r: any) => r.current_attitude },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<RecentAction>[] = [
    { key: 'stakeholder_name', header: 'Stakeholder', render: (r: any) => r.stakeholder_name ?? '-' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '-' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '-' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Stakeholder Influence Matrix</h1>
        <p className="text-sm text-gray-600">
          Map stakeholder influence and interest. Track attitudes and engagement actions across investors, board, customers, team, regulators, and partners.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">High influence active stakeholders</h2>
        <p className="text-xs text-gray-500 mb-2">Influence level seven or higher and status active.</p>
        <DataTable
          rows={highInfluence}
          columns={highCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All stakeholders</h2>
        <p className="text-xs text-gray-500 mb-2">Sorted by influence level descending.</p>
        <DataTable
          rows={stakeholders}
          columns={stakeholderCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent actions</h2>
        <p className="text-xs text-gray-500 mb-2">Latest engagements, concerns addressed, escalations, and win-backs.</p>
        <DataTable
          rows={recentActions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
