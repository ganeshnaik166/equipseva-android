import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [proposalsRes, openRes, recentRes] = await Promise.all([
    sb.rpc('list_proposals_r1977'),
    sb.rpc('open_proposals_r1977'),
    sb.rpc('recent_votes_r1977', { p_limit: 50 }),
  ]);

  const proposals: any[] = Array.isArray(proposalsRes.data) ? proposalsRes.data : [];
  const open: any[] = Array.isArray(openRes.data) ? openRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const proposalCols: Column<any>[] = [
    { key: 'proposal_label', header: 'Proposal', render: (r: any) => String(r.proposal_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'vote_threshold_pct', header: 'Threshold %', render: (r: any) => String(r.vote_threshold_pct ?? '') },
    { key: 'current_yes_shares', header: 'Yes shares', render: (r: any) => String(r.current_yes_shares ?? 0) },
    { key: 'current_no_shares', header: 'No shares', render: (r: any) => String(r.current_no_shares ?? 0) },
    { key: 'abstain_shares', header: 'Abstain', render: (r: any) => String(r.abstain_shares ?? 0) },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleString() : '' },
    { key: 'closes_at', header: 'Closes', render: (r: any) => r.closes_at ? new Date(r.closes_at).toLocaleString() : '' },
  ];

  const openCols: Column<any>[] = [
    { key: 'proposal_label', header: 'Proposal', render: (r: any) => String(r.proposal_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'vote_threshold_pct', header: 'Threshold %', render: (r: any) => String(r.vote_threshold_pct ?? '') },
    { key: 'tally', header: 'Tally yes and no', render: (r: any) => `${r.current_yes_shares ?? 0} yes, ${r.current_no_shares ?? 0} no` },
    { key: 'closes_at', header: 'Closes', render: (r: any) => r.closes_at ? new Date(r.closes_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'voter_email', header: 'Voter', render: (r: any) => String(r.voter_email ?? '') },
    { key: 'vote', header: 'Vote', render: (r: any) => String(r.vote ?? '') },
    { key: 'shares_voted', header: 'Shares', render: (r: any) => String(r.shares_voted ?? 0) },
    { key: 'voted_at', header: 'Voted at', render: (r: any) => r.voted_at ? new Date(r.voted_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Stockholder Vote Tracker</h1>
        <p className="text-sm text-gray-600">Track stockholder proposals, threshold approval, and per-voter share tallies.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open proposals</h2>
        <p className="text-xs text-gray-500 mb-2">Status open, passing, or failing. Threshold is the percent of yes shares required to pass.</p>
        <DataTable rows={open} columns={openCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All proposals</h2>
        <DataTable rows={proposals} columns={proposalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent votes</h2>
        <p className="text-xs text-gray-500 mb-2">Last 50 vote entries across all proposals.</p>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
