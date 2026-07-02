import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorVotingBlockTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [allBlocksRes, activeBlocksRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_voting_blocks_r2141'),
    sb.rpc('active_voting_blocks_r2141'),
    sb.rpc('recent_voting_block_actions_r2141'),
  ]);

  const allBlocks = Array.isArray(allBlocksRes.data) ? allBlocksRes.data : [];
  const activeBlocks = Array.isArray(activeBlocksRes.data) ? activeBlocksRes.data : [];
  const recentActions = Array.isArray(recentActionsRes.data) ? recentActionsRes.data : [];

  const blockColumns: Column<any>[] = [
    { key: 'block_label', header: 'Block', render: (r: any) => String(r.block_label ?? '') },
    { key: 'total_shares_in_block', header: 'Shares', render: (r: any) => String(r.total_shares_in_block ?? 0) },
    { key: 'member_count', header: 'Members', render: (r: any) => String(r.member_count ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'formed_at', header: 'Formed', render: (r: any) => r.formed_at ? new Date(r.formed_at).toLocaleString() : 'pending' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionColumns: Column<any>[] = [
    { key: 'block_id', header: 'Block id', render: (r: any) => String(r.block_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main className="mx-auto max-w-6xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor Voting Block Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track investor voting blocks formed around proposals. Founder-only view.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Active blocks</h2>
        <DataTable
          rows={activeBlocks}
          columns={blockColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All blocks</h2>
        <DataTable
          rows={allBlocks}
          columns={blockColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent actions</h2>
        <DataTable
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
