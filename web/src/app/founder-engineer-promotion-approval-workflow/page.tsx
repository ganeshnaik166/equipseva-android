import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [proposalsRes, summaryRes, workloadRes] = await Promise.all([
    sb.rpc('list_proposals_r1780'),
    sb.rpc('pending_proposals_summary_r1780'),
    sb.rpc('approver_workload_r1780'),
  ]);

  const proposals = (proposalsRes.data as any[]) ?? [];
  const summary = (summaryRes.data as any[]) ?? [];
  const workload = (workloadRes.data as any[]) ?? [];

  const proposalCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'current_tier', header: 'Current', render: (r: any) => r.current_tier ?? '—' },
    { key: 'proposed_tier', header: 'Proposed', render: (r: any) => r.proposed_tier ?? '—' },
    { key: 'proposer_email', header: 'Proposer', render: (r: any) => r.proposer_email ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'approval_count', header: 'Approvals', render: (r: any) => String(r.approval_count ?? 0) },
    { key: 'proposed_at', header: 'Proposed', render: (r: any) => r.proposed_at ? new Date(r.proposed_at).toLocaleString() : '—' },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleString() : '—' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'proposal_count', header: 'Count', render: (r: any) => String(r.proposal_count ?? 0) },
    { key: 'oldest_proposed_at', header: 'Oldest', render: (r: any) => r.oldest_proposed_at ? new Date(r.oldest_proposed_at).toLocaleString() : '—' },
  ];

  const workloadCols: Column<any>[] = [
    { key: 'approver_email', header: 'Approver', render: (r: any) => r.approver_email ?? '—' },
    { key: 'approver_role', header: 'Role', render: (r: any) => r.approver_role ?? '—' },
    { key: 'total_decisions', header: 'Total', render: (r: any) => String(r.total_decisions ?? 0) },
    { key: 'approves', header: 'Approves', render: (r: any) => String(r.approves ?? 0) },
    { key: 'rejects', header: 'Rejects', render: (r: any) => String(r.rejects ?? 0) },
    { key: 'needs_more_info', header: 'More Info', render: (r: any) => String(r.needs_more_info ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Promotion Approval Workflow</h1>
        <p className="text-sm text-gray-600">Tier promotion proposals with multi-step approval log (manager, founder, peer, customer).</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending Proposals Summary</h2>
        <DataTable rows={summary} columns={summaryCols} rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Proposals</h2>
        <DataTable rows={proposals} columns={proposalCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Approver Workload</h2>
        <DataTable rows={workload} columns={workloadCols} rowKey={(r: any, i: number) => String((r.approver_email ?? '') + (r.approver_role ?? '') + i)} />
      </section>
    </div>
  );
}
